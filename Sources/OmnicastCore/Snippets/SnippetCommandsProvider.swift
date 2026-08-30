// SPDX-License-Identifier: GPL-3.0-or-later

import ApplicationServices
import Foundation

public struct SnippetCommandsProvider: CommandProvider {
    private let store: SnippetStore
    private let openManager: @MainActor @Sendable () -> Void

    @MainActor
    public init(
        store: SnippetStore,
        openManager: @escaping @MainActor @Sendable () -> Void
    ) {
        self.store = store
        self.openManager = openManager
    }

    public func commands() async -> [any Command] {
        let snippets = await MainActor.run { store.snippets }
        var commands: [any Command] = [
            SearchSnippetsCommand(openManager: openManager)
        ]
        commands.append(contentsOf: snippets.map { snippet in
            SnippetPasteCommand(snippet: snippet, store: store)
        })
        return commands
    }
}

private struct SearchSnippetsCommand: Command {
    let id = "snippets.search"
    let title = "Search Snippets"
    let subtitle = "Browse and edit saved snippets"
    let icon = CommandIcon.sfSymbol("text.quote")
    let keywords = ["snippets", "text", "manager"]
    let kind = CommandKind.snippet
    let openManager: @MainActor @Sendable () -> Void

    @MainActor
    func execute(context: CommandContext) async throws {
        openManager()
    }
}

private struct SnippetPasteCommand: Command {
    let snippet: Snippet
    let store: SnippetStore

    var id: String { "snippet.\(snippet.id.uuidString)" }
    var title: String { snippet.name }
    var subtitle: String { snippet.keyword ?? snippet.content }
    var icon: CommandIcon { .sfSymbol("text.quote") }
    var keywords: [String] { [snippet.keyword, snippet.content].compactMap { $0 } }
    var kind: CommandKind { .snippet }

    @MainActor
    func execute(context: CommandContext) async throws {
        let rendered = SnippetPlaceholderRenderer.render(
            snippet.content,
            context: SnippetPlaceholderContext(
                clipboard: context.clipboard.readText() ?? "",
                selection: commandSelectionText(),
                date: Date(),
                uuid: UUID()
            )
        )
        context.clipboard.writeText(rendered.text)
        try await SnippetPasteHelper.paste(
            cursorOffsetFromEnd: rendered.cursorOffsetFromEnd ?? 0
        )
        _ = try store.recordUse(id: snippet.id)
    }

    private func commandSelectionText() -> String {
        let system = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            system,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success, let focusedValue else {
            return ""
        }
        let focused = focusedValue as! AXUIElement
        var selectedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            focused,
            kAXSelectedTextAttribute as CFString,
            &selectedValue
        ) == .success else {
            return ""
        }
        return selectedValue as? String ?? ""
    }
}
