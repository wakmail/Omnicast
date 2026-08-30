// SPDX-License-Identifier: GPL-3.0-or-later

import CommonCrypto
import CryptoKit
import Foundation
import zlib

public enum RayconfigReaderError: Error, Equatable, LocalizedError, Sendable {
    case passwordRequired
    case wrongPassword
    case corruptFile(String)

    public var errorDescription: String? {
        switch self {
        case .passwordRequired:
            return "A password is required for this Raycast backup."
        case .wrongPassword:
            return "The password is not valid for this Raycast backup."
        case .corruptFile(let reason):
            return "The Raycast backup is corrupt. \(reason)"
        }
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
        guard data.count.isMultiple(of: kCCBlockSizeAES128) else {
            throw RayconfigReaderError.corruptFile("The encrypted data has an invalid length.")
        }

        let decrypted = try decrypt(data, password: password)
        guard let gzipStart = gzipOffset(in: decrypted) else {
            throw RayconfigReaderError.wrongPassword
        }
        let compressed = decrypted[gzipStart...]
        let jsonData: Data
        do {
            jsonData = try gunzip(Data(compressed))
        } catch let error as RayconfigReaderError {
            throw error
        } catch {
            throw RayconfigReaderError.corruptFile("The compressed payload could not be unpacked.")
        }
        return try decodeBackup(jsonData)
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

    private func gzipOffset(in data: Data) -> Data.Index? {
        guard data.count >= 3 else { return nil }
        let limit = min(data.count - 2, 64)
        for offset in 0..<limit {
            let index = data.index(data.startIndex, offsetBy: offset)
            if data[index] == 0x1F,
               data[data.index(after: index)] == 0x8B,
               data[data.index(index, offsetBy: 2)] == 0x08 {
                return index
            }
        }
        return nil
    }

    private func decrypt(_ ciphertext: Data, password: String) throws -> Data {
        let material = deriveKeyAndInitializationVector(password: password)
        let outputCapacity = ciphertext.count + kCCBlockSizeAES128
        var output = Data(count: outputCapacity)
        var outputLength = 0
        let status = output.withUnsafeMutableBytes { outputBytes in
            ciphertext.withUnsafeBytes { ciphertextBytes in
                material.key.withUnsafeBytes { keyBytes in
                    material.initializationVector.withUnsafeBytes { vectorBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            material.key.count,
                            vectorBytes.baseAddress,
                            ciphertextBytes.baseAddress,
                            ciphertext.count,
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

    private func deriveKeyAndInitializationVector(password: String) -> (key: Data, initializationVector: Data) {
        let passwordData = Data(password.utf8)
        var material = Data()
        var previous = Data()
        while material.count < 48 {
            var hasher = SHA256()
            hasher.update(data: previous)
            hasher.update(data: passwordData)
            previous = Data(hasher.finalize())
            material.append(previous)
        }
        return (
            key: material.prefix(32),
            initializationVector: material.dropFirst(32).prefix(16)
        )
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
