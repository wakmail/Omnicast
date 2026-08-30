// SPDX-License-Identifier: GPL-3.0-or-later

@testable import OmnicastCore
import XCTest

final class PermissionEnableFlowTests: XCTestCase {
    func testSnippetFlowWaitsForBothPermissionsInOrder() {
        var flow = PermissionEnableFlow(feature: .snippets)

        flow.requestEnable(granted: [])
        XCTAssertEqual(flow.state, .waiting([.accessibility, .inputMonitoring]))
        XCTAssertEqual(flow.nextPermissionToRequest, .accessibility)

        flow.permissionsChanged(granted: [.accessibility])
        XCTAssertEqual(flow.state, .waiting([.inputMonitoring]))
        XCTAssertEqual(flow.nextPermissionToRequest, .inputMonitoring)

        flow.permissionsChanged(granted: [.accessibility, .inputMonitoring])
        XCTAssertEqual(flow.state, .enabled)
        XCTAssertNil(flow.nextPermissionToRequest)
    }

    func testHyperKeyFlowWaitsForInputMonitoringAndCanTurnOff() {
        var flow = PermissionEnableFlow(feature: .hyperKey)

        flow.requestEnable(granted: [])
        XCTAssertEqual(flow.state, .waiting([.inputMonitoring]))

        flow.permissionsChanged(granted: [.inputMonitoring])
        XCTAssertEqual(flow.state, .enabled)

        flow.disable()
        XCTAssertEqual(flow.state, .off)
    }

    func testFeatureWithExistingGrantsEnablesImmediately() {
        var snippets = PermissionEnableFlow(feature: .snippets)
        snippets.requestEnable(granted: [.accessibility, .inputMonitoring])
        XCTAssertEqual(snippets.state, .enabled)

        var hyperKey = PermissionEnableFlow(feature: .hyperKey)
        hyperKey.requestEnable(granted: [.inputMonitoring])
        XCTAssertEqual(hyperKey.state, .enabled)
    }

    func testEnabledFeatureTurnsOffWhenItsGrantIsRemoved() {
        var flow = PermissionEnableFlow(feature: .hyperKey, enabled: true)
        flow.permissionsChanged(granted: [])
        XCTAssertEqual(flow.state, .off)
    }
}
