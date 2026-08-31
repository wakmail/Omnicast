// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import OmnicastExtensions
import OmnicastUI
import SwiftUI

struct ExtensionStoreCommand: ViewPresentingCommand {
    let id = "extension:store"
    let title = "Extension Store"
    let subtitle = "Browse and install extensions"
    let icon = CommandIcon.sfSymbol("puzzlepiece.extension")
    let keywords = ["store"]
    let kind = CommandKind.extensionCommand

    @MainActor
    func execute(context: CommandContext) async throws {}
}

struct ExtensionStoreCommandsProvider: CommandProvider {
    func commands() async -> [any Command] {
        [ExtensionStoreCommand()]
    }
}

@MainActor
// Native fallback retained for recovery if the hosted Store cannot launch.
enum ExtensionStoreLauncherPresentation {
    static func presentedView(
        catalog: RaycastStoreCatalog,
        registry: ExtensionRegistry,
        navigation: LauncherNavigationCoordinator,
        onRegistryChanged: @escaping @MainActor () -> Void
    ) -> LauncherPresentedView {
        let model = ExtensionStoreViewModel(
            catalog: catalog,
            registry: registry,
            onRegistryChanged: onRegistryChanged
        )
        let openDetail: (RaycastStoreExtension) -> Void = { [weak model] extensionValue in
            guard let model else { return }
            navigation.push(detailView(extensionValue: extensionValue, model: model))
        }
        return LauncherPresentedView(
            title: "Extension Store",
            content: AnyView(ExtensionStoreLauncherView(
                model: model,
                openDetail: openDetail
            )),
            initialQuery: "",
            onQueryChange: { [weak model] in model?.updateQuery($0) },
            onKey: { [weak model] key in
                guard let model else { return false }
                switch key {
                case .moveUp:
                    model.moveSelection(by: -1)
                case .moveDown:
                    model.moveSelection(by: 1)
                case .enter:
                    guard let selected = model.selectedExtension else { return true }
                    openDetail(selected)
                case .commandEnter:
                    guard let selected = model.selectedExtension else { return true }
                    Task { await model.install(selected) }
                default:
                    return false
                }
                return true
            }
        )
    }

    private static func detailView(
        extensionValue: RaycastStoreExtension,
        model: ExtensionStoreViewModel
    ) -> LauncherPresentedView {
        LauncherPresentedView(
            title: extensionValue.title,
            content: AnyView(ExtensionStoreDetailView(
                extensionValue: extensionValue,
                model: model
            )),
            showsSearchField: false,
            initialQuery: "",
            onKey: { [weak model] key in
                guard let model else { return false }
                guard key == .enter || key == .commandEnter else { return false }
                Task {
                    switch model.state(for: extensionValue) {
                    case .installed:
                        await model.uninstall(extensionValue)
                    case .notInstalled:
                        await model.install(extensionValue)
                    case .installing:
                        break
                    }
                }
                return true
            }
        )
    }
}

