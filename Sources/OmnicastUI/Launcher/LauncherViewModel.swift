// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation
import OmnicastCore

@MainActor
final class LauncherViewModel: ObservableObject {
    @Published var query = "" {
        didSet { updateResults() }
    }
    @Published private(set) var results: [RankedCommand] = []
    @Published var selectedIndex = 0
    @Published var actionPanelVisible = false
    @Published private(set) var isLoading = true

    let context: CommandContext
    private let registry: CommandRegistry
    private let frecencyStore: FrecencyStore
    private let keyEvents: LauncherKeyEvents
    private let onHide: (Bool) -> Void
    private let onOpenSettings: () -> Void
    private var commands: [any Command] = []
    private var subscriptions = Set<AnyCancellable>()

    init(
        registry: CommandRegistry,
        context: CommandContext,
        frecencyStore: FrecencyStore,
        keyEvents: LauncherKeyEvents,
        onHide: @escaping (Bool) -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.registry = registry
        self.context = context
        self.frecencyStore = frecencyStore
        self.keyEvents = keyEvents
        self.onHide = onHide
        self.onOpenSettings = onOpenSettings

        keyEvents.$latest
            .compactMap { $0?.key }
            .sink { [weak self] key in self?.handle(key) }
            .store(in: &subscriptions)

        Task { await loadCommands() }
    }

    var selectedCommand: (any Command)? {
        guard results.indices.contains(selectedIndex) else { return nil }
        return results[selectedIndex].command
    }

    func select(_ index: Int) {
        selectedIndex = index
    }

    func executeSelected() {
        guard let command = selectedCommand else { return }
        let launchQuery = query
        actionPanelVisible = false
        onHide(true)

        Task {
            do {
                try await command.execute(context: context)
                try frecencyStore.recordLaunch(commandID: command.id, query: launchQuery)
            } catch {
                context.toasts.show(error.localizedDescription)
            }
        }
    }

    func revealSelected() {
        guard let url = selectedCommand?.resourceURL else { return }
        context.opener.reveal(url)
        actionPanelVisible = false
        onHide(true)
    }

    func copySelectedPath() {
        guard let path = selectedCommand?.resourceURL?.path else { return }
        context.clipboard.writeText(path)
        context.toasts.show("Path copied")
        actionPanelVisible = false
    }

    private func loadCommands() async {
        commands = await registry.commands()
        isLoading = false
        updateResults()
    }

    private func updateResults() {
        results = SearchRanker.rank(
            commands,
            query: query,
            frecency: frecencyStore.entries
        )
        selectedIndex = min(selectedIndex, max(0, results.count - 1))
    }

    private func handle(_ key: LauncherKey) {
        switch key {
        case .moveUp:
            selectedIndex = max(0, selectedIndex - 1)
        case .moveDown:
            selectedIndex = min(max(0, results.count - 1), selectedIndex + 1)
        case .enter:
            executeSelected()
        case .escape:
            actionPanelVisible = false
            onHide(true)
        case .actions:
            actionPanelVisible.toggle()
        case .settings:
            onOpenSettings()
        }
    }
}
