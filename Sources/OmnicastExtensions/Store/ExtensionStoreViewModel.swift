// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation

public enum ExtensionStoreLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}

public enum ExtensionStoreInstallState: Equatable {
    case notInstalled
    case installing(progress: Double)
    case installed
}

@MainActor
public final class ExtensionStoreViewModel: ObservableObject {
    @Published public private(set) var extensions: [RaycastStoreExtension] = []
    @Published public private(set) var installed: [InstalledExtension] = []
    @Published public private(set) var loadState: ExtensionStoreLoadState = .idle
    @Published public private(set) var operationError: String?
    @Published public var selectedIndex = 0

    public let catalog: RaycastStoreCatalog
    private let registry: ExtensionRegistry
    private let onRegistryChanged: @MainActor () -> Void
    private var query = ""
    private var allExtensions: [RaycastStoreExtension] = []
    @Published private var installProgress: [String: Double] = [:]
    private var failedOperation: FailedOperation?

    public init(
        catalog: RaycastStoreCatalog,
        registry: ExtensionRegistry,
        onRegistryChanged: @escaping @MainActor () -> Void = {}
    ) {
        self.catalog = catalog
        self.registry = registry
        self.onRegistryChanged = onRegistryChanged
    }

    public var selectedExtension: RaycastStoreExtension? {
        guard extensions.indices.contains(selectedIndex) else { return nil }
        return extensions[selectedIndex]
    }

    public func state(for extensionValue: RaycastStoreExtension) -> ExtensionStoreInstallState {
        if let progress = installProgress[extensionValue.name] {
            return .installing(progress: progress)
        }
        return installed.contains { $0.slug == extensionValue.name }
            ? .installed
            : .notInstalled
    }

    public func load() async {
        guard loadState != .loading else { return }
        loadState = .loading
        do {
            async let catalogValues = catalog.extensions()
            async let installedValues = registry.listInstalled()
            allExtensions = try await catalogValues
            installed = try await installedValues
            applyQuery()
            loadState = .loaded
            operationError = nil
        } catch {
            loadState = .failed("The extension store is unavailable. Try again.")
        }
    }

    public func retry() async {
        await load()
    }

    public func updateQuery(_ value: String) {
        query = value
        applyQuery()
    }

    public func moveSelection(by offset: Int) {
        guard !extensions.isEmpty else {
            selectedIndex = 0
            return
        }
        selectedIndex = min(max(0, selectedIndex + offset), extensions.count - 1)
    }

    public func select(_ index: Int) {
        guard extensions.indices.contains(index) else { return }
        selectedIndex = index
    }

    public func install(_ extensionValue: RaycastStoreExtension) async {
        guard state(for: extensionValue) == .notInstalled else { return }
        installProgress[extensionValue.name] = 0.15
        operationError = nil
        failedOperation = nil
        do {
            _ = try await registry.install(storeSlug: extensionValue.name)
            installProgress[extensionValue.name] = 0.9
            installed = try await registry.listInstalled()
            installProgress[extensionValue.name] = nil
            onRegistryChanged()
        } catch {
            installProgress[extensionValue.name] = nil
            operationError = "This extension could not be installed. Try again."
            failedOperation = .install(extensionValue)
        }
    }

    public func uninstall(_ extensionValue: RaycastStoreExtension) async {
        guard state(for: extensionValue) == .installed else { return }
        installProgress[extensionValue.name] = 0.15
        operationError = nil
        failedOperation = nil
        do {
            try await registry.uninstall(slug: extensionValue.name)
            installed = try await registry.listInstalled()
            installProgress[extensionValue.name] = nil
            onRegistryChanged()
        } catch {
            installProgress[extensionValue.name] = nil
            operationError = "This extension could not be uninstalled. Try again."
            failedOperation = .uninstall(extensionValue)
        }
    }

    public func retryLastOperation() async {
        guard let failedOperation else { return }
        switch failedOperation {
        case .install(let extensionValue):
            await install(extensionValue)
        case .uninstall(let extensionValue):
            await uninstall(extensionValue)
        }
    }

    private func applyQuery() {
        let terms = query
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .split(whereSeparator: \Character.isWhitespace)
            .map(String.init)
        extensions = allExtensions.filter { extensionValue in
            guard !terms.isEmpty else { return true }
            let searchable = [
                extensionValue.name,
                extensionValue.title,
                extensionValue.author,
                extensionValue.description,
                extensionValue.commands.map(\.title).joined(separator: " ")
            ]
                .joined(separator: " ")
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            return terms.allSatisfy(searchable.contains)
        }
        selectedIndex = min(selectedIndex, max(0, extensions.count - 1))
    }
}

private enum FailedOperation {
    case install(RaycastStoreExtension)
    case uninstall(RaycastStoreExtension)
}
