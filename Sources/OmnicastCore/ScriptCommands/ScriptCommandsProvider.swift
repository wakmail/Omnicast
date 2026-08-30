// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public protocol ScriptArgumentTakingCommand: Command {
    var scriptArguments: [ScriptArgument] { get }

    @MainActor
    func execute(arguments: [String: String], context: CommandContext) async throws
}

public protocol ConfirmationRequiringCommand: Command {
    var needsConfirmation: Bool { get }
}

public struct ScriptExecutableCommand: ScriptArgumentTakingCommand, ConfirmationRequiringCommand {
    public let script: ScriptCommand
    public let runner: ScriptCommandRunner

    public var id: String { script.id }
    public var title: String { script.title }
    public var subtitle: String { script.packageName }
    public var icon: CommandIcon { Self.icon(for: script) }
    public var keywords: [String] { script.keywords }
    public let kind: CommandKind = .script
    public var resourceURL: URL? { script.scriptURL }
    public var scriptArguments: [ScriptArgument] { script.arguments }
    public var needsConfirmation: Bool { script.needsConfirmation }

    public init(script: ScriptCommand, runner: ScriptCommandRunner = ScriptCommandRunner()) {
        self.script = script
        self.runner = runner
    }

    @MainActor
    public func execute(context: CommandContext) async throws {
        try await execute(arguments: [:], context: context)
    }

    @MainActor
    public func execute(arguments: [String: String], context: CommandContext) async throws {
        let result = try await runner.run(script, arguments: arguments)
        if result.exitCode != 0 {
            if script.mode != .silent, !result.lastLine.isEmpty {
                context.toasts.show(result.lastLine)
            }
            throw ScriptCommandExecutionError.unsuccessful(
                exitCode: result.exitCode,
                message: result.lastLine
            )
        }
        switch script.mode {
        case .silent:
            break
        case .compact:
            if !result.lastLine.isEmpty {
                context.toasts.show(result.lastLine)
            }
        case .fullOutput:
            if !result.output.isEmpty {
                context.toasts.show(result.output)
            }
        case .inline:
            if !result.firstLine.isEmpty {
                context.toasts.show(result.firstLine)
            }
        }
    }

    private static func icon(for script: ScriptCommand) -> CommandIcon {
        guard let value = script.icon?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else {
            return .sfSymbol("terminal")
        }
        if let remoteURL = URL(string: value), ["http", "https"].contains(remoteURL.scheme) {
            return .image(remoteURL)
        }
        let expanded: String
        if value.hasPrefix("~/") {
            expanded = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(String(value.dropFirst(2))).path
        } else {
            expanded = value
        }
        let fileURL = expanded.hasPrefix("/")
            ? URL(fileURLWithPath: expanded)
            : script.scriptURL.deletingLastPathComponent().appendingPathComponent(expanded)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return .image(fileURL)
        }
        if value.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation }) {
            return .emoji(value)
        }
        return .sfSymbol("terminal")
    }
}

public struct ScriptCommandsProvider: CommandProvider {
    public let directories: [URL]
    public let runner: ScriptCommandRunner

    public init(
        directories: [URL] = ScriptCommandsProvider.defaultDirectories,
        runner: ScriptCommandRunner = ScriptCommandRunner()
    ) {
        self.directories = directories
        self.runner = runner
    }

    public func commands() async -> [any Command] {
        let directories = directories
        let scripts = await Task.detached(priority: .utility) {
            Self.scan(directories: directories)
        }.value
        return scripts.map { ScriptExecutableCommand(script: $0, runner: runner) as any Command }
    }

    public static var defaultDirectories: [URL] {
        [OmnicastDataDirectory.defaultURL.appendingPathComponent("scripts", isDirectory: true)]
    }

    private static func scan(directories: [URL]) -> [ScriptCommand] {
        let manager = FileManager.default
        var scripts: [ScriptCommand] = []
        var seen = Set<URL>()
        for directory in directories {
            guard let enumerator = manager.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }
            for case let url as URL in enumerator {
                if ["node_modules", ".git"].contains(url.lastPathComponent) {
                    enumerator.skipDescendants()
                    continue
                }
                guard !url.lastPathComponent.contains(".template."),
                      seen.insert(url.standardizedFileURL).inserted,
                      let values = try? url.resourceValues(forKeys: [.isRegularFileKey]),
                      values.isRegularFile == true,
                      let script = try? ScriptCommandParser.parse(contentsOf: url)
                else {
                    continue
                }
                scripts.append(script)
            }
        }
        return scripts.sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }
}
