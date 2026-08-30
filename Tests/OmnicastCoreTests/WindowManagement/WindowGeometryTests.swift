// SPDX-License-Identifier: GPL-3.0-or-later

import CoreGraphics
@testable import OmnicastCore
import XCTest

final class WindowGeometryTests: XCTestCase {
    private let area = CGRect(x: 100, y: 50, width: 1_200, height: 900)
    private let current = CGRect(x: 300, y: 200, width: 500, height: 400)

    func testHalves() {
        XCTAssertEqual(
            frame(for: .left, in: area, current: current),
            CGRect(x: 100, y: 50, width: 600, height: 900)
        )
        XCTAssertEqual(
            frame(for: .bottom, in: area, current: current),
            CGRect(x: 100, y: 500, width: 1_200, height: 450)
        )
    }

    func testThirds() {
        XCTAssertEqual(
            frame(for: .centerThird, in: area, current: current),
            CGRect(x: 500, y: 50, width: 400, height: 900)
        )
        XCTAssertEqual(
            frame(for: .lastTwoThirds, in: area, current: current),
            CGRect(x: 500, y: 50, width: 800, height: 900)
        )
    }

    func testQuarters() {
        XCTAssertEqual(
            frame(for: .topRight, in: area, current: current),
            CGRect(x: 700, y: 50, width: 600, height: 450)
        )
        XCTAssertEqual(
            frame(for: .thirdFourth, in: area, current: current),
            CGRect(x: 700, y: 50, width: 300, height: 900)
        )
        XCTAssertEqual(
            frame(for: .centerThreeFourths, in: area, current: current),
            CGRect(x: 250, y: 50, width: 900, height: 900)
        )
    }

    func testCenterPlacements() {
        XCTAssertEqual(
            frame(for: .center, in: area, current: current),
            CGRect(x: 340, y: 230, width: 720, height: 540)
        )
        XCTAssertEqual(
            frame(for: .center80, in: area, current: current),
            CGRect(x: 160, y: 95, width: 1_080, height: 810)
        )
    }

    func testNudgesStopAtEveryScreenEdge() {
        let topLeft = CGRect(x: 100, y: 50, width: 400, height: 300)
        XCTAssertEqual(frame(for: .moveLeft10, in: area, current: topLeft), topLeft)
        XCTAssertEqual(frame(for: .moveUp10, in: area, current: topLeft), topLeft)

        let bottomRight = CGRect(x: 900, y: 650, width: 400, height: 300)
        XCTAssertEqual(frame(for: .moveRight10, in: area, current: bottomRight), bottomRight)
        XCTAssertEqual(frame(for: .moveDown10, in: area, current: bottomRight), bottomRight)
    }

    func testResizeUsesTenPercentOfCurrentDimensions() {
        let base = CGRect(x: 300, y: 200, width: 500, height: 400)
        XCTAssertEqual(
            frame(for: .increaseRight10, in: area, current: base),
            CGRect(x: 300, y: 200, width: 550, height: 400)
        )
        XCTAssertEqual(
            frame(for: .decreaseTop10, in: area, current: base),
            CGRect(x: 300, y: 240, width: 500, height: 360)
        )
    }

    func testMinimumSizeFallbacks() {
        let smallArea = CGRect(x: 10, y: 20, width: 80, height: 40)
        XCTAssertEqual(
            frame(for: .left, in: smallArea, current: current),
            CGRect(x: 10, y: 20, width: 120, height: 60)
        )
    }
}
