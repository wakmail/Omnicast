// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import XCTest

final class ClipboardCommandsProviderTests: XCTestCase {
    func testProviderReturnsClipboardHistoryCommand() async {
        let commands = await ClipboardCommandsProvider().commands()

        XCTAssertEqual(commands.count, 1)
        XCTAssertEqual(commands.first?.id, "clipboard:history")
        XCTAssertEqual(commands.first?.title, "Clipboard History")
        XCTAssertEqual(commands.first?.kind, .clipboard)
    }
}
