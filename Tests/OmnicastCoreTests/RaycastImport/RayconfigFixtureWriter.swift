// SPDX-License-Identifier: GPL-3.0-or-later

import CommonCrypto
import CryptoKit
import Foundation
import zlib

enum RayconfigFixtureWriter {
    static let defaultInitializationVector = Data((0..<16).map(UInt8.init))

    static func make(
        payload: Data,
        password: String,
        initializationVector: Data = defaultInitializationVector
    ) throws -> Data {
        try encrypt(gzip(payload), password: password, initializationVector: initializationVector)
    }

    static func makeUncompressed(
        payload: Data,
        password: String,
        initializationVector: Data = defaultInitializationVector
    ) throws -> Data {
        try encrypt(payload, password: password, initializationVector: initializationVector)
    }

    private static func gzip(_ data: Data) throws -> Data {
        var stream = z_stream()
        let status = deflateInit2_(
            &stream,
            Z_DEFAULT_COMPRESSION,
            Z_DEFLATED,
            MAX_WBITS + 16,
            8,
            Z_DEFAULT_STRATEGY,
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)
        )
        guard status == Z_OK else { throw FixtureError.gzip }
        defer { deflateEnd(&stream) }

        var output = Data()
        let finalStatus: Int32 = data.withUnsafeBytes { inputBytes in
            stream.next_in = UnsafeMutablePointer(
                mutating: inputBytes.bindMemory(to: Bytef.self).baseAddress
            )
            stream.avail_in = uInt(data.count)
            let bufferSize = 4_096
            var buffer = [UInt8](repeating: 0, count: bufferSize)
            while true {
                let result = buffer.withUnsafeMutableBytes { outputBytes -> Int32 in
                    stream.next_out = outputBytes.bindMemory(to: Bytef.self).baseAddress
                    stream.avail_out = uInt(bufferSize)
                    return deflate(&stream, Z_FINISH)
                }
                let produced = bufferSize - Int(stream.avail_out)
                output.append(contentsOf: buffer.prefix(produced))
                if result == Z_STREAM_END { return result }
                if result != Z_OK { return result }
            }
        }
        guard finalStatus == Z_STREAM_END else { throw FixtureError.gzip }
        return output
    }

    private static func encrypt(
        _ plaintext: Data,
        password: String,
        initializationVector: Data
    ) throws -> Data {
        guard initializationVector.count == kCCBlockSizeAES128 else {
            throw FixtureError.encryption
        }
        let key = Data(SHA256.hash(data: Data(password.utf8)))
        let outputCapacity = plaintext.count + kCCBlockSizeAES128
        var output = Data(count: outputCapacity)
        var outputLength = 0
        let status = output.withUnsafeMutableBytes { outputBytes in
            plaintext.withUnsafeBytes { plaintextBytes in
                key.withUnsafeBytes { keyBytes in
                    initializationVector.withUnsafeBytes { vectorBytes in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            key.count,
                            vectorBytes.baseAddress,
                            plaintextBytes.baseAddress,
                            plaintext.count,
                            outputBytes.baseAddress,
                            outputCapacity,
                            &outputLength
                        )
                    }
                }
            }
        }
        guard status == kCCSuccess else { throw FixtureError.encryption }
        output.removeSubrange(outputLength..<output.count)
        var container = initializationVector
        container.append(output)
        return container
    }

    private enum FixtureError: Error {
        case gzip
        case encryption
    }
}
