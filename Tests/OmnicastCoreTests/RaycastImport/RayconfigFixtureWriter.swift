// SPDX-License-Identifier: GPL-3.0-or-later

import CommonCrypto
import CryptoKit
import Foundation
import zlib

enum RayconfigFixtureWriter {
    static func make(payload: Data, password: String) throws -> Data {
        try encrypt(gzip(payload), password: password)
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

    private static func encrypt(_ plaintext: Data, password: String) throws -> Data {
        let material = derive(password: password)
        let outputCapacity = plaintext.count + kCCBlockSizeAES128
        var output = Data(count: outputCapacity)
        var outputLength = 0
        let status = output.withUnsafeMutableBytes { outputBytes in
            plaintext.withUnsafeBytes { plaintextBytes in
                material.key.withUnsafeBytes { keyBytes in
                    material.vector.withUnsafeBytes { vectorBytes in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            material.key.count,
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
        return output
    }

    private static func derive(password: String) -> (key: Data, vector: Data) {
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
        return (material.prefix(32), material.dropFirst(32).prefix(16))
    }

    private enum FixtureError: Error {
        case gzip
        case encryption
    }
}
