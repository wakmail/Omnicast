// SPDX-License-Identifier: GPL-3.0-or-later

@testable import Omnicast
import OmnicastCore
import OmnicastExtensions
import XCTest

final class ExtensionStoreCommandTests: XCTestCase {
    func testCommandUsesExtensionKindAndStoreKeyword() {
        let command = ExtensionStoreCommand()

        XCTAssertEqual(command.title, "Extension Store")
        XCTAssertEqual(command.kind, .extensionCommand)
        XCTAssertEqual(command.keywords, ["store"])
    }

    func testBuiltinStoreIsTheDefaultExtensionStoreCommand() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "ExtensionStoreCommandTests.\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let provider = ExtensionCommandsProvider(
            registry: ExtensionRegistry(directoryURL: directory),
            open: { _, _ in }
        )

        let commands = await provider.commands()
        let store = try XCTUnwrap(commands.first(where: { $0.id == "extension:store" }))

        XCTAssertEqual(store.title, "Extension Store")
        XCTAssertEqual(store.kind, .extensionCommand)
    }
}
