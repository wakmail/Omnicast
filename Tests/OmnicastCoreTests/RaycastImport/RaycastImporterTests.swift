// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OmnicastCore
import XCTest

@MainActor
final class RaycastImporterTests: XCTestCase {
    func testMapsEverySupportedCategoryIntoIsolatedStores() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let quicklinks = try QuicklinkStore(directoryURL: directory)
        let snippets = try SnippetStore(directoryURL: directory)
        let notes = try NotesStore(directoryURL: directory)
        let settings = try SettingsStore(directoryURL: directory)
        let supplemental = try RaycastImportStore(directoryURL: directory)
        let importer = try RaycastImporter(
            quicklinkStore: quicklinks,
            snippetStore: snippets,
            notesStore: notes,
            settingsStore: settings,
            importStore: supplemental
        )
        let backup = makeBackup()

        let result = try importer.run(backup: backup)

        XCTAssertEqual(quicklinks.quicklinks.map(\.urlTemplate), ["https://example.com?q={query}"])
        XCTAssertEqual(snippets.snippets.map(\.name), ["Greeting"])
        XCTAssertEqual(notes.notes.first?.title, "Project")
        XCTAssertEqual(notes.notes.first?.pinned, true)
        XCTAssertEqual(settings.settings.hotkey, .optionSpace)
        XCTAssertEqual(settings.settings.windowMode, .compact)
        XCTAssertEqual(settings.settings.navigationStyle, .macOS)
        XCTAssertEqual(settings.settings.popToRootTimeout, 30)
        XCTAssertEqual(supplemental.data.scriptDirectories, ["/tmp/Raycast Scripts"])
        XCTAssertEqual(supplemental.data.commandHotkeys["system-emoji-picker"]?.displayName, "Command Space")
        XCTAssertEqual(Set(supplemental.data.disabledCommandKeys), Set(["raycastScript_/tmp/old.sh", "ext-github-stars"]))
        XCTAssertEqual(
            try supplemental.extensionPreferences(extensionSlug: "github"),
            ["token": .string("secret")]
        )
        XCTAssertEqual(result.extensionsToInstall, ["github"])
        XCTAssertEqual(result.categories[.quicklinks]?.imported, 1)
        XCTAssertEqual(result.categories[.snippets]?.imported, 1)
        XCTAssertEqual(result.categories[.notes]?.imported, 1)
        XCTAssertEqual(result.categories[.extensionPreferences]?.imported, 1)
        XCTAssertEqual(result.categories[.settings]?.imported, 5)
        XCTAssertEqual(result.categories[.settings]?.skipped, 0)
        XCTAssertFalse(result.skippedItems.contains {
            ["Window mode", "Navigation style", "Return timeout"].contains($0.item)
        })
    }

    func testUnselectedCategoryDoesNotMutateItsStore() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let quicklinks = try QuicklinkStore(directoryURL: directory)
        let snippets = try SnippetStore(directoryURL: directory)
        let notes = try NotesStore(directoryURL: directory)
        let settings = try SettingsStore(directoryURL: directory)
        let importer = try RaycastImporter(
            quicklinkStore: quicklinks,
            snippetStore: snippets,
            notesStore: notes,
            settingsStore: settings
        )
        var categories = Set(RaycastImportCategory.allCases)
        categories.remove(.notes)

        let result = try importer.run(
            backup: makeBackup(),
            selections: RaycastImportSelections(selectedCategories: categories)
        )

        XCTAssertTrue(notes.notes.isEmpty)
        XCTAssertEqual(result.categories[.notes]?.selected, false)
        XCTAssertEqual(result.categories[.notes]?.skipped, 1)
        XCTAssertTrue(result.skippedItems.contains { $0.category == .notes })
    }

    private func makeBackup() -> RaycastBackup {
        RaycastBackup(
            raycastVersion: "1.99.0",
            quicklinksPackage: RaycastQuicklinksPackage(
                quicklinks: [RaycastQuicklinkRecord(name: "Search", url: "https://example.com?q={argument}")]
            ),
            snippetsPackage: RaycastSnippetsPackage(
                snippets: [RaycastSnippetRecord(name: "Greeting", text: "Hello", keyword: "hello")]
            ),
            notesPackage: RaycastNotesPackage(
                notes: [RaycastNoteRecord(title: "Project", text: "Details", pinned: true)]
            ),
            extensionsPackage: RaycastExtensionsPackage(
                extensions: [
                    RaycastExtensionRecord(
                        name: "github",
                        commands: [RaycastExtensionCommandRecord(name: "stars", enabled: false)],
                        prefs: [RaycastPreferenceRecord(name: "token", type: "password", value: .string("secret"))]
                    )
                ]
            ),
            preferencesPackage: RaycastPreferencesPackage(
                preferencesGeneral: RaycastGeneralPreferences(raycastGlobalHotkey: "Option-49"),
                preferencesAppearance: RaycastAppearancePreferences(raycastPreferredWindowMode: "compact"),
                preferencesAdvanced: RaycastAdvancedPreferences(
                    navigationCommandStyleIdentifierKey: "macos",
                    popToRootTimeout: 30
                )
            ),
            rootSearchPackage: RaycastRootSearchPackage(
                rootSearch: [RaycastRootSearchRecord(key: "builtin_command_searchEmoji", hotkey: "Command-49")]
            ),
            scriptCommandsPackage: RaycastScriptCommandsPackage(
                scriptCommandsDirectories: ["/tmp/Raycast Scripts"],
                disabledCommands: ["raycastScript_/tmp/old.sh"]
            )
        )
    }
}
