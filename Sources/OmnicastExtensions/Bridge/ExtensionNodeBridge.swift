// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum ExtensionNodeBridgeError: LocalizedError {
    case invalidPayload(String)
    case invalidURL(String)
    case unsupportedSyncOperation(String)

    var errorDescription: String? {
        switch self {
        case .invalidPayload(let name):
            "The Node bridge message is missing or has an invalid \(name) value"
        case .invalidURL(let value):
            "The Node bridge message contains an invalid URL: \(value)"
        case .unsupportedSyncOperation(let operation):
            "The synchronous Node operation is not supported: \(operation)"
        }
    }
}

final class ExtensionNodeBridge: @unchecked Sendable {
    private let fileManager: FileManager
    private let session: URLSession

    init(
        fileManager: FileManager = .default,
        session: URLSession = .shared
    ) {
        self.fileManager = fileManager
        self.session = session
    }

    func synchronousResponse(for source: String?) -> String {
        do {
            guard let source,
                  let data = source.data(using: .utf8),
                  let request = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let operation = request["operation"] as? String,
                  let payload = request["payload"] as? [String: Any] else {
                throw ExtensionNodeBridgeError.invalidPayload("request")
            }
            let result = try performSynchronous(operation: operation, payload: payload)
            return try encode(["result": result])
        } catch {
            return (try? encode(["error": error.localizedDescription]))
                ?? "{\"error\":\"The synchronous Node operation failed\"}"
        }
    }

