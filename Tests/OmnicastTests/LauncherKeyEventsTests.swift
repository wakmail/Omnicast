// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastUI
import XCTest

@MainActor
final class LauncherKeyEventsTests: XCTestCase {
    func testRootListReceivesKeysThroughPublishedRoute() {
        let events = LauncherKeyEvents()

        XCTAssertTrue(events.route(.enter))
        XCTAssertEqual(events.activeSurface, .rootList)
        XCTAssertEqual(events.latest?.key, .enter)
    }

    func testPushedViewClaimsHandledKeysAndLeavesOtherKeysForAppKit() {
        let events = LauncherKeyEvents()
        var received: [LauncherKey] = []
        events.activatePushedView { key in
            received.append(key)
            return key == .enter
        }

        XCTAssertTrue(events.route(.enter))
        XCTAssertFalse(events.route(.moveDown))
        XCTAssertEqual(events.activeSurface, .pushedView)
        XCTAssertEqual(received, [.enter, .moveDown])
        XCTAssertNil(events.latest)
    }

    func testReturningToRootRemovesPushedViewHandler() {
        let events = LauncherKeyEvents()
        var pushedCallCount = 0
        events.activatePushedView { _ in
            pushedCallCount += 1
            return true
        }
        events.activateRootList()

        XCTAssertTrue(events.route(.escape))
        XCTAssertEqual(events.activeSurface, .rootList)
        XCTAssertEqual(events.latest?.key, .escape)
        XCTAssertEqual(pushedCallCount, 0)
    }
}
