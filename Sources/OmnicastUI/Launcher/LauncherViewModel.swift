// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation
import OmnicastCore
import SwiftUI

@MainActor
final class LauncherViewModel: ObservableObject {
    @Published var query = "" {
        didSet { queryDidChange() }
    }
    @Published private(set) var results: [RankedCommand] = []
    @Published var selectedIndex = 0
    var selectionCameFromKeyboard = true
    @Published var actionPanelVisible = false
    @Published private(set) var isLoading = true
    @Published private(set) var navigationDepth = 0
    @Published private(set) var inputMode: LauncherInputMode = .browsing

    let context: CommandContext
    private let registry: CommandRegistry
    private let frecencyStore: FrecencyStore
    private let keyEvents: LauncherKeyEvents
    private let webSearchBangs: WebSearchBangs
    private let calculatorProvider: CalculatorProvider
    private let presentingCommands: [String: LauncherCommandPresenter]
    private let onHide: (Bool) -> Void
    private let onOpenSettings: () -> Void
    private var commands: [any Command] = []
    private var navigation = LauncherNavigationStack<NavigationEntry>()
    private var pendingCommand: (any Command)?
    private var pendingLaunchQuery = ""
    private var argumentState: LauncherArgumentState?
    private var pendingArgument: String?
    private var pendingScriptArguments: [String: String]?
    private var subscriptions = Set<AnyCancellable>()

    init(
        registry: CommandRegistry,
        context: CommandContext,
        frecencyStore: FrecencyStore,
        keyEvents: LauncherKeyEvents,
        webSearchBangs: WebSearchBangs,
        calculatorProvider: CalculatorProvider,
        presentingCommands: [String: LauncherCommandPresenter],
        navigationCoordinator: LauncherNavigationCoordinator,
        onHide: @escaping (Bool) -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.registry = registry
        self.context = context
        self.frecencyStore = frecencyStore
        self.keyEvents = keyEvents
        self.webSearchBangs = webSearchBangs
        self.calculatorProvider = calculatorProvider
        self.presentingCommands = presentingCommands
        self.onHide = onHide
        self.onOpenSettings = onOpenSettings

        keyEvents.$latest
            .compactMap { $0?.key }
            .sink { [weak self] key in self?.handle(key) }
            .store(in: &subscriptions)

        navigationCoordinator.$latest
            .compactMap { $0?.action }
            .sink { [weak self] action in self?.handle(action) }
            .store(in: &subscriptions)

        Task { await reloadCommands() }
    }

    var selectedCommand: (any Command)? {
        guard results.indices.contains(selectedIndex) else { return nil }
        return results[selectedIndex].command
    }

    var presentedView: LauncherPresentedView? { navigation.current?.view }
    var isAtRoot: Bool { navigation.isRoot }

    var searchPlaceholder: String {
        switch inputMode {
        case .argument(let placeholder, _):
            placeholder
        case .confirmation:
            "Press Enter to confirm"
        case .browsing:
            presentedView?.showsSearchField == true
                ? "Search \(presentedView?.title ?? "")"
                : "Search for apps and commands"
        }
    }

    func select(_ index: Int) {
        selectedIndex = index
    }

