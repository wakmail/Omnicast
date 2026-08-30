// SPDX-License-Identifier: GPL-3.0-or-later

@testable import OmnicastCore
import XCTest

final class WindowCommandsProviderTests: XCTestCase {
    func testProviderExposesEveryPlacementWithUniqueIdentifiers() async {
        let commands = await WindowCommandsProvider().commands()
        XCTAssertEqual(commands.count, WindowPlacement.allCases.count)
        XCTAssertEqual(Set(commands.map(\.id)).count, commands.count)
        XCTAssertTrue(commands.allSatisfy { $0.kind == .window })
    }

    func testUpstreamNamesAndSearchTerms() async throws {
        let commands = await WindowCommandsProvider().commands()
        let left = try XCTUnwrap(commands.first { $0.id == "system-window-management-left" })
        XCTAssertEqual(left.title, "Window: Left Half")
        XCTAssertTrue(left.keywords.contains("left half"))

        let maximize = try XCTUnwrap(commands.first { $0.id == "system-window-management-fill" })
        XCTAssertEqual(maximize.title, "Window: Maximize")
    }
}
