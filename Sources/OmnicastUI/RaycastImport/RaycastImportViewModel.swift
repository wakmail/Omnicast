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

    public init(reader: RayconfigReader = RayconfigReader(), importer: RaycastImporter) {
        self.reader = reader
        self.importer = importer
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
        guard panel.runModal() == .OK else { return }
        fileURL = panel.url
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
