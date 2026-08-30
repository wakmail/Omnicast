// SPDX-License-Identifier: GPL-3.0-or-later

@testable import Omnicast
import XCTest

final class LauncherPanelSnapTests: XCTestCase {
    private let panelSize = CGSize(width: 680, height: 480)
    private let mainScreen = CGRect(x: 0, y: 0, width: 1_440, height: 900)

    func testDefaultFrameIsCenteredNearScreenTop() {
        XCTAssertEqual(
            launcherPanelDefaultFrame(
                panelSize: panelSize,
                screenVisibleFrame: mainScreen
            ),
            CGRect(x: 380, y: 330, width: 680, height: 480)
        )
    }

    func testSnapUsesFrameCentersAndIncludesThresholdBoundary() {
        let target = launcherPanelDefaultFrame(
            panelSize: panelSize,
            screenVisibleFrame: mainScreen
        )
        let dropped = target.offsetBy(dx: 28.8, dy: 38.4)

        XCTAssertEqual(
            launcherPanelSnapTarget(
                droppedFrame: dropped,
                screenVisibleFrames: [mainScreen]
            ),
            target
        )
    }

    func testDropBeyondThresholdDoesNotSnap() {
        let target = launcherPanelDefaultFrame(
            panelSize: panelSize,
            screenVisibleFrame: mainScreen
        )

        XCTAssertNil(
            launcherPanelSnapTarget(
                droppedFrame: target.offsetBy(dx: 48.01, dy: 0),
                screenVisibleFrames: [mainScreen]
            )
        )
    }

    func testNearestDisplayDefaultHandlesNegativeScreenCoordinates() {
        let leftScreen = CGRect(x: -1_920, y: -120, width: 1_920, height: 1_080)
        let target = launcherPanelDefaultFrame(
            panelSize: panelSize,
            screenVisibleFrame: leftScreen
        )
        let dropped = target.offsetBy(dx: -20, dy: 12)

        XCTAssertEqual(
            launcherPanelSnapTarget(
                droppedFrame: dropped,
                screenVisibleFrames: [mainScreen, leftScreen]
            ),
            target
        )
    }

    func testNearestDisplayDefaultHandlesScreenAboveMainDisplay() {
        let upperScreen = CGRect(x: 240, y: 900, width: 1_280, height: 800)
        let target = launcherPanelDefaultFrame(
            panelSize: panelSize,
            screenVisibleFrame: upperScreen
        )

        XCTAssertEqual(
            launcherPanelSnapTarget(
                droppedFrame: target.offsetBy(dx: 0, dy: -47),
                screenVisibleFrames: [mainScreen, upperScreen]
            ),
            target
        )
    }

    func testNoScreensCannotProduceSnapTarget() {
        XCTAssertNil(
            launcherPanelSnapTarget(
                droppedFrame: CGRect(origin: .zero, size: panelSize),
                screenVisibleFrames: []
            )
        )
    }
}
