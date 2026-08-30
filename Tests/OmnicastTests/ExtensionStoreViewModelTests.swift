// SPDX-License-Identifier: GPL-3.0-or-later

@testable import Omnicast
import OmnicastCore
import XCTest

final class ExtensionStoreCommandTests: XCTestCase {
    func testCommandUsesExtensionKindAndStoreKeyword() {
        let command = ExtensionStoreCommand()

        XCTAssertEqual(command.title, "Extension Store")
        XCTAssertEqual(command.kind, .extensionCommand)
        XCTAssertEqual(command.keywords, ["store"])
    }
}
