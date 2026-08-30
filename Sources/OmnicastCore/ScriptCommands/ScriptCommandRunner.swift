// SPDX-License-Identifier: GPL-3.0-or-later

import Darwin
import Foundation

public struct ScriptExecutionResult: Equatable, Sendable {
    public let commandID: String
    public let mode: ScriptCommandMode
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String
    public let output: String
    public let firstLine: String
    public let lastLine: String
    public let timedOut: Bool

    public init(
        commandID: String,
        mode: ScriptCommandMode,
        exitCode: Int32,
        stdout: String,
        stderr: String,
        output: String,
        firstLine: String,
        lastLine: String,
        timedOut: Bool
    ) {
        self.commandID = commandID
        self.mode = mode
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.output = output
        self.firstLine = firstLine
        self.lastLine = lastLine
        self.timedOut = timedOut
    }
}

public enum ScriptCommandExecutionError: Error, Equatable, LocalizedError {
    case missingArguments([String])
    case launchFailed(String)
    case unsuccessful(exitCode: Int32, message: String)

    public var errorDescription: String? {
        switch self {
        case let .missingArguments(names):
            return "Missing required arguments: " + names.joined(separator: ", ")
        case let .launchFailed(message):
            return "Could not start the script: \(message)"
        case let .unsuccessful(exitCode, message):
            return message.isEmpty ? "Script exited with code \(exitCode)" : message
        }
    }
}

public struct ScriptCommandRunner: Sendable {
    public let timeout: TimeInterval
    public let maximumOutputBytes: Int
    public let environment: [String: String]
    public let loginShellPath: String?

    public init(
        timeout: TimeInterval = 60,
        maximumOutputBytes: Int = 2 * 1_024 * 1_024,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        loginShellPath: String? = nil
    ) {
        self.timeout = timeout
        self.maximumOutputBytes = maximumOutputBytes
        self.environment = environment
        self.loginShellPath = loginShellPath
    }

    public func run(
        _ command: ScriptCommand,
        arguments: [String: String] = [:]
    ) async throws -> ScriptExecutionResult {
        try await Task.detached(priority: .userInitiated) {
            try runSynchronously(command, arguments: arguments)
        }.value
    }

    public static func displayLines(from value: String) -> [String] {
        value.components(separatedBy: .newlines)
            .map(stripANSI)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func runSynchronously(
        _ command: ScriptCommand,
        arguments: [String: String]
    ) throws -> ScriptExecutionResult {
        let missing = command.arguments.filter {
            $0.required && (arguments[$0.name] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if !missing.isEmpty {
            throw ScriptCommandExecutionError.missingArguments(missing.map(\.name))
        }

        let source: String
        do {
            source = try String(contentsOf: command.scriptURL, encoding: .utf8)
        } catch {
            throw ScriptCommandExecutionError.launchFailed(error.localizedDescription)
        }
        let firstSourceLine = source.components(separatedBy: .newlines).first ?? ""
        let invocation = makeInvocation(
            shebang: firstSourceLine,
            scriptURL: command.scriptURL,
            arguments: encodedArguments(for: command, values: arguments)
        )

        let process = Process()
        process.executableURL = invocation.executable
        process.arguments = invocation.arguments
        process.currentDirectoryURL = command.scriptURL.deletingLastPathComponent()
        var processEnvironment = environment
        if let loginPath = loginPath() {
            processEnvironment["PATH"] = loginPath
        }
        processEnvironment["RAYCAST_TITLE"] = command.title
        processEnvironment["RAYCAST_MODE"] = command.mode.rawValue
        processEnvironment["RAYCAST_COMMAND_ID"] = command.id
        processEnvironment["RAYCAST_SCRIPT_PATH"] = command.scriptURL.path
        processEnvironment["RAYCAST_PACKAGE_NAME"] = command.packageName
        process.environment = processEnvironment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        let stdout = DataAccumulator(limit: maximumOutputBytes)
        let stderr = DataAccumulator(limit: maximumOutputBytes)
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            stdout.append(handle.availableData)
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            stderr.append(handle.availableData)
        }

        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            throw ScriptCommandExecutionError.launchFailed(error.localizedDescription)
        }

        let state = ScriptProcessState()
        let timeoutWork = DispatchWorkItem {
            guard process.isRunning else { return }
            state.markTimedOut()
            process.terminate()
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1) {
                if process.isRunning {
                    kill(process.processIdentifier, SIGKILL)
                }
            }
        }
        DispatchQueue.global(qos: .userInitiated).asyncAfter(
            deadline: .now() + max(0.1, timeout),
            execute: timeoutWork
        )
        process.waitUntilExit()
        timeoutWork.cancel()

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        stdout.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
        stderr.append(stderrPipe.fileHandleForReading.readDataToEndOfFile())

        var stdoutText = stdout.string
        var stderrText = stderr.string
        if stdout.didOverflow {
            stdoutText += "\nOutput exceeded the size limit."
        }
        if stderr.didOverflow {
            stderrText += "\nError output exceeded the size limit."
        }
        if state.timedOut {
            stderrText += "\nScript timed out."
        }
        let combined = [stdoutText, stderrText]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = Self.displayLines(from: combined)
        let stdoutLines = Self.displayLines(from: stdoutText)

        return ScriptExecutionResult(
            commandID: command.id,
            mode: command.mode,
            exitCode: state.timedOut ? 124 : process.terminationStatus,
            stdout: stdoutText,
            stderr: stderrText,
            output: combined,
            firstLine: stdoutLines.first ?? lines.first ?? "",
            lastLine: lines.last ?? "",
            timedOut: state.timedOut
        )
    }