    func executeSelected(commandEnter: Bool = false) {
        switch inputMode {
        case .argument:
            advanceArgument(allowingEmpty: commandEnter)
            return
        case .confirmation:
            executePending()
            return
        case .browsing:
            break
        }

        guard let command = selectedCommand else { return }
        if let command = command as? any ViewPresentingCommand,
           let presenter = presentingCommands[command.presentationID] {
            push(presenter(command, query))
            return
        }

        pendingCommand = command
        pendingLaunchQuery = query

        if let scriptCommand = command as? any ScriptArgumentTakingCommand,
           !scriptCommand.scriptArguments.isEmpty {
            beginArguments(scriptCommand.scriptArguments.map {
                LauncherArgumentDefinition(
                    name: $0.name,
                    placeholder: $0.placeholder.isEmpty ? $0.name : $0.placeholder,
                    isRequired: $0.required
                )
            })
            if commandEnter {
                advanceArgument(allowingEmpty: true)
            }
            return
        }

        if let argumentCommand = command as? any ArgumentTakingCommand,
           argumentCommand.requiresArgument {
            beginArguments([
                LauncherArgumentDefinition(
                    name: "argument",
                    placeholder: argumentCommand.argumentPlaceholder,
                    isRequired: true
                )
            ])
            if commandEnter {
                advanceArgument(allowingEmpty: true)
            }
            return
        }

        finishPreparation()
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

    func push(_ view: LauncherPresentedView) {
        cancelInput(restoringQuery: false)
        let previousQuery = query
        navigation.push(NavigationEntry(view: view, previousQuery: previousQuery))
        navigationDepth = navigation.depth
        if let initialQuery = view.initialQuery {
            query = initialQuery
        } else {
            view.onQueryChange(query)
        }
        actionPanelVisible = false
    }

    @discardableResult
    func pop() -> Bool {
        guard let entry = navigation.pop() else { return false }
        entry.view.onDismiss()
        navigationDepth = navigation.depth
        query = entry.previousQuery
        navigation.current?.view.onQueryChange(query)
        return true
    }

    func resetNavigation() {
        while let entry = navigation.pop() {
            entry.view.onDismiss()
        }
        navigationDepth = 0
        cancelInput(restoringQuery: false)
        updateResults()
    }

    func reloadCommands() async {
        commands = await registry.commands(forceRefresh: true)
        isLoading = false
        updateResults()
    }

    private func beginArguments(_ definitions: [LauncherArgumentDefinition]) {
        guard let first = definitions.first else {
            finishPreparation()
            return
        }
        argumentState = LauncherArgumentState(definitions: definitions)
        query = ""
        inputMode = .argument(
            placeholder: first.placeholder,
            progress: argumentState?.progress ?? ""
        )
    }

    private func advanceArgument(allowingEmpty: Bool) {
        guard var state = argumentState else { return }
        switch state.submit(query, allowingEmpty: allowingEmpty) {
        case .needsValue(let placeholder):
            context.toasts.show("\(placeholder) is required")
        case .next(let definition):
            argumentState = state
            query = ""
            inputMode = .argument(
                placeholder: definition.placeholder,
                progress: state.progress
            )
            if allowingEmpty, !definition.isRequired {
                advanceArgument(allowingEmpty: true)
            }
        case .complete(let values):
            argumentState = nil
            if pendingCommand is any ScriptArgumentTakingCommand {
                pendingScriptArguments = values
            } else {
                pendingArgument = values["argument"] ?? ""
            }
            finishPreparation()
        }
    }

    private func finishPreparation() {
        guard let pendingCommand else { return }
        if let confirmation = pendingCommand as? any ConfirmationRequiringCommand,
           confirmation.needsConfirmation {
            query = ""
            inputMode = .confirmation(commandTitle: pendingCommand.title)
        } else {
            executePending()
        }
    }

    private func executePending() {
        guard let command = pendingCommand else { return }
        let launchQuery = pendingLaunchQuery
        let argument = pendingArgument
        let scriptArguments = pendingScriptArguments ?? [:]

        if let scriptCommand = command as? ScriptExecutableCommand,
           (scriptCommand.script.mode == .fullOutput || scriptCommand.script.mode == .inline) {
            clearPending()
            query = launchQuery
            actionPanelVisible = false
            let model = ScriptOutputViewModel(
                command: scriptCommand,
                arguments: scriptArguments
            )
            push(LauncherPresentedView(
                title: scriptCommand.title,
                content: AnyView(ScriptOutputView(model: model)),
                showsSearchField: false,
                initialQuery: "",
                onDismiss: { [weak model] in model?.stop() }
            ))
            do {
                try frecencyStore.recordLaunch(commandID: command.id, query: launchQuery)
            } catch {
                context.toasts.show(error.localizedDescription)
            }
            return
        }

        clearPending()
        query = launchQuery
        actionPanelVisible = false
        if command.kind != .extensionCommand {
            onHide(true)
        }

        Task {
            do {
                if let command = command as? any ScriptArgumentTakingCommand {
                    try await command.execute(arguments: scriptArguments, context: context)
                } else if let command = command as? any ArgumentTakingCommand,
                          let argument {
                    try await command.execute(argument: argument, context: context)
                } else {
                    try await command.execute(context: context)
                }
                try frecencyStore.recordLaunch(commandID: command.id, query: launchQuery)
            } catch {
                context.toasts.show(error.localizedDescription)
            }
        }
    }

    private func cancelInput(restoringQuery: Bool = true) {
        let restored = pendingLaunchQuery
        clearPending()
        if restoringQuery {
            query = restored
        }
    }

    private func clearPending() {
        pendingCommand = nil
        pendingArgument = nil
        pendingScriptArguments = nil
        argumentState = nil
        pendingLaunchQuery = ""
        inputMode = .browsing
    }

    private func queryDidChange() {
        guard inputMode == .browsing else { return }
        if let presentedView {
            presentedView.onQueryChange(query)
        } else {
            updateResults()
        }
    }

    private func updateResults() {
        guard navigation.isRoot, inputMode == .browsing else { return }
        var resolved = LauncherSearchResults.resolve(
            commands: commands,
            query: query,
            frecency: frecencyStore.entries,
            bangs: webSearchBangs
        )
        if let calculation = calculatorProvider.inlineResult(for: query) {
            resolved.removeAll { $0.command.id == calculation.id }
            resolved.insert(RankedCommand(command: calculation, score: .infinity), at: 0)
        }
        results = resolved
        selectionCameFromKeyboard = true
        selectedIndex = min(selectedIndex, max(0, results.count - 1))
    }

    private func handle(_ action: LauncherNavigationCoordinator.Action) {
        switch action {
        case .push(let view):
            push(view)
        case .pop:
            _ = pop()
        case .reset:
            resetNavigation()
        case .reloadCommands:
            Task { await reloadCommands() }
        }
    }

    private func handle(_ key: LauncherKey) {
        if key == .escape {
            if actionPanelVisible {
                actionPanelVisible = false
                return
            }
            if inputMode != .browsing {
                cancelInput()
                return
            }
            if pop() { return }
            onHide(true)
            return
        }

        if inputMode == .browsing,
           let presentedView,
           presentedView.onKey(key) {
            return
        }

        switch key {
        case .moveUp:
            selectionCameFromKeyboard = true
            selectedIndex = max(0, selectedIndex - 1)
        case .moveDown:
            selectionCameFromKeyboard = true
            selectedIndex = min(max(0, results.count - 1), selectedIndex + 1)
        case .enter:
            executeSelected()
        case .commandEnter:
            executeSelected(commandEnter: true)
        case .actions:
            if isAtRoot { actionPanelVisible.toggle() }
        case .settings:
            onOpenSettings()
        case .escape:
            break
        }
    }
}

private struct NavigationEntry {
    let view: LauncherPresentedView
    let previousQuery: String
}
