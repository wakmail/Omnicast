// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct CalendarEventColor: Codable, Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let fallback = CalendarEventColor(
        red: 0.545,
        green: 0.576,
        blue: 0.631
    )
}

public struct CalendarEvent: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let calendarID: String
    public let calendarName: String
    public let calendarColor: CalendarEventColor
    public let title: String
    public let location: String?
    public let notes: String?
    public let start: Date
    public let end: Date
    public let isAllDay: Bool

    public init(
        id: String,
        calendarID: String,
        calendarName: String,
        calendarColor: CalendarEventColor = .fallback,
        title: String,
        location: String? = nil,
        notes: String? = nil,
        start: Date,
        end: Date,
        isAllDay: Bool = false
    ) {
        self.id = id
        self.calendarID = calendarID
        self.calendarName = calendarName
        self.calendarColor = calendarColor
        self.title = title
        self.location = location
        self.notes = notes
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
    }

    public var calendarURL: URL? {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        guard let identifier = id.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return nil
        }
        return URL(string: "ical://ekevent/\(identifier)?method=show&options=more")
    }
}

public struct CalendarDayGroup: Equatable, Identifiable, Sendable {
    public let date: Date
    public let events: [CalendarEvent]

    public var id: Date { date }

    public init(date: Date, events: [CalendarEvent]) {
        self.date = date
        self.events = events
    }
}

public enum CalendarEventGrouper {
    public static func groups(
        for events: [CalendarEvent],
        calendar: Foundation.Calendar = .current
    ) -> [CalendarDayGroup] {
        let sorted = events.sorted { left, right in
            if left.start != right.start { return left.start < right.start }
            if left.end != right.end { return left.end < right.end }
            return left.id < right.id
        }
        let grouped = Dictionary(grouping: sorted) { event in
            calendar.startOfDay(for: event.start)
        }
        return grouped.keys.sorted().map { date in
            CalendarDayGroup(date: date, events: grouped[date] ?? [])
        }
    }
}
