// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import OmnicastUI
import XCTest

@MainActor
final class RaycastImportViewModelTests: XCTestCase {
    func testExtensionInstallFailuresDoNotAbortTheBatch() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "RaycastImportViewModelTests.\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let importer = try makeImporter(directory: directory)
        var attempted: [String] = []
        let model = RaycastImportViewModel(importer: importer) { slug in
            attempted.append(slug)
            if slug == "missing" {
                throw TestInstallError.notFound
            }
        }

        await model.installExtensions(["first", "missing", "last"])

        XCTAssertEqual(attempted, ["first", "missing", "last"])
        XCTAssertEqual(model.extensionInstallStates["first"], .installed)
        XCTAssertEqual(
            model.extensionInstallStates["missing"],
            .failed(reason: "The extension was not found in the catalog.")
        )
        XCTAssertEqual(model.extensionInstallStates["last"], .installed)
    }

    private func makeImporter(directory: URL) throws -> RaycastImporter {
        try RaycastImporter(
            quicklinkStore: QuicklinkStore(directoryURL: directory),
            snippetStore: SnippetStore(directoryURL: directory),
            notesStore: NotesStore(directoryURL: directory),
            settingsStore: SettingsStore(directoryURL: directory),
            importStore: RaycastImportStore(directoryURL: directory)
        )
    }
}

private enum TestInstallError: LocalizedError {
    case notFound

    var errorDescription: String? {
        "The extension was not found in the catalog."
    }
}
