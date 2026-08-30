// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct HyperKeyMapping: Codable, Equatable, Sendable {
    let source: UInt64
    let destination: UInt64

    enum CodingKeys: String, CodingKey {
        case source = "HIDKeyboardModifierMappingSrc"
        case destination = "HIDKeyboardModifierMappingDst"
    }
}

enum HyperKeyMappingCodec {
    static let capsLockUsage: UInt64 = 0x700000039
    static let function18Usage: UInt64 = 0x70000006D
    static let rightControlUsage: UInt64 = 0x7000000E4

    static func parse(_ output: String) -> [HyperKeyMapping] {
        let pattern = #"HIDKeyboardModifierMappingSrc\s*=\s*(\d+)[^}]*HIDKeyboardModifierMappingDst\s*=\s*(\d+)"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        return expression.matches(in: output, range: range).compactMap { match in
            guard
                let sourceRange = Range(match.range(at: 1), in: output),
                let destinationRange = Range(match.range(at: 2), in: output),
                let source = UInt64(output[sourceRange]),
                let destination = UInt64(output[destinationRange])
            else {
                return nil
            }
            return HyperKeyMapping(source: source, destination: destination)
        }
    }

    static func propertyJSON(for mappings: [HyperKeyMapping]) throws -> String {
        let entries = mappings.map {
            [
                "HIDKeyboardModifierMappingSrc": NSNumber(value: $0.source),
                "HIDKeyboardModifierMappingDst": NSNumber(value: $0.destination)
            ]
        }
        let data = try JSONSerialization.data(withJSONObject: ["UserKeyMapping": entries])
        guard let value = String(data: data, encoding: .utf8) else {
            throw HyperKeyError.invalidMappingData
        }
        return value
    }
}

struct HyperKeyMappingRunner {
    func apply(target: HyperKeyRemapTarget) throws {
        var mappings = try currentMappings().filter {
            $0.source != HyperKeyMappingCodec.capsLockUsage
        }
        let destination: UInt64
        switch target {
        case .function18:
            destination = HyperKeyMappingCodec.function18Usage
        case .rightControl:
            destination = HyperKeyMappingCodec.rightControlUsage
        }
        mappings.append(
            HyperKeyMapping(source: HyperKeyMappingCodec.capsLockUsage, destination: destination)
        )
        try setMappings(mappings)
    }

    func removeCapsLockMapping() throws {
        let mappings = try currentMappings().filter {
            $0.source != HyperKeyMappingCodec.capsLockUsage
        }
        try setMappings(mappings)
    }

    private func currentMappings() throws -> [HyperKeyMapping] {
        let output = try run(arguments: ["property", "--get", "UserKeyMapping"])
        return HyperKeyMappingCodec.parse(output)
    }

    private func setMappings(_ mappings: [HyperKeyMapping]) throws {
        let json = try HyperKeyMappingCodec.propertyJSON(for: mappings)
        _ = try run(arguments: ["property", "--set", json])
    }

    private func run(arguments: [String]) throws -> String {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        process.waitUntilExit()

        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            let errorData = errors.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw HyperKeyError.mappingFailed(message ?? "The keyboard mapping command failed")
        }
        return String(data: outputData, encoding: .utf8) ?? ""
    }
}
