// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastUI
import XCTest

final class LauncherThemeTests: XCTestCase {
    func testZeroRowsUsesMinimumHeight() {
        XCTAssertEqual(
            LauncherTheme.Metrics.panelHeight(
                rowCount: 0,
                sectionCount: 1,
                windowMode: .standard
            ),
            LauncherTheme.Metrics.minimumPanelHeight
        )
    }

    func testOneRowIncludesSectionHeader() {
        XCTAssertEqual(
            LauncherTheme.Metrics.panelHeight(
                rowCount: 1,
                sectionCount: 1,
                windowMode: .standard
            ),
            LauncherTheme.Metrics.minimumPanelHeight
                + LauncherTheme.Metrics.sectionHeaderHeight
        )
    }

    func testSectionHeadersContributeToHeight() {
        let oneSection = LauncherTheme.Metrics.panelHeight(
            rowCount: 1,
            sectionCount: 1,
            windowMode: .standard
        )
        let twoSections = LauncherTheme.Metrics.panelHeight(
            rowCount: 1,
            sectionCount: 2,
            windowMode: .standard
        )

        XCTAssertEqual(
            twoSections,
            oneSection + LauncherTheme.Metrics.sectionHeaderHeight
        )
    }

    func testStandardMaximumRowCountUsesStandardCap() {
        XCTAssertEqual(
            LauncherTheme.Metrics.panelHeight(
                rowCount: 8,
                sectionCount: 1,
                windowMode: .standard
            ),
            LauncherTheme.Metrics.panelHeight
        )
    }

    func testCompactMaximumRowCountUsesCompactCap() {
        XCTAssertEqual(
            LauncherTheme.Metrics.panelHeight(
                rowCount: LauncherTheme.Metrics.compactResultRowCount,
                sectionCount: 1,
                windowMode: .compact
            ),
            LauncherTheme.Metrics.compactPanelHeight
        )
    }

    func testRowsBeyondMaximumRemainClamped() {
        XCTAssertEqual(
            LauncherTheme.Metrics.panelHeight(
                rowCount: 100,
                sectionCount: 4,
                windowMode: .standard
            ),
            LauncherTheme.Metrics.panelHeight
        )
        XCTAssertEqual(
            LauncherTheme.Metrics.panelHeight(
                rowCount: 100,
                sectionCount: 4,
                windowMode: .compact
            ),
            LauncherTheme.Metrics.compactPanelHeight
        )
    }
}