    private func encodedArguments(
        for command: ScriptCommand,
        values: [String: String]
    ) -> [String] {
        command.arguments.map { definition in
            let value = values[definition.name] ?? ""
            return definition.percentEncoded ? Self.percentEncode(value) : value
        }
    }

    private func makeInvocation(
        shebang: String,
        scriptURL: URL,
        arguments: [String]
    ) -> (executable: URL, arguments: [String]) {
        let trimmed = shebang.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#!") else {
            return (URL(fileURLWithPath: "/bin/bash"), [scriptURL.path] + arguments)
        }
        var parts = trimmed.dropFirst(2).split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard let executable = parts.first else {
            return (URL(fileURLWithPath: "/bin/bash"), [scriptURL.path] + arguments)
        }
        parts.removeFirst()
        if executable == "/usr/bin/env", parts.first == "-S" {
            parts.removeFirst()
        }
        return (URL(fileURLWithPath: executable), parts + [scriptURL.path] + arguments)
    }

    private func loginPath() -> String? {
        let shell = loginShellPath ?? systemLoginShell() ?? environment["SHELL"] ?? "/bin/zsh"
        guard FileManager.default.isExecutableFile(atPath: shell) else { return nil }
        let marker = "__OMNICAST_LOGIN_PATH__"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-l", "-c", "printf '\n\(marker)%s' \"$PATH\""]
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(decoding: data, as: UTF8.self)
            guard let markerRange = output.range(of: marker, options: .backwards) else {
                return nil
            }
            let value = output[markerRange.upperBound...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        } catch {
            return nil
        }
    }

    private func systemLoginShell() -> String? {
        guard let record = getpwuid(getuid()), let shell = record.pointee.pw_shell else {
            return nil
        }
        let value = String(cString: shell)
        return value.isEmpty ? nil : value
    }

    private static func percentEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "!\'()*-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static func stripANSI(_ value: String) -> String {
        value.replacingOccurrences(
            of: "\u{001B}\\[[0-9;]*m",
            with: "",
            options: .regularExpression
        )
    }
}

private final class DataAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private let limit: Int
    private var data = Data()
    private var overflow = false

    init(limit: Int) {
        self.limit = max(0, limit)
    }

    func append(_ value: Data) {
        guard !value.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        let remaining = max(0, limit - data.count)
        data.append(value.prefix(remaining))
        if value.count > remaining {
            overflow = true
        }
    }

    var string: String {
        lock.lock()
        defer { lock.unlock() }
        return String(decoding: data, as: UTF8.self)
    }

    var didOverflow: Bool {
        lock.lock()
        defer { lock.unlock() }
        return overflow
    }
}

private final class ScriptProcessState: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    func markTimedOut() {
        lock.lock()
        value = true
        lock.unlock()
    }

    var timedOut: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}
