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

    func testSnapUsesFrameCentersAndIncludesTwelvePointThresholdBoundary() {
        let target = launcherPanelDefaultFrame(
            panelSize: panelSize,
            screenVisibleFrame: mainScreen
        )
        let dropped = target.offsetBy(dx: 0, dy: 12)

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
                droppedFrame: target.offsetBy(dx: 12.01, dy: 0),
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
        let dropped = target.offsetBy(dx: -8, dy: 6)

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
                droppedFrame: target.offsetBy(dx: 0, dy: -11),
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

    func testVerticalGuideMagnetizesPanelCenterIndependently() throws {
        let panelFrame = CGRect(x: 387.5, y: 120, width: 680, height: 480)
        let alignment = try XCTUnwrap(
            launcherPanelGuideAlignment(
                panelFrame: panelFrame,
                screenVisibleFrames: [mainScreen]
            )
        )

        XCTAssertEqual(alignment.verticalGuideX, 720)
        XCTAssertNil(alignment.horizontalGuideY)
        XCTAssertEqual(alignment.magnetizedFrame.origin.x, 385.625)
        XCTAssertEqual(alignment.magnetizedFrame.origin.y, panelFrame.origin.y)
    }

    func testHorizontalGuideMagnetizesPanelTopIndependently() throws {
        let panelFrame = CGRect(x: 80, y: 337.5, width: 680, height: 480)
        let alignment = try XCTUnwrap(
            launcherPanelGuideAlignment(
                panelFrame: panelFrame,
                screenVisibleFrames: [mainScreen]
            )
        )

        XCTAssertNil(alignment.verticalGuideX)
        XCTAssertEqual(alignment.horizontalGuideY, 810)
        XCTAssertEqual(alignment.magnetizedFrame.origin.x, panelFrame.origin.x)
        XCTAssertEqual(alignment.magnetizedFrame.origin.y, 335.625)
    }

    func testGuidesActivateAtEightPointBoundary() throws {
        let defaultFrame = launcherPanelDefaultFrame(
            panelSize: panelSize,
            screenVisibleFrame: mainScreen
        )
        let alignment = try XCTUnwrap(
            launcherPanelGuideAlignment(
                panelFrame: defaultFrame.offsetBy(dx: -8, dy: 8),
                screenVisibleFrames: [mainScreen]
            )
        )

        XCTAssertEqual(alignment.verticalGuideX, mainScreen.midX)
        XCTAssertEqual(alignment.horizontalGuideY, defaultFrame.maxY)
        XCTAssertEqual(
            alignment.magnetizedFrame,
            defaultFrame.offsetBy(dx: -6, dy: 6)
        )
    }

    func testGuidesDoNotActivateBeyondEightPoints() throws {
        let defaultFrame = launcherPanelDefaultFrame(
            panelSize: panelSize,
            screenVisibleFrame: mainScreen
        )
        let panelFrame = defaultFrame.offsetBy(dx: 8.01, dy: -8.01)
        let alignment = try XCTUnwrap(
            launcherPanelGuideAlignment(
                panelFrame: panelFrame,
                screenVisibleFrames: [mainScreen]
            )
        )

        XCTAssertFalse(alignment.hasActiveGuide)
        XCTAssertEqual(alignment.magnetizedFrame, panelFrame)
    }

    func testGuideCoordinatesRespectNegativeScreenOrigin() throws {
        let leftScreen = CGRect(x: -1_920, y: -120, width: 1_920, height: 1_080)
        let defaultFrame = launcherPanelDefaultFrame(
            panelSize: panelSize,
            screenVisibleFrame: leftScreen
        )
        let alignment = try XCTUnwrap(
            launcherPanelGuideAlignment(
                panelFrame: defaultFrame.offsetBy(dx: 6, dy: -7),
                screenVisibleFrames: [mainScreen, leftScreen]
            )
        )

        XCTAssertEqual(alignment.screenVisibleFrame, leftScreen)
        XCTAssertEqual(alignment.verticalGuideX, -960)
        XCTAssertEqual(alignment.horizontalGuideY, 870)
        XCTAssertEqual(
            alignment.magnetizedFrame,
            defaultFrame.offsetBy(dx: 4.5, dy: -5.25)
        )
    }

    func testGuideCoordinatesRespectScreenAboveMainDisplay() throws {
        let upperScreen = CGRect(x: 240, y: 900, width: 1_280, height: 800)
        let defaultFrame = launcherPanelDefaultFrame(
            panelSize: panelSize,
            screenVisibleFrame: upperScreen
        )
        let alignment = try XCTUnwrap(
            launcherPanelGuideAlignment(
                panelFrame: defaultFrame.offsetBy(dx: -4, dy: 3),
                screenVisibleFrames: [mainScreen, upperScreen]
            )
        )

        XCTAssertEqual(alignment.screenVisibleFrame, upperScreen)
        XCTAssertEqual(alignment.verticalGuideX, 880)
        XCTAssertEqual(alignment.horizontalGuideY, 1_610)
        XCTAssertEqual(
            alignment.magnetizedFrame,
            defaultFrame.offsetBy(dx: -3, dy: 2.25)
        )
    }

    func testGuideAlignmentRequiresScreenAndValidActivationDistance() {
        let panelFrame = CGRect(origin: .zero, size: panelSize)

        XCTAssertNil(
            launcherPanelGuideAlignment(
                panelFrame: panelFrame,
                screenVisibleFrames: []
            )
        )
        XCTAssertNil(
            launcherPanelGuideAlignment(
                panelFrame: panelFrame,
                screenVisibleFrames: [mainScreen],
                activationDistance: -1
            )
        )
    }
}
