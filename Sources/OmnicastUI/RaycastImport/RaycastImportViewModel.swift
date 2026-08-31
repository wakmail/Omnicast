// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Combine
import Foundation
import OmnicastCore
import UniformTypeIdentifiers

public enum RaycastExtensionInstallState: Equatable, Sendable {
    case installing
    case installed
    case failed(reason: String)
}

public typealias RaycastExtensionInstaller = @MainActor (String) async throws -> Void

@MainActor
public final class RaycastImportViewModel: ObservableObject {
    @Published public var fileURL: URL?
    @Published public var password = ""
    @Published public var selectedCategories = Set(RaycastImportCategory.allCases)
    @Published public private(set) var isImporting = false
    @Published public private(set) var result: RaycastImportResult?
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var importFailureMessage: String?
    @Published public private(set) var extensionInstallStates: [String: RaycastExtensionInstallState] = [:]

    private let reader: RayconfigReader
    private let importer: RaycastImporter
    private let extensionInstaller: RaycastExtensionInstaller?

    public init(
        reader: RayconfigReader = RayconfigReader(),
        importer: RaycastImporter,
        fileURL: URL? = nil,
        extensionInstaller: RaycastExtensionInstaller? = nil
    ) {
        self.reader = reader
        self.importer = importer
        self.fileURL = fileURL
        self.extensionInstaller = extensionInstaller
    }

    public var canRunImport: Bool {
        fileURL != nil && !selectedCategories.isEmpty && !isImporting
    }

    public func chooseFile() {
        let panel = NSOpenPanel()
        panel.title = "Choose Raycast Backup"
        panel.prompt = "Choose"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "rayconfig") ?? .data,
            .json
        ]
        panel.directoryURL = FileManager.default.urls(
            for: .downloadsDirectory,
            in: .userDomainMask
        ).first
        guard panel.runModal() == .OK else { return }
        guard let url = panel.url else { return }
        selectFile(url)
    }

    public func acceptDrop(_ providers: [NSItemProvider]) -> Bool {
        RayconfigDropReceiver.receive(providers) { [weak self] result in
            switch result {
            case .success(let url):
                self?.selectFile(url)
            case .failure(let error):
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    public func selectFile(_ url: URL) {
        do {
            fileURL = try RayconfigDropValidator.validate([url])
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        result = nil
        errorMessage = nil
        importFailureMessage = nil
        extensionInstallStates = [:]
    }

    public func setSelected(_ category: RaycastImportCategory, selected: Bool) {
        if selected {
            selectedCategories.insert(category)
        } else {
            selectedCategories.remove(category)
        }
    }

    public func runImport() {
        guard !isImporting else { return }
        guard let fileURL else {
            errorMessage = "Choose a Raycast backup first."
            return
        }
        guard !selectedCategories.isEmpty else {
            errorMessage = "Choose at least one category."
            return
        }
        let password = password
        let reader = reader
        let selections = RaycastImportSelections(selectedCategories: selectedCategories)
        isImporting = true
        result = nil
        errorMessage = nil
        importFailureMessage = nil
        extensionInstallStates = [:]
        Task {
            await Task.yield()
            do {
                let backup = try await Task.detached {
                    try reader.read(from: fileURL, password: password.isEmpty ? nil : password)
                }.value
                let importResult = try importer.run(backup: backup, selections: selections)
                result = importResult
                await installExtensions(importResult.extensionsToInstall)
            } catch {
                importFailureMessage = error.localizedDescription
            }
            isImporting = false
        }
    }

    public func prepareToRetry() {
        importFailureMessage = nil
        errorMessage = nil
    }

    public func installExtensions(_ slugs: [String]) async {
        for slug in slugs {
            extensionInstallStates[slug] = .installing
            guard let extensionInstaller else {
                extensionInstallStates[slug] = .failed(
                    reason: "Extension installation is unavailable."
                )
                continue
            }
            do {
                try await extensionInstaller(slug)
                extensionInstallStates[slug] = .installed
            } catch {
                extensionInstallStates[slug] = .failed(reason: error.localizedDescription)
            }
        }
    }
}

@MainActor
enum RayconfigDropReceiver {
    static let typeIdentifiers = [UTType.fileURL.identifier]

    static func receive(
        _ providers: [NSItemProvider],
        completion: @escaping (Result<URL, Error>) -> Void
    ) -> Bool {
        guard providers.count == 1, let provider = providers.first else {
            completion(.failure(RayconfigDropValidationError.invalidFileCount))
            return false
        }
        guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else {
            completion(.failure(RayconfigDropValidationError.unsupportedExtension))
            return false
        }
        provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, error in
            Task { @MainActor in
                if let error {
                    completion(.failure(error))
                    return
                }
                guard let data, let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    completion(.failure(RayconfigDropValidationError.unsupportedExtension))
                    return
                }
                do {
                    completion(.success(try RayconfigDropValidator.validate([url])))
                } catch {
                    completion(.failure(error))
                }
            }
        }
        return true
    }
}
