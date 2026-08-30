// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct SystemCommandsProvider: CommandProvider {
    public init() {}

    public func commands() async -> [any Command] {
        [
            SystemCommand(
                id: "system:sleep",
                title: "Sleep",
                subtitle: "Put the Mac to sleep",
                iconName: "moon.fill",
                keywords: ["power", "rest", "suspend"],
                action: .sleep
            ),
            SystemCommand(
                id: "system:restart",
                title: "Restart",
                subtitle: "Restart the Mac",
                iconName: "arrow.clockwise",
                keywords: ["reboot", "power", "reset"],
                action: .restart
            ),
            SystemCommand(
                id: "system:shutdown",
                title: "Shut Down",
                subtitle: "Shut down the Mac",
                iconName: "power",
                keywords: ["shutdown", "power off", "halt"],
                action: .shutDown
            ),
            SystemCommand(
                id: "system:lock-screen",
                title: "Lock Screen",
                subtitle: "Lock the screen",
                iconName: "lock.fill",
                keywords: ["security", "password"],
                action: .lockScreen
            ),
            SystemCommand(
                id: "system:log-out",
                title: "Log Out",
                subtitle: "Log out of the current session",
                iconName: "rectangle.portrait.and.arrow.right",
                keywords: ["logout", "sign out", "user"],
                action: .logOut
            ),
            SystemCommand(
                id: "system:empty-trash",
                title: "Empty Trash",
                subtitle: "Permanently delete items in Trash",
                iconName: "trash.fill",
                keywords: ["delete", "bin", "clean"],
                action: .emptyTrash
            ),
            SystemCommand(
                id: "system:show-desktop",
                title: "Show Desktop",
                subtitle: "Move windows aside",
                iconName: "macwindow",
                keywords: ["desktop", "windows", "finder"],
                action: .showDesktop
            )
        ]
    }
}

public struct SystemCommand: Command {
    public let id: String
    public let title: String
    public let subtitle: String
    public let icon: CommandIcon
    public let keywords: [String]
    public let kind: CommandKind = .system
    private let action: SystemAction

    fileprivate init(
        id: String,
        title: String,
        subtitle: String,
        iconName: String,
        keywords: [String],
        action: SystemAction
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        icon = .sfSymbol(iconName)
        self.keywords = keywords
        self.action = action
    }

    @MainActor
    public func execute(context: CommandContext) async throws {
        try await Task.detached(priority: .userInitiated) {
            try SystemActionRunner.run(action)
        }.value
        context.toasts.show("\(title) requested")
    }
}

private enum SystemAction: Sendable {
    case sleep
    case restart
    case shutDown
    case lockScreen
    case logOut
    case emptyTrash
    case showDesktop
}

private enum SystemActionRunner {
    static func run(_ action: SystemAction) throws {
        switch action {
        case .sleep:
            try runExecutable("/usr/bin/pmset", arguments: ["sleepnow"])
        case .restart:
            try runAppleScript("tell application \"Finder\" to restart")
        case .shutDown:
            try runAppleScript("tell application \"Finder\" to shut down")
        case .lockScreen:
            try runAppleScript(
                "tell application \"System Events\" to keystroke \"q\" using {command down, control down}"
            )
        case .logOut:
            try runAppleScript("tell application \"Finder\" to log out")
        case .emptyTrash:
            try runAppleScript("tell application \"Finder\" to empty trash")
        case .showDesktop:
            try runAppleScript("tell application \"System Events\" to key code 103")
        }
    }

    private static func runAppleScript(_ source: String) throws {
        try runExecutable("/usr/bin/osascript", arguments: ["-e", source])
    }

    private static func runExecutable(_ path: String, arguments: [String]) throws {
        let process = Process()
        let standardError = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardError = standardError
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = standardError.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw SystemCommandError.failed(message ?? "The system command failed")
        }
    }
}

public enum SystemCommandError: LocalizedError {
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .failed(let message): message
        }
    }
}
