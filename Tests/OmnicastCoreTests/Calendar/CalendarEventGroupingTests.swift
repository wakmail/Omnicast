// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OmnicastCore
import XCTest

final class CalendarEventGroupingTests: XCTestCase {
    func testGroupingUsesInjectedCalendarAndSortsEventsWithinDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let firstDay = try date(2026, 8, 30, 0, calendar: calendar)
        let secondDay = try date(2026, 8, 31, 0, calendar: calendar)
        let later = fixture(
            id: "later",
            start: try date(2026, 8, 30, 15, calendar: calendar)
        )
        let nextDay = fixture(
            id: "next",
            start: try date(2026, 8, 31, 9, calendar: calendar)
        )
        let earlier = fixture(
            id: "earlier",
            start: try date(2026, 8, 30, 8, calendar: calendar)
        )

        let groups = CalendarEventGrouper.groups(
            for: [later, nextDay, earlier],
            calendar: calendar
        )

        XCTAssertEqual(groups.map(\.date), [firstDay, secondDay])
        XCTAssertEqual(groups[0].events.map(\.id), ["earlier", "later"])
        XCTAssertEqual(groups[1].events.map(\.id), ["next"])
    }

    func testCalendarURLTargetsEventIdentifier() throws {
        let event = fixture(id: "event/id", start: Date(timeIntervalSince1970: 100))
        let url = try XCTUnwrap(event.calendarURL)

        XCTAssertEqual(url.scheme, "ical")
        XCTAssertTrue(url.absoluteString.contains("event%2Fid"))
        XCTAssertTrue(url.absoluteString.contains("method=show"))
    }

    private func fixture(id: String, start: Date) -> CalendarEvent {
        CalendarEvent(
            id: id,
            calendarID: "work",
            calendarName: "Work",
            title: id,
            start: start,
            end: start.addingTimeInterval(3_600)
        )
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        calendar: Calendar
    ) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour
        )))
    }
}