    func executeProcess(payload: [String: JSONValue]) async throws -> JSONValue {
        let kind = try string("kind", in: payload)
        let command = try string("command", in: payload)
        let arguments = arrayOfStrings("arguments", in: payload)
        let options = object("options", in: payload)
        let process = Process()
        if kind == "exec" {
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [command] + arguments
        }
        if let cwd = optionalString("cwd", in: options), !cwd.isEmpty {
            process.currentDirectoryURL = URL(fileURLWithPath: cwd, isDirectory: true)
        }
        if case .object(let environment)? = options["env"] {
            process.environment = environment.reduce(into: [:]) { result, entry in
                if case .string(let value) = entry.value {
                    result[entry.key] = value
                }
            }
        }

        let temporaryURL = fileManager.temporaryDirectory.appendingPathComponent(
            "OmnicastProcess.\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: temporaryURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryURL) }
        let stdoutURL = temporaryURL.appendingPathComponent("stdout")
        let stderrURL = temporaryURL.appendingPathComponent("stderr")
        fileManager.createFile(atPath: stdoutURL.path, contents: nil)
        fileManager.createFile(atPath: stderrURL.path, contents: nil)
        let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
        let stderrHandle = try FileHandle(forWritingTo: stderrURL)
        defer {
            try? stdoutHandle.close()
            try? stderrHandle.close()
        }
        process.standardOutput = stdoutHandle
        process.standardError = stderrHandle
        try process.run()

        let timeout = number("timeout", in: options) ?? 0
        let deadline = timeout > 0
            ? Date().addingTimeInterval(timeout / 1_000)
            : .distantFuture
        var timedOut = false
        while process.isRunning {
            if Date() >= deadline {
                timedOut = true
                process.terminate()
                break
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        if process.isRunning {
            process.waitUntilExit()
        }
        try stdoutHandle.synchronize()
        try stderrHandle.synchronize()
        let stdoutData = try Data(contentsOf: stdoutURL)
        let stderrData = try Data(contentsOf: stderrURL)
        let maximum = Int(number("maxBuffer", in: options) ?? 10 * 1_024 * 1_024)
        if stdoutData.count > maximum || stderrData.count > maximum {
            throw CocoaError(.fileReadTooLarge)
        }
        return .object([
            "stdout": .string(String(decoding: stdoutData, as: UTF8.self)),
            "stderr": .string(String(decoding: stderrData, as: UTF8.self)),
            "status": .number(Double(process.terminationStatus)),
            "timedOut": .bool(timedOut)
        ])
    }

    func access(payload: [String: JSONValue]) throws -> JSONValue {
        let path = try string("path", in: payload)
        guard fileManager.fileExists(atPath: path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return .null
    }

    func readFile(payload: [String: JSONValue]) throws -> JSONValue {
        let data = try Data(contentsOf: URL(fileURLWithPath: try string("path", in: payload)))
        if let encoding = optionalString("encoding", in: payload), encoding != "buffer" {
            return .string(decode(data, encoding: encoding))
        }
        return .object(["base64": .string(data.base64EncodedString())])
    }

    func stat(payload: [String: JSONValue]) throws -> JSONValue {
        try stat(path: string("path", in: payload))
    }

    func readDirectory(payload: [String: JSONValue]) throws -> JSONValue {
        let names = try fileManager.contentsOfDirectory(atPath: string("path", in: payload))
        return .array(names.map(JSONValue.string))
    }

    func writeFile(payload: [String: JSONValue]) throws -> JSONValue {
        let url = URL(fileURLWithPath: try string("path", in: payload))
        let data: Data
        if let value = optionalString("data", in: payload) {
            data = Data(value.utf8)
        } else if let value = optionalString("base64", in: payload),
                  let decoded = Data(base64Encoded: value) {
            data = decoded
        } else {
            throw ExtensionNodeBridgeError.invalidPayload("data")
        }
        try data.write(to: url)
        return .null
    }

    func makeDirectory(payload: [String: JSONValue]) throws -> JSONValue {
        try fileManager.createDirectory(
            at: URL(fileURLWithPath: string("path", in: payload), isDirectory: true),
            withIntermediateDirectories: bool("recursive", in: payload) ?? false
        )
        return .null
    }

    func fetch(payload: [String: JSONValue]) async throws -> JSONValue {
        let rawURL = try string("url", in: payload)
        guard let url = URL(string: rawURL) else {
            throw ExtensionNodeBridgeError.invalidURL(rawURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = optionalString("method", in: payload) ?? "GET"
        if case .object(let headers)? = payload["headers"] {
            for (name, value) in headers {
                if case .string(let value) = value {
                    request.setValue(value, forHTTPHeaderField: name)
                }
            }
        }
        if let body = optionalString("body", in: payload) {
            request.httpBody = Data(body.utf8)
        } else if let body = optionalString("bodyBase64", in: payload) {
            request.httpBody = Data(base64Encoded: body)
        }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        let headers = response.allHeaderFields.reduce(into: [String: JSONValue]()) { result, pair in
            result[String(describing: pair.key)] = .string(String(describing: pair.value))
        }
        return .object([
            "status": .number(Double(response.statusCode)),
            "url": .string(response.url?.absoluteString ?? rawURL),
            "headers": .object(headers),
            "bodyBase64": .string(data.base64EncodedString())
        ])
    }

    private func performSynchronous(operation: String, payload: [String: Any]) throws -> Any {
        guard let path = payload["path"] as? String else {
            throw ExtensionNodeBridgeError.invalidPayload("path")
        }
        switch operation {
        case "fs.readFileSync":
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            if let encoding = payload["encoding"] as? String, encoding != "buffer" {
                return decode(data, encoding: encoding)
            }
            return ["base64": data.base64EncodedString()]
        case "fs.existsSync":
            return fileManager.fileExists(atPath: path)
        case "fs.statSync":
            return try stat(path: path).foundationValue
        default:
            throw ExtensionNodeBridgeError.unsupportedSyncOperation(operation)
        }
    }

    private func stat(path: String) throws -> JSONValue {
        let attributes = try fileManager.attributesOfItem(atPath: path)
        let type = attributes[.type] as? FileAttributeType
        let modified = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        return .object([
            "size": .number(Double((attributes[.size] as? NSNumber)?.int64Value ?? 0)),
            "mtimeMs": .number(modified * 1_000),
            "isFile": .bool(type == .typeRegular),
            "isDirectory": .bool(type == .typeDirectory),
            "isSymbolicLink": .bool(type == .typeSymbolicLink)
        ])
    }

    private func decode(_ data: Data, encoding: String) -> String {
        switch encoding.lowercased() {
        case "base64": data.base64EncodedString()
        case "ascii": String(data: data, encoding: .ascii) ?? ""
        case "utf16le", "ucs2", "ucs-2": String(data: data, encoding: .utf16LittleEndian) ?? ""
        default: String(decoding: data, as: UTF8.self)
        }
    }

    private func encode(_ value: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed])
        return String(decoding: data, as: UTF8.self)
    }

    private func string(_ name: String, in values: [String: JSONValue]) throws -> String {
        guard case .string(let value) = values[name] else {
            throw ExtensionNodeBridgeError.invalidPayload(name)
        }
        return value
    }

    private func optionalString(_ name: String, in values: [String: JSONValue]) -> String? {
        guard case .string(let value) = values[name] else { return nil }
        return value
    }

    private func number(_ name: String, in values: [String: JSONValue]) -> Double? {
        guard case .number(let value) = values[name] else { return nil }
        return value
    }

    private func bool(_ name: String, in values: [String: JSONValue]) -> Bool? {
        guard case .bool(let value) = values[name] else { return nil }
        return value
    }

    private func object(_ name: String, in values: [String: JSONValue]) -> [String: JSONValue] {
        guard case .object(let value) = values[name] else { return [:] }
        return value
    }

    private func arrayOfStrings(_ name: String, in values: [String: JSONValue]) -> [String] {
        guard case .array(let values) = values[name] else { return [] }
        return values.compactMap {
            guard case .string(let value) = $0 else { return nil }
            return value
        }
    }
}
