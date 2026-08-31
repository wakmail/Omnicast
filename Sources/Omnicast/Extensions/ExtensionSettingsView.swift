// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastExtensions
import OmnicastUI
import SwiftUI

@MainActor
final class ExtensionSettingsViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var searchResults: [RaycastStoreExtension] = []
    @Published private(set) var installed: [InstalledExtension] = []
    @Published private(set) var isWorking = false
    @Published private(set) var errorMessage: String?

    private let registry: ExtensionRegistry
    private let catalog: RaycastStoreCatalog
    private let onRegistryChanged: () -> Void

    init(
        registry: ExtensionRegistry,
        catalog: RaycastStoreCatalog,
        onRegistryChanged: @escaping () -> Void
    ) {
        self.registry = registry
        self.catalog = catalog
        self.onRegistryChanged = onRegistryChanged
    }

    var installedSlugs: Set<String> {
        Set(installed.map(\.slug))
    }

    func load() async {
        do {
            async let catalogValues = catalog.extensions()
            async let installedValues = registry.listInstalled()
            searchResults = try await catalogValues
            installed = try await installedValues
            errorMessage = nil
        } catch {
            errorMessage = "The extension store is unavailable. Try again."
        }
    }

    func search() async {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        isWorking = true
        defer { isWorking = false }
        do {
            searchResults = try await catalog.search(query: value)
            errorMessage = nil
        } catch {
            errorMessage = "The extension store is unavailable. Try again."
        }
    }

    func install(_ extensionValue: RaycastStoreExtension) async {
        await mutate {
            _ = try await registry.install(storeSlug: extensionValue.name)
        }
    }

    func uninstall(_ extensionValue: InstalledExtension) async {
        await mutate {
            try await registry.uninstall(slug: extensionValue.slug)
        }
    }

    private func mutate(_ operation: () async throws -> Void) async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await operation()
            installed = try await registry.listInstalled()
            errorMessage = nil
            onRegistryChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ExtensionSettingsView: View {
    @StateObject private var model: ExtensionSettingsViewModel
    @Environment(\.colorScheme) private var colorScheme

    @MainActor
    init(
        registry: ExtensionRegistry,
        catalog: RaycastStoreCatalog,
        onRegistryChanged: @escaping () -> Void
    ) {
        _model = StateObject(wrappedValue: ExtensionSettingsViewModel(
            registry: registry,
            catalog: catalog,
            onRegistryChanged: onRegistryChanged
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: LauncherTheme.Metrics.footerIconTitleSpacing) {
                TextField("Search extension catalog", text: $model.query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await model.search() } }
                Button("Search") { Task { await model.search() } }
                    .buttonStyle(.borderedProminent)
            }
            .padding(LauncherTheme.Metrics.searchHorizontalPadding)

            Divider()

            HSplitView {
                extensionList
                installedList
            }

            if let errorMessage = model.errorMessage {
                HStack {
                    Text(errorMessage)
                        .font(LauncherTheme.Typography.footerTitle)
                        .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
                    Spacer()
                    Button("Retry") { Task { await model.search() } }
                }
                .padding(LauncherTheme.Metrics.footerHorizontalPadding)
            }
        }
        .overlay {
            if model.isWorking {
                ProgressView()
                    .padding(LauncherTheme.Metrics.actionPanelPadding)
                    .background(
                        LauncherTheme.Palette.toastSurface(for: colorScheme),
                        in: RoundedRectangle(cornerRadius: LauncherTheme.Metrics.rowCornerRadius)
                    )
            }
        }
        .task { await model.load() }
    }

    private var extensionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("CATALOG")
            List(model.searchResults, id: \.name) { extensionValue in
                HStack(spacing: LauncherTheme.Metrics.rowIconTitleSpacing) {
                    AsyncImage(url: extensionValue.iconURL) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Image(systemName: "puzzlepiece.extension")
                    }
                    .frame(
                        width: LauncherTheme.Metrics.rowIconSize,
                        height: LauncherTheme.Metrics.rowIconSize
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(extensionValue.title)
                            .font(LauncherTheme.Typography.rowTitle)
                        Text(extensionValue.description)
                            .font(LauncherTheme.Typography.rowSubtitle)
                            .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
                            .lineLimit(2)
                    }
                    Spacer()
                    if model.installedSlugs.contains(extensionValue.name) {
                        Text("Installed")
                            .font(LauncherTheme.Typography.footerTitle)
                            .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
                    } else {
                        Button("Install") {
                            Task { await model.install(extensionValue) }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .frame(minWidth: 380)
    }

    private var installedList: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("INSTALLED")
            List(model.installed, id: \.slug) { extensionValue in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(extensionValue.manifest.title)
                            .font(LauncherTheme.Typography.rowTitle)
                        Text("\(extensionValue.manifest.commands.count) commands")
                            .font(LauncherTheme.Typography.rowSubtitle)
                            .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
                    }
                    Spacer()
                    if extensionValue.isBuiltin {
                        Text("Built In")
                            .font(LauncherTheme.Typography.footerTitle)
                            .foregroundStyle(
                                LauncherTheme.Palette.secondaryText(for: colorScheme)
                            )
                    } else {
                        Button("Uninstall", role: .destructive) {
                            Task { await model.uninstall(extensionValue) }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 300)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(LauncherTheme.Typography.section)
            .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
            .padding(.leading, LauncherTheme.Metrics.sectionLeadingPadding)
            .padding(.vertical, LauncherTheme.Metrics.sectionTopPadding)
    }
}
