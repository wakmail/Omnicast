// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum TarGzipError: LocalizedError {
    case toolFailed(String)
    case unsafeEntry(String)
    case unsupportedEntry(String)

    var errorDescription: String? {
        switch self {
        case .toolFailed(let output):
            "The archive tool failed: \(output)"
        case .unsafeEntry(let entry):
            "The extension archive contains an unsafe path: \(entry)"
        case .unsupportedEntry(let entry):
            "The extension archive contains an unsupported entry: \(entry)"
        }
    }
}

enum TarGzipExtractor {
    static func extract(archiveURL: URL, destinationURL: URL) throws {
        let names = try run(arguments: ["-tzf", archiveURL.path])
        try validateNames(names)
        let details = try run(arguments: ["-tvzf", archiveURL.path])
        try validateEntryTypes(details)
        try FileManager.default.createDirectory(
            at: destinationURL,
            withIntermediateDirectories: true
        )
        _ = try run(arguments: [
            "-xzf",
            archiveURL.path,
            "-C",
            destinationURL.path
        ])
    }

    private static func validateNames(_ output: String) throws {
        for rawName in output.split(whereSeparator: \.isNewline) {
            let name = String(rawName)
            let components = name.split(separator: "/", omittingEmptySubsequences: false)
            if name.hasPrefix("/")
                || name.hasPrefix("\\")
                || components.contains("..")
                || components.first == "~" {
                throw TarGzipError.unsafeEntry(name)
            }
        }
    }

    private static func validateEntryTypes(_ output: String) throws {
        for line in output.split(whereSeparator: \.isNewline) {
            guard let type = line.first else { continue }
            if type != "-" && type != "d" {
                throw TarGzipError.unsupportedEntry(String(line))
            }
        }
    }

    private static func run(arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(data: data, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw TarGzipError.toolFailed(text)
        }
        return text
    }
}