private struct ExtensionStoreLauncherView: View {
    @ObservedObject var model: ExtensionStoreViewModel
    let openDetail: (RaycastStoreExtension) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            switch model.loadState {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                VStack(spacing: LauncherTheme.Metrics.footerGroupSpacing) {
                    Text(message)
                        .font(LauncherTheme.Typography.emptyState)
                        .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
                    Button("Retry") { Task { await model.retry() } }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded:
                results
            }
        }
        .task { await model.load() }
    }

    private var results: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Text("EXTENSIONS")
                        .font(LauncherTheme.Typography.section)
                        .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
                        .padding(.leading, LauncherTheme.Metrics.sectionLeadingPadding)
                        .padding(.top, LauncherTheme.Metrics.sectionTopPadding)
                        .padding(.bottom, LauncherTheme.Metrics.sectionBottomPadding)

                    if let operationError = model.operationError {
                        HStack {
                            Text(operationError)
                                .font(LauncherTheme.Typography.emptyState)
                                .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
                            Spacer()
                            Button("Retry") { Task { await model.retryLastOperation() } }
                                .buttonStyle(.plain)
                                .foregroundStyle(LauncherTheme.Palette.accent)
                        }
                        .padding(.horizontal, LauncherTheme.Metrics.sectionLeadingPadding)
                        .padding(.bottom, LauncherTheme.Metrics.sectionBottomPadding)
                    }

                    if model.extensions.isEmpty {
                        Text("No matching extensions")
                            .font(LauncherTheme.Typography.emptyState)
                            .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
                            .frame(maxWidth: .infinity)
                            .padding(.top, LauncherTheme.Metrics.footerHeight)
                    } else {
                        ForEach(Array(model.extensions.enumerated()), id: \.element.name) { index, value in
                            ExtensionStoreRow(
                                extensionValue: value,
                                state: model.state(for: value),
                                isSelected: index == model.selectedIndex
                            )
                            .padding(.horizontal, LauncherTheme.Metrics.rowOuterInset)
                            .id(value.name)
                            .contentShape(Rectangle())
                            .onTapGesture { model.select(index) }
                            .onTapGesture(count: 2) {
                                model.select(index)
                                openDetail(value)
                            }
                            .onHover { hovering in
                                if hovering { model.select(index) }
                            }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .onChange(of: model.selectedIndex) {
                guard let selected = model.selectedExtension else { return }
                proxy.scrollTo(selected.name)
            }
        }
    }
}

private struct ExtensionStoreRow: View {
    let extensionValue: RaycastStoreExtension
    let state: ExtensionStoreInstallState
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: LauncherTheme.Metrics.rowIconTitleSpacing) {
            RemoteIconView(url: extensionValue.iconURL) {
                Image(systemName: "puzzlepiece.extension")
                    .resizable()
                    .scaledToFit()
                    .padding(LauncherTheme.Metrics.symbolIconPadding)
            }
            .frame(
                width: LauncherTheme.Metrics.rowIconSize,
                height: LauncherTheme.Metrics.rowIconSize
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: LauncherTheme.Metrics.rowSubtitleSpacing) {
                    Text(extensionValue.title)
                        .font(LauncherTheme.Typography.rowTitle)
                        .foregroundStyle(LauncherTheme.Palette.primaryText(for: colorScheme))
                        .lineLimit(1)
                    Text(extensionValue.author)
                        .font(LauncherTheme.Typography.rowKind)
                        .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
                        .lineLimit(1)
                }
                Text(extensionValue.description)
                    .font(LauncherTheme.Typography.rowSubtitle)
                    .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
                    .lineLimit(1)
            }

            Spacer(minLength: LauncherTheme.Metrics.rowTrailingSpacing)
            installState
        }
        .padding(.horizontal, LauncherTheme.Metrics.rowContentPadding)
        .frame(
            maxWidth: .infinity,
            minHeight: LauncherTheme.Metrics.rowHeight * 1.35
        )
        .background {
            RoundedRectangle(
                cornerRadius: LauncherTheme.Metrics.rowCornerRadius,
                style: .continuous
            )
            .fill(isSelected ? LauncherTheme.Palette.selectedRow(for: colorScheme) : .clear)
            .overlay {
                RoundedRectangle(
                    cornerRadius: LauncherTheme.Metrics.rowCornerRadius,
                    style: .continuous
                )
                .strokeBorder(
                    isSelected ? LauncherTheme.Palette.borderPrimary(for: colorScheme) : .clear,
                    lineWidth: LauncherTheme.Metrics.borderWidth
                )
            }
        }
    }

    @ViewBuilder
    private var installState: some View {
        switch state {
        case .notInstalled:
            Text("Install")
                .font(LauncherTheme.Typography.rowKind)
                .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
        case .installing(let progress):
            VStack(alignment: .trailing, spacing: 3) {
                Text("Installing")
                    .font(LauncherTheme.Typography.rowKind)
                    .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
                ProgressView(value: progress)
                    .frame(width: LauncherTheme.Metrics.footerHeight)
            }
        case .installed:
            Text("Installed")
                .font(LauncherTheme.Typography.rowKind)
                .foregroundStyle(LauncherTheme.Palette.accent)
        }
    }
}
