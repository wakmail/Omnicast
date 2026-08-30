// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import XCTest

final class DictationHUDStateTests: XCTestCase {
    func testListeningLevelIsClamped() {
        XCTAssertEqual(
            DictationHUDState.listening(normalizing: 1.8),
            .listening(level: 1)
        )
        XCTAssertEqual(
            DictationHUDState.listening(normalizing: -0.4),
            .listening(level: 0)
        )
    }
}
