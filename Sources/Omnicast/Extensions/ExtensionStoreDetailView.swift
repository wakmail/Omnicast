// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastExtensions
import OmnicastUI
import SwiftUI

struct ExtensionStoreDetailView: View {
    let extensionValue: RaycastStoreExtension
    @ObservedObject var model: ExtensionStoreViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var screenshotURLs: [URL] = []
    @State private var loadingScreenshots = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LauncherTheme.Metrics.footerGroupSpacing) {
                header

                Text(extensionValue.description)
                    .font(LauncherTheme.Typography.rowSubtitle)
                    .foregroundStyle(LauncherTheme.Palette.primaryText(for: colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)

                screenshots
                commands

                if let error = model.operationError {
                    HStack {
                        Text(error)
                            .font(LauncherTheme.Typography.emptyState)
                            .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
                        Button("Retry") { Task { await model.retryLastOperation() } }
                            .buttonStyle(.plain)
                            .foregroundStyle(LauncherTheme.Palette.accent)
                    }
                }
            }
            .padding(LauncherTheme.Metrics.searchHorizontalPadding)
        }
        .scrollIndicators(.hidden)
        .task(id: extensionValue.name) { await loadScreenshots() }
    }

    private var header: some View {
        HStack(spacing: LauncherTheme.Metrics.rowIconTitleSpacing) {
            AsyncImage(url: extensionValue.iconURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Image(systemName: "puzzlepiece.extension")
                    .resizable()
                    .scaledToFit()
                    .padding(LauncherTheme.Metrics.symbolIconPadding)
            }
            .frame(
                width: LauncherTheme.Metrics.footerHeight,
                height: LauncherTheme.Metrics.footerHeight
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(extensionValue.title)
                    .font(LauncherTheme.Typography.search)
                    .foregroundStyle(LauncherTheme.Palette.primaryText(for: colorScheme))
                Text("By \(extensionValue.author)")
                    .font(LauncherTheme.Typography.rowSubtitle)
                    .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
            }

            Spacer()
            actionButton
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch model.state(for: extensionValue) {
        case .notInstalled:
            Button("Install") { Task { await model.install(extensionValue) } }
                .buttonStyle(.borderedProminent)
        case .installing(let progress):
            ProgressView(value: progress)
                .frame(width: LauncherTheme.Metrics.footerHeight * 2)
        case .installed:
            Button("Uninstall") { Task { await model.uninstall(extensionValue) } }
                .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var screenshots: some View {
        if loadingScreenshots {
            ProgressView()
                .frame(maxWidth: .infinity)
        } else if !screenshotURLs.isEmpty {
            VStack(alignment: .leading, spacing: LauncherTheme.Metrics.sectionBottomPadding) {
                sectionTitle("SCREENSHOTS")
                ScrollView(.horizontal) {
                    LazyHStack(spacing: LauncherTheme.Metrics.rowIconTitleSpacing) {
                        ForEach(screenshotURLs, id: \.absoluteString) { url in
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(
                                width: LauncherTheme.Metrics.panelWidth * 0.42,
                                height: LauncherTheme.Metrics.panelHeight * 0.34
                            )
                            .background(
                                LauncherTheme.Palette.selectedRow(for: colorScheme),
                                in: RoundedRectangle(cornerRadius: LauncherTheme.Metrics.rowCornerRadius)
                            )
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var commands: some View {
        VStack(alignment: .leading, spacing: LauncherTheme.Metrics.sectionBottomPadding) {
            sectionTitle("COMMANDS")
            ForEach(extensionValue.commands, id: \.name) { command in
                VStack(alignment: .leading, spacing: 2) {
                    Text(command.title)
                        .font(LauncherTheme.Typography.rowTitle)
                        .foregroundStyle(LauncherTheme.Palette.primaryText(for: colorScheme))
                    if !command.description.isEmpty {
                        Text(command.description)
                            .font(LauncherTheme.Typography.rowSubtitle)
                            .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, LauncherTheme.Metrics.sectionBottomPadding)
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(LauncherTheme.Typography.section)
            .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
    }

    private func loadScreenshots() async {
        loadingScreenshots = true
        defer { loadingScreenshots = false }
        screenshotURLs = (try? await model.catalog.screenshots(for: extensionValue)) ?? []
    }
}
