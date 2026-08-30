// SPDX-License-Identifier: GPL-3.0-or-later

import CommonCrypto
import CryptoKit
import Foundation
import zlib

public enum RayconfigReaderError: Error, Equatable, LocalizedError, Sendable {
    case passwordRequired
    case wrongPassword
    case unsupportedVersion
    case corruptFile(String)

    public var errorDescription: String? {
        switch self {
        case .passwordRequired:
            return "A password is required for this Raycast backup."
        case .wrongPassword:
            return "The password is not valid for this Raycast backup."
        case .unsupportedVersion:
            return "This Raycast backup version is not supported."
        case .corruptFile(let reason):
            return "The Raycast backup is corrupt. \(reason)"
        }
    }
}

enum RayconfigContainerVersion: Equatable, Sendable {
    case classic
}

struct RayconfigContainer: Equatable, Sendable {
    static let initializationVectorRange = 0..<kCCBlockSizeAES128
    static let ciphertextOffset = kCCBlockSizeAES128
    static let saltRange: Range<Int>? = nil
    static let hmacLength = 0

    let version: RayconfigContainerVersion
    let initializationVector: Data
    let ciphertext: Data

    static func parse(_ data: Data) throws -> RayconfigContainer {
        let minimumSize = kCCBlockSizeAES128 * 2
        guard data.count >= minimumSize else {
            throw RayconfigReaderError.corruptFile("The encrypted data is too short.")
        }
        guard data.count.isMultiple(of: kCCBlockSizeAES128) else {
            throw RayconfigReaderError.corruptFile("The encrypted data has an invalid length.")
        }

        // Raycast exports from 2025 and 2026 have no inline version marker.
        // Their first block is the random IV and every remaining block is ciphertext.
        return RayconfigContainer(
            version: .classic,
            initializationVector: data.subdata(in: initializationVectorRange),
            ciphertext: data.subdata(in: ciphertextOffset..<data.count)
        )
    }
}

public struct RayconfigReader: Sendable {
    private let maximumDecodedSize: Int

    public init(maximumDecodedSize: Int = 1_073_741_824) {
        self.maximumDecodedSize = maximumDecodedSize
    }

    public func read(from url: URL, password: String?) throws -> RaycastBackup {
        let data: Data
        do {
            data = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            throw RayconfigReaderError.corruptFile("The file could not be read.")
        }
        return try read(data: data, password: password)
    }

    public func read(data: Data, password: String?) throws -> RaycastBackup {
        guard !data.isEmpty else {
            throw RayconfigReaderError.corruptFile("The file is empty.")
        }
        if firstNonWhitespaceByte(in: data) == Character("{").asciiValue {
            return try decodeBackup(data)
        }
        guard let password, !password.isEmpty else {
            throw RayconfigReaderError.passwordRequired
        }
        let container = try RayconfigContainer.parse(data)
        let decrypted = try decrypt(container, password: password)
        return try decodeDecryptedPayload(decrypted)
    }

    private func decodeDecryptedPayload(_ data: Data) throws -> RaycastBackup {
        if hasGzipMagic(data) {
            let jsonData: Data
            do {
                jsonData = try gunzip(data)
            } catch let error as RayconfigReaderError {
                throw error
            } catch {
                throw RayconfigReaderError.corruptFile("The compressed payload could not be unpacked.")
            }
            return try decodeBackup(jsonData)
        }
        if firstNonWhitespaceByte(in: data) == Character("{").asciiValue {
            return try decodeBackup(data)
        }
        if data.starts(with: [0x50, 0x4B]) {
            throw RayconfigReaderError.unsupportedVersion
        }
        throw RayconfigReaderError.wrongPassword
    }

    private func decodeBackup(_ data: Data) throws -> RaycastBackup {
        do {
            return try JSONDecoder().decode(RaycastBackup.self, from: data)
        } catch {
            throw RayconfigReaderError.corruptFile("The payload is not valid JSON.")
        }
    }

    private func firstNonWhitespaceByte(in data: Data) -> UInt8? {
        data.first { byte in
            byte != 0x20 && byte != 0x09 && byte != 0x0A && byte != 0x0D
        }
    }

    private func hasGzipMagic(_ data: Data) -> Bool {
        data.starts(with: [0x1F, 0x8B, 0x08])
    }

    private func decrypt(_ container: RayconfigContainer, password: String) throws -> Data {
        // Raycast hashes the UTF8 password once and uses the 32 byte digest as
        // the AES key. The PBKDF2 and HMAC strings in the app binary belong to
        // its embedded SQLCipher codec and are not used by rayconfig exports.
        let key = Data(SHA256.hash(data: Data(password.utf8)))
        let outputCapacity = container.ciphertext.count + kCCBlockSizeAES128
        var output = Data(count: outputCapacity)
        var outputLength = 0
        let status = output.withUnsafeMutableBytes { outputBytes in
            container.ciphertext.withUnsafeBytes { ciphertextBytes in
                key.withUnsafeBytes { keyBytes in
                    container.initializationVector.withUnsafeBytes { vectorBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            key.count,
                            vectorBytes.baseAddress,
                            ciphertextBytes.baseAddress,
                            container.ciphertext.count,
                            outputBytes.baseAddress,
                            outputCapacity,
                            &outputLength
                        )
                    }
                }
            }
        }
        guard status == kCCSuccess else {
            if status == kCCDecodeError {
                throw RayconfigReaderError.wrongPassword
            }
            throw RayconfigReaderError.corruptFile("The encrypted payload could not be decoded.")
        }
        output.removeSubrange(outputLength..<output.count)
        return output
    }

    private func gunzip(_ data: Data) throws -> Data {
        var stream = z_stream()
        let initialization = inflateInit2_(
            &stream,
            MAX_WBITS + 16,
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)
        )
        guard initialization == Z_OK else {
            throw RayconfigReaderError.corruptFile("The decompressor could not start.")
        }
        defer { inflateEnd(&stream) }

        var decoded = Data()
        let status: Int32 = data.withUnsafeBytes { inputBytes in
            stream.next_in = UnsafeMutablePointer(
                mutating: inputBytes.bindMemory(to: Bytef.self).baseAddress
            )
            stream.avail_in = uInt(data.count)
            let bufferSize = 65_536
            var buffer = [UInt8](repeating: 0, count: bufferSize)
            while true {
                let result = buffer.withUnsafeMutableBytes { outputBytes -> Int32 in
                    stream.next_out = outputBytes.bindMemory(to: Bytef.self).baseAddress
                    stream.avail_out = uInt(bufferSize)
                    return inflate(&stream, Z_NO_FLUSH)
                }
                let produced = bufferSize - Int(stream.avail_out)
                if produced > 0 {
                    decoded.append(buffer, count: produced)
                    if decoded.count > maximumDecodedSize {
                        return Z_MEM_ERROR
                    }
                }
                if result == Z_STREAM_END { return result }
                if result != Z_OK { return result }
                if stream.avail_in == 0 && produced == 0 { return Z_DATA_ERROR }
            }
        }
        if status == Z_MEM_ERROR {
            throw RayconfigReaderError.corruptFile("The decoded payload is too large.")
        }
        guard status == Z_STREAM_END else {
            throw RayconfigReaderError.corruptFile("The compressed payload is invalid.")
        }
        return decoded
    }
}
