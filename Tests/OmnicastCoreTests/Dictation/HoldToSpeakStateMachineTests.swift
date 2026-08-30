// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import XCTest

final class HoldToSpeakStateMachineTests: XCTestCase {
    func testPressReleaseAndCompletionTransitions() {
        var machine = HoldToSpeakStateMachine()

        XCTAssertEqual(machine.handle(.pressed), .startEngine)
        XCTAssertEqual(machine.phase, .starting)
        XCTAssertNil(machine.handle(.engineStarted))
        XCTAssertEqual(machine.phase, .listening)
        XCTAssertEqual(machine.handle(.released), .stopEngineAndPaste)
        XCTAssertEqual(machine.phase, .transcribing)
        XCTAssertNil(machine.handle(.completed))
        XCTAssertEqual(machine.phase, .idle)
    }

    func testReleaseWhileStartingStillStopsEngine() {
        var machine = HoldToSpeakStateMachine()

        XCTAssertEqual(machine.handle(.pressed), .startEngine)
        XCTAssertEqual(machine.handle(.released), .stopEngineAndPaste)
        XCTAssertEqual(machine.phase, .transcribing)
    }

    func testDuplicateEventsDoNotProduceActions() {
        var machine = HoldToSpeakStateMachine()

        XCTAssertNil(machine.handle(.released))
        XCTAssertEqual(machine.handle(.pressed), .startEngine)
        XCTAssertNil(machine.handle(.pressed))
        XCTAssertNil(machine.handle(.completed))
        XCTAssertEqual(machine.phase, .starting)
        XCTAssertNil(machine.handle(.failed))
        XCTAssertEqual(machine.phase, .idle)
    }
}
