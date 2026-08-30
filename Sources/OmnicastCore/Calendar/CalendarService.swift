// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import CoreGraphics
import EventKit
import Foundation

public enum CalendarAccessState: String, Equatable, Sendable {
    case granted
    case writeOnly
    case denied
    case restricted
    case notDetermined
    case unknown
}

public enum CalendarServiceError: LocalizedError, Equatable {
    case accessRequired(CalendarAccessState)

    public var errorDescription: String? {
        switch self {
        case .accessRequired:
            return "Calendar access is required"
        }
    }
}

@MainActor
public final class CalendarService: ObservableObject {
    @Published public private(set) var accessState: CalendarAccessState
    @Published public private(set) var changeCount = 0

    private let eventStore: EKEventStore
    private let calendar: Foundation.Calendar
    private var changeObserver: NSObjectProtocol?

    public var isGranted: Bool {
        accessState == .granted
    }

    public init(
        eventStore: EKEventStore = EKEventStore(),
        calendar: Foundation.Calendar = .current
    ) {
        self.eventStore = eventStore
        self.calendar = calendar
        accessState = Self.currentAccessState()
        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.accessState = Self.currentAccessState()
                self?.changeCount += 1
            }
        }
    }

    deinit {
        if let changeObserver {
            NotificationCenter.default.removeObserver(changeObserver)
        }
    }

    @discardableResult
    public func requestAccess() async throws -> Bool {
        let granted = try await eventStore.requestFullAccessToEvents()
        accessState = Self.currentAccessState()
        return granted && accessState == .granted
    }

    public func fetchToday(referenceDate: Date = Date()) throws -> [CalendarEvent] {
        let start = calendar.startOfDay(for: referenceDate)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return try fetchEvents(from: start, to: end)
    }

    public func fetchThisWeek(referenceDate: Date = Date()) throws -> [CalendarEvent] {
        let start = calendar.startOfDay(for: referenceDate)
        guard let end = calendar.date(byAdding: .day, value: 7, to: start) else { return [] }
        return try fetchEvents(from: start, to: end)
    }

    public func fetchEvents(from start: Date, to end: Date) throws -> [CalendarEvent] {
        accessState = Self.currentAccessState()
        guard accessState == .granted else {
            throw CalendarServiceError.accessRequired(accessState)
        }
        let predicate = eventStore.predicateForEvents(
            withStart: start,
            end: end,
            calendars: nil
        )
        return eventStore.events(matching: predicate)
            .map(Self.calendarEvent)
            .sorted { left, right in
                if left.start != right.start { return left.start < right.start }
                return left.id < right.id
            }
    }

    public static func currentAccessState() -> CalendarAccessState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            return .granted
        case .writeOnly:
            return .writeOnly
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        case .authorized:
            return .granted
        @unknown default:
            return .unknown
        }
    }

    private static func calendarEvent(_ event: EKEvent) -> CalendarEvent {
        let title = event.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return CalendarEvent(
            id: event.eventIdentifier ?? event.calendarItemIdentifier,
            calendarID: event.calendar.calendarIdentifier,
            calendarName: event.calendar.title,
            calendarColor: color(from: event.calendar.cgColor),
            title: title.isEmpty ? "Untitled Event" : title,
            location: event.location,
            notes: event.notes,
            start: event.startDate,
            end: event.endDate,
            isAllDay: event.isAllDay
        )
    }

    private static func color(from color: CGColor?) -> CalendarEventColor {
        guard let color,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let converted = color.converted(
                to: colorSpace,
                intent: .defaultIntent,
                options: nil
              ),
              let components = converted.components else {
            return .fallback
        }
        if components.count == 2 {
            return CalendarEventColor(
                red: Double(components[0]),
                green: Double(components[0]),
                blue: Double(components[0]),
                alpha: Double(components[1])
            )
        }
        guard components.count >= 3 else { return .fallback }
        return CalendarEventColor(
            red: Double(components[0]),
            green: Double(components[1]),
            blue: Double(components[2]),
            alpha: components.count > 3 ? Double(components[3]) : 1
        )
    }
}
