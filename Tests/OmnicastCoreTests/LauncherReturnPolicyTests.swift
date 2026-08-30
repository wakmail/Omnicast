// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OmnicastCore
import XCTest

final class LauncherReturnPolicyTests: XCTestCase {
    private let hiddenAt = Date(timeIntervalSinceReferenceDate: 1_000)

    func testZeroTimeoutNeverReturnsToRoot() {
        XCTAssertFalse(shouldPopLauncherToRoot(
            hiddenAt: hiddenAt,
            shownAt: hiddenAt.addingTimeInterval(10_000),
            timeout: 0
        ))
    }

    func testOnlyElapsedTimeLongerThanTimeoutReturnsToRoot() {
        XCTAssertFalse(shouldPopLauncherToRoot(
            hiddenAt: hiddenAt,
            shownAt: hiddenAt.addingTimeInterval(5),
            timeout: 5
        ))
        XCTAssertTrue(shouldPopLauncherToRoot(
            hiddenAt: hiddenAt,
            shownAt: hiddenAt.addingTimeInterval(5.001),
            timeout: 5
        ))
    }

    func testMissingHideTimeKeepsCurrentSurface() {
        XCTAssertFalse(shouldPopLauncherToRoot(
            hiddenAt: nil,
            shownAt: hiddenAt,
            timeout: 5
        ))
    }
}
