// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Combine
import Foundation
import OmnicastCore

@MainActor
public final class ScheduleViewModel: ObservableObject {
    @Published public private(set) var events: [CalendarEvent] = []
    @Published public private(set) var groups: [CalendarDayGroup] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?

    public let service: CalendarService

    private let calendar: Foundation.Calendar
    private let referenceDate: () -> Date
    private var subscriptions = Set<AnyCancellable>()

    public init(
        service: CalendarService,
        calendar: Foundation.Calendar = .current,
        referenceDate: @escaping () -> Date = Date.init
    ) {
        self.service = service
        self.calendar = calendar
        self.referenceDate = referenceDate

        service.$changeCount
            .dropFirst()
            .sink { [weak self] _ in
                guard let self, self.service.accessState == .granted else { return }
                Task { await self.reload() }
            }
            .store(in: &subscriptions)
        service.$accessState
            .dropFirst()
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &subscriptions)
    }

    public var accessState: CalendarAccessState {
        service.accessState
    }

    public func activate() async {
        if service.accessState == .notDetermined {
            await requestAccess()
        } else if service.accessState == .granted {
            await reload()
        }
    }

    public func requestAccess() async {
        isLoading = true
        errorMessage = nil
        do {
            let granted = try await service.requestAccess()
            if granted {
                try loadEvents()
            } else {
                events = []
                groups = []
                errorMessage = "Calendar access was not granted"
            }
        } catch {
            events = []
            groups = []
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    public func reload() async {
        isLoading = true
        errorMessage = nil
        do {
            try loadEvents()
        } catch {
            events = []
            groups = []
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    public func open(_ event: CalendarEvent) {
        if let calendarURL = event.calendarURL,
           NSWorkspace.shared.open(calendarURL) {
            return
        }
        guard let applicationURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.iCal"
        ) else { return }
        NSWorkspace.shared.openApplication(
            at: applicationURL,
            configuration: NSWorkspace.OpenConfiguration()
        )
    }

    public func openCalendarPrivacySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    private func loadEvents() throws {
        let loaded = try service.fetchThisWeek(referenceDate: referenceDate())
        events = loaded
        groups = CalendarEventGrouper.groups(for: loaded, calendar: calendar)
    }
}
