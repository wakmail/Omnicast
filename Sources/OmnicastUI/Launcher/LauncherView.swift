// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import SwiftUI

public struct LauncherView: View {
    @StateObject private var model: LauncherViewModel
    @ObservedObject private var toasts: ToastCenter
    @ObservedObject private var settingsStore: SettingsStore
    @Environment(\.colorScheme) private var colorScheme
    private let onImportRayconfig: (URL) -> Void

    @MainActor
    public init(
        registry: CommandRegistry,
        context: CommandContext,
        frecencyStore: FrecencyStore,
        keyEvents: LauncherKeyEvents,
        toasts: ToastCenter,
        settingsStore: SettingsStore,
        webSearchBangs: WebSearchBangs = WebSearchBangs(),
        calculatorProvider: CalculatorProvider = CalculatorProvider(),
        presentingCommands: [String: LauncherCommandPresenter] = [:],
        navigationCoordinator: LauncherNavigationCoordinator? = nil,
        onImportRayconfig: @escaping (URL) -> Void = { _ in },
        onHide: @escaping (Bool) -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        _model = StateObject(wrappedValue: LauncherViewModel(
            registry: registry,
            context: context,
            frecencyStore: frecencyStore,
            keyEvents: keyEvents,
            webSearchBangs: webSearchBangs,
            calculatorProvider: calculatorProvider,
            presentingCommands: presentingCommands,
            navigationCoordinator: navigationCoordinator ?? LauncherNavigationCoordinator(),
            onHide: onHide,
            onOpenSettings: onOpenSettings
        ))
        self.toasts = toasts
        self.settingsStore = settingsStore
        self.onImportRayconfig = onImportRayconfig
    }

