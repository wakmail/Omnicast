// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Combine
import Foundation
import OmnicastCore
import UniformTypeIdentifiers

@MainActor
public final class RaycastImportViewModel: ObservableObject {
    @Published public var fileURL: URL?
    @Published public var password = ""
    @Published public var selectedCategories = Set(RaycastImportCategory.allCases)
    @Published public private(set) var isImporting = false
    @Published public private(set) var result: RaycastImportResult?
    @Published public private(set) var errorMessage: String?

    private let reader: RayconfigReader
    private let importer: RaycastImporter

    public init(
        reader: RayconfigReader = RayconfigReader(),
        importer: RaycastImporter,
        fileURL: URL? = nil
    ) {
        self.reader = reader
        self.importer = importer
        self.fileURL = fileURL
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
    }

    public func setSelected(_ category: RaycastImportCategory, selected: Bool) {
        if selected {
            selectedCategories.insert(category)
        } else {
            selectedCategories.remove(category)
        }
    }

    public func runImport() {
        guard let fileURL else {
            errorMessage = "Choose a Raycast backup first."
            return
        }
        let password = password
        let reader = reader
        let selections = RaycastImportSelections(selectedCategories: selectedCategories)
        isImporting = true
        result = nil
        errorMessage = nil
        Task {
            do {
                let backup = try await Task.detached {
                    try reader.read(from: fileURL, password: password.isEmpty ? nil : password)
                }.value
                result = try importer.run(backup: backup, selections: selections)
            } catch {
                errorMessage = error.localizedDescription
            }
            isImporting = false
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
