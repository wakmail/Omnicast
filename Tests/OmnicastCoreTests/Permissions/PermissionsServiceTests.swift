// SPDX-License-Identifier: GPL-3.0-or-later

@testable import OmnicastCore
import XCTest

@MainActor
final class PermissionsServiceTests: XCTestCase {
    func testPollsOnlyWhileRequestedGrantsAreMissing() {
        let checker = MutablePermissionChecker()
        let service = makeService(checker: checker)

        XCTAssertFalse(service.accessibility)
        XCTAssertFalse(service.inputMonitoring)
        XCTAssertFalse(service.isPolling)

        service.requestAccessibility()
        service.requestInputMonitoring()

        XCTAssertEqual(service.waitingFor, [.accessibility, .inputMonitoring])
        XCTAssertTrue(service.isPolling)

        checker.accessibility = true
        service.refresh()

        XCTAssertTrue(service.accessibility)
        XCTAssertEqual(service.waitingFor, [.inputMonitoring])
        XCTAssertTrue(service.isPolling)

        checker.inputMonitoring = true
        service.refresh()

        XCTAssertTrue(service.inputMonitoring)
        XCTAssertTrue(service.waitingFor.isEmpty)
        XCTAssertFalse(service.isPolling)
    }

    func testRequestsOpenExactPrivacyPanesAndPublishKinds() {
        let checker = MutablePermissionChecker()
        var opened: [URL] = []
        var requested: [PermissionKind] = []
        var accessibilityPrompts = 0
        var inputPrompts = 0
        let service = PermissionsService(
            checker: checker,
            pollInterval: 3_600,
            accessibilityRequester: { accessibilityPrompts += 1 },
            inputMonitoringRequester: { inputPrompts += 1 },
            settingsOpener: { opened.append($0) }
        )
        service.onRequest = { requested.append($0) }

        service.requestAccessibility()
        service.requestInputMonitoring()

        XCTAssertEqual(accessibilityPrompts, 1)
        XCTAssertEqual(inputPrompts, 1)
        XCTAssertEqual(requested, [.accessibility, .inputMonitoring])
        XCTAssertEqual(opened.map(\.absoluteString), [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        ])
    }

    private func makeService(checker: MutablePermissionChecker) -> PermissionsService {
        PermissionsService(
            checker: checker,
            pollInterval: 3_600,
            accessibilityRequester: {},
            inputMonitoringRequester: {},
            settingsOpener: { _ in }
        )
    }
}

private final class MutablePermissionChecker: PermissionChecking {
    var accessibility = false
    var inputMonitoring = false

    func accessibilityGranted() -> Bool { accessibility }
    func inputMonitoringGranted() -> Bool { inputMonitoring }
}