    public var body: some View {
        ZStack {
            VisualEffectBackground(material: .underWindowBackground)
            LauncherTheme.Palette.surface(for: colorScheme)

            VStack(spacing: 0) {
                launcherHeader

                divider

                if let presentedView = model.presentedView {
                    presentedView.content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    resultList
                }

                divider

                footer
            }

            if let message = toasts.message {
                VStack {
                    Spacer()
                    Text(message)
                        .font(LauncherTheme.Typography.toast)
                        .foregroundStyle(LauncherTheme.Palette.primaryText(for: colorScheme))
                        .padding(.horizontal, LauncherTheme.Metrics.toastHorizontalPadding)
                        .padding(.vertical, LauncherTheme.Metrics.toastVerticalPadding)
                        .background(LauncherTheme.Palette.toastSurface(for: colorScheme), in: Capsule())
                        .padding(.bottom, LauncherTheme.Metrics.toastBottomPadding)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(
                    .easeOut(duration: LauncherTheme.Metrics.toastAnimationDuration),
                    value: message
                )
            }
        }
        .frame(
            width: LauncherTheme.Metrics.panelWidth,
            height: LauncherTheme.Metrics.panelHeight(for: settingsStore.settings.windowMode)
        )
        .clipShape(panelShape)
        .overlay {
            panelShape.strokeBorder(
                LauncherTheme.Palette.borderPrimary(for: colorScheme),
                lineWidth: LauncherTheme.Metrics.borderWidth
            )
        }
        .onDrop(of: RayconfigDropReceiver.typeIdentifiers, isTargeted: nil) { providers in
            guard model.isAtRoot else { return false }
            return RayconfigDropReceiver.receive(providers) { result in
                switch result {
                case .success(let url):
                    onImportRayconfig(url)
                case .failure(let error):
                    toasts.show(error.localizedDescription)
                }
            }
        }
    }

    @ViewBuilder
    private var launcherHeader: some View {
        if model.presentedView?.showsSearchField == false {
            HStack {
                Text(model.presentedView?.title ?? "Omnicast")
                    .font(LauncherTheme.Typography.search)
                    .foregroundStyle(LauncherTheme.Palette.primaryText(for: colorScheme))
                Spacer()
            }
            .frame(height: LauncherTheme.Metrics.searchHeight)
            .padding(.horizontal, LauncherTheme.Metrics.searchHorizontalPadding)
        } else {
            HStack(spacing: LauncherTheme.Metrics.searchIconSpacing) {
                Image(systemName: "magnifyingglass")
                    .font(.system(
                        size: LauncherTheme.Metrics.searchIconSize,
                        weight: .medium
                    ))
                    .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))

                LauncherSearchField(
                    text: $model.query,
                    placeholder: model.searchPlaceholder
                )
            }
            .frame(height: LauncherTheme.Metrics.searchHeight)
            .padding(.horizontal, LauncherTheme.Metrics.searchHorizontalPadding)
        }
    }

    private var resultList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Text("RESULTS")
                        .font(LauncherTheme.Typography.section)
                        .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
                        .padding(.leading, LauncherTheme.Metrics.sectionLeadingPadding)
                        .padding(.top, LauncherTheme.Metrics.sectionTopPadding)
                        .padding(.bottom, LauncherTheme.Metrics.sectionBottomPadding)

                    if model.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if model.results.isEmpty {
                        Text("No matching commands")
                            .font(LauncherTheme.Typography.emptyState)
                            .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ForEach(Array(model.results.enumerated()), id: \.element.command.id) { index, result in
                            CommandRowView(
                                command: result.command,
                                isSelected: index == model.selectedIndex
                            )
                            .padding(.horizontal, LauncherTheme.Metrics.rowOuterInset)
                            .id(result.command.id)
                            .contentShape(Rectangle())
                            .onAppear {
                                prefetchIcons(startingAt: index)
                            }
                            .onTapGesture {
                                model.select(index)
                                model.executeSelected()
                            }
                            .onHover { hovering in
                                model.selectionCameFromKeyboard = false
                                if hovering { model.select(index) }
                            }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .onChange(of: model.selectedIndex) {
                guard model.selectionCameFromKeyboard else { return }
                if let command = model.selectedCommand {
                    proxy.scrollTo(command.id)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: LauncherTheme.Metrics.footerIconTitleSpacing) {
            if !model.isAtRoot {
                Text(model.presentedView?.title ?? "Feature")
                    .font(LauncherTheme.Typography.footerTitle)
                    .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
                    .lineLimit(1)
            } else if case .confirmation(let title) = model.inputMode {
                Text("Confirm \(title)")
                    .font(LauncherTheme.Typography.footerTitle)
                    .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
                    .lineLimit(1)
            } else if case .argument(_, let progress) = model.inputMode {
                Text(progress)
                    .font(LauncherTheme.Typography.footerTitle)
                    .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
            } else if let command = model.selectedCommand {
                CommandIconView(icon: command.icon)
                    .frame(
                        width: LauncherTheme.Metrics.footerIconSize,
                        height: LauncherTheme.Metrics.footerIconSize
                    )
                    .clipShape(RoundedRectangle(
                        cornerRadius: LauncherTheme.Metrics.footerIconCornerRadius,
                        style: .continuous
                    ))

                Text(command.title)
                    .font(LauncherTheme.Typography.footerTitle)
                    .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
                    .lineLimit(1)
            } else {
                Text("No selection")
                    .font(LauncherTheme.Typography.footerTitle)
                    .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
            }

            Spacer()

            HStack(spacing: LauncherTheme.Metrics.footerGroupSpacing) {
                if !model.isAtRoot {
                    FooterActionButton("Back", keys: ["Esc"]) {
                        _ = model.pop()
                    }
                } else if case .confirmation = model.inputMode {
                    FooterActionButton("Confirm", keys: ["Enter"]) {
                        model.executeSelected()
                    }
                    FooterActionButton("Cancel", keys: ["Esc"]) {
                        model.cancelInputFromFooter()
                    }
                } else if case .argument = model.inputMode {
                    FooterActionButton("Continue", keys: ["Enter"]) {
                        model.executeSelected()
                    }
                    FooterActionButton("Cancel", keys: ["Esc"]) {
                        model.cancelInputFromFooter()
                    }
                } else {
                    FooterActionButton("Open", keys: ["Enter"]) {
                        model.executeSelected()
                    }
                    .disabled(model.selectedCommand == nil)

                    FooterActionButton("Actions", keys: ["⌘", "K"]) {
                        model.actionPanelVisible.toggle()
                    }
                    .popover(isPresented: $model.actionPanelVisible, arrowEdge: .bottom) {
                        actionPanel
                    }
                }
            }
        }
        .padding(.horizontal, LauncherTheme.Metrics.footerHorizontalPadding)
        .frame(height: LauncherTheme.Metrics.footerHeight)
    }

    private var actionPanel: some View {
        VStack(alignment: .leading, spacing: LauncherTheme.Metrics.actionPanelSpacing) {
            Button("Open") { model.executeSelected() }

            if model.selectedCommand?.resourceURL != nil {
                Button("Show in Finder") { model.revealSelected() }
                Button("Copy path") { model.copySelectedPath() }
            }
        }
        .buttonStyle(.plain)
        .padding(LauncherTheme.Metrics.actionPanelPadding)
        .frame(width: LauncherTheme.Metrics.actionPanelWidth, alignment: .leading)
    }

    private var divider: some View {
        LauncherTheme.Palette.borderPrimary(for: colorScheme)
            .frame(height: LauncherTheme.Metrics.dividerHeight)
    }

    private func prefetchIcons(startingAt index: Int) {
        let endIndex = min(
            model.results.endIndex,
            index + LauncherTheme.Metrics.iconPrefetchLookahead + 1
        )
        let urls = model.results[index..<endIndex].compactMap { result -> URL? in
            guard case .image(let url) = result.command.icon else { return nil }
            return url
        }
        RemoteIconPrefetcher.prefetch(urls)
    }

    private var panelShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: LauncherTheme.Metrics.panelCornerRadius,
            style: .continuous
        )
    }
}
