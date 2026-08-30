// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import SwiftUI

public struct ScheduleView: View {
    @StateObject private var model: ScheduleViewModel
    @Environment(\.colorScheme) private var colorScheme

    @MainActor
    public init(viewModel: ScheduleViewModel) {
        _model = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        Group {
            if model.isLoading && model.groups.isEmpty {
                ProgressView("Loading schedule")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.accessState != .granted {
                permissionView
            } else if model.groups.isEmpty {
                emptyView
            } else {
                scheduleList
            }
        }
        .background(LauncherTheme.Palette.surface(for: colorScheme))
        .task { await model.activate() }
    }

    private var scheduleList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18, pinnedViews: [.sectionHeaders]) {
                ForEach(model.groups) { group in
                    Section {
                        VStack(spacing: 4) {
                            ForEach(group.events) { event in
                                Button {
                                    model.open(event)
                                } label: {
                                    ScheduleEventRow(event: event, colorScheme: colorScheme)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } header: {
                        ScheduleDayHeader(
                            title: dayTitle(group.date),
                            colorScheme: colorScheme
                        )
                    }
                }
            }
            .padding(14)
        }
        .scrollIndicators(.hidden)
    }

    private var permissionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 30))
                .foregroundStyle(secondaryText)
            Text(permissionTitle)
                .font(.system(size: 15, weight: .semibold))
            Text("Omnicast needs Calendar access to show your schedule")
                .font(.system(size: 13))
                .foregroundStyle(secondaryText)
            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.red)
            }
            if model.accessState == .notDetermined {
                Button("Allow Calendar Access") {
                    Task { await model.requestAccess() }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Open Calendar Privacy Settings") {
                    model.openCalendarPrivacySettings()
                }
            }
        }
        .multilineTextAlignment(.center)
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar")
                .font(.system(size: 28))
            Text("Your week is clear")
                .font(.system(size: 15, weight: .semibold))
            Text("Events for the next seven days will appear here")
                .font(.system(size: 13))
        }
        .foregroundStyle(secondaryText)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var permissionTitle: String {
        switch model.accessState {
        case .notDetermined:
            return "See your schedule"
        case .denied, .restricted, .writeOnly:
            return "Calendar access is unavailable"
        case .unknown:
            return "Calendar status is unavailable"
        case .granted:
            return "My Schedule"
        }
    }

    private func dayTitle(_ date: Date) -> String {
        let calendar = Foundation.Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private var secondaryText: Color {
        LauncherTheme.Palette.secondaryText(for: colorScheme)
    }
}

private struct ScheduleDayHeader: View {
    let title: String
    let colorScheme: ColorScheme

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .background(LauncherTheme.Palette.surface(for: colorScheme))
    }
}

private struct ScheduleEventRow: View {
    let event: CalendarEvent
    let colorScheme: ColorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Circle()
                .fill(Color(
                    red: event.calendarColor.red,
                    green: event.calendarColor.green,
                    blue: event.calendarColor.blue,
                    opacity: event.calendarColor.alpha
                ))
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(LauncherTheme.Palette.primaryText(for: colorScheme))
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(timeRange)
                    Text(event.calendarName)
                    if let location = event.location, !location.isEmpty {
                        Text(location)
                            .lineLimit(1)
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
            }
            Spacer(minLength: 8)
            Image(systemName: "arrow.up.forward.app")
                .font(.system(size: 11))
                .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
                .padding(.top, 3)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(
            LauncherTheme.Palette.selectedRow(for: colorScheme).opacity(0.45),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .contentShape(Rectangle())
    }

    private var timeRange: String {
        if event.isAllDay { return "All day" }
        let start = event.start.formatted(date: .omitted, time: .shortened)
        let end = event.end.formatted(date: .omitted, time: .shortened)
        return "\(start) to \(end)"
    }
}
