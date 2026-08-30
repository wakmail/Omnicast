// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import SwiftUI

public struct LauncherView: View {
    @StateObject private var model: LauncherViewModel
    @ObservedObject private var toasts: ToastCenter
    @Environment(\.colorScheme) private var colorScheme

    @MainActor
    public init(
        registry: CommandRegistry,
        context: CommandContext,
        frecencyStore: FrecencyStore,
        keyEvents: LauncherKeyEvents,
        toasts: ToastCenter,
        webSearchBangs: WebSearchBangs = WebSearchBangs(),
        presentingCommands: [String: LauncherCommandPresenter] = [:],
        navigationCoordinator: LauncherNavigationCoordinator? = nil,
        onHide: @escaping (Bool) -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        _model = StateObject(wrappedValue: LauncherViewModel(
            registry: registry,
            context: context,
            frecencyStore: frecencyStore,
            keyEvents: keyEvents,
            webSearchBangs: webSearchBangs,
            presentingCommands: presentingCommands,
            navigationCoordinator: navigationCoordinator ?? LauncherNavigationCoordinator(),
            onHide: onHide,
            onOpenSettings: onOpenSettings
        ))
        self.toasts = toasts
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
            height: LauncherTheme.Metrics.panelHeight
        )
        .clipShape(panelShape)
        .overlay {
            panelShape.strokeBorder(
                LauncherTheme.Palette.borderPrimary(for: colorScheme),
                lineWidth: LauncherTheme.Metrics.borderWidth
            )
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
            LauncherSearchField(
                text: $model.query,
                placeholder: model.searchPlaceholder
            )
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
                    HStack(spacing: LauncherTheme.Metrics.footerLabelSpacing) {
                        Text("Back")
                            .font(LauncherTheme.Typography.footerAction)
                            .foregroundStyle(LauncherTheme.Palette.primaryText(for: colorScheme))
                        KeyCap("Esc")
                    }
                } else if case .confirmation = model.inputMode {
                    footerHint("Confirm", key: "Enter")
                    footerHint("Cancel", key: "Esc")
                } else if case .argument = model.inputMode {
                    footerHint("Continue", key: "Enter")
                    footerHint("Cancel", key: "Esc")
                } else {
                    footerHint("Open", key: "Enter")

                    Button {
                        model.actionPanelVisible.toggle()
                    } label: {
                        HStack(spacing: LauncherTheme.Metrics.footerLabelSpacing) {
                            Text("Actions")
                                .font(LauncherTheme.Typography.footerTitle)
                                .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
                            HStack(spacing: LauncherTheme.Metrics.keyCapSpacing) {
                                KeyCap("⌘")
                                KeyCap("K")
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $model.actionPanelVisible, arrowEdge: .bottom) {
                        actionPanel
                    }
                }
            }
        }
        .padding(.horizontal, LauncherTheme.Metrics.footerHorizontalPadding)
        .frame(height: LauncherTheme.Metrics.footerHeight)
    }

    private func footerHint(_ title: String, key: String) -> some View {
        HStack(spacing: LauncherTheme.Metrics.footerLabelSpacing) {
            Text(title)
                .font(LauncherTheme.Typography.footerAction)
                .foregroundStyle(LauncherTheme.Palette.primaryText(for: colorScheme))
            KeyCap(key)
        }
    }

    private var actionPanel: some View {
        VStack(alignment: .leading, spacing: LauncherTheme.Metrics.actionPanelSpacing) {
            Button("Open") { model.executeSelected() }
                .keyboardShortcut(.return, modifiers: [])

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

    private var panelShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: LauncherTheme.Metrics.panelCornerRadius,
            style: .continuous
        )
    }
}

private struct KeyCap: View {
    let label: String
    @Environment(\.colorScheme) private var colorScheme

    init(_ label: String) {
        self.label = label
    }

    var body: some View {
        Text(label)
            .font(LauncherTheme.Typography.keyCap)
            .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
            .padding(.horizontal, LauncherTheme.Metrics.keyCapHorizontalPadding)
            .frame(
                minWidth: LauncherTheme.Metrics.keyCapMinimumWidth,
                minHeight: LauncherTheme.Metrics.keyCapHeight,
                maxHeight: LauncherTheme.Metrics.keyCapHeight
            )
            .background(
                LauncherTheme.Palette.keyCap(for: colorScheme),
                in: RoundedRectangle(
                    cornerRadius: LauncherTheme.Metrics.keyCapCornerRadius,
                    style: .continuous
                )
            )
    }
}
