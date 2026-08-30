// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import ApplicationServices
import Combine
import Foundation
import IOKit

public enum PermissionKind: String, CaseIterable, Hashable, Sendable {
    case accessibility
    case inputMonitoring

    public var displayName: String {
        switch self {
        case .accessibility: "Accessibility"
        case .inputMonitoring: "Input Monitoring"
        }
    }
}

public protocol PermissionChecking {
    func accessibilityGranted() -> Bool
    func inputMonitoringGranted() -> Bool
}

public struct SystemPermissionChecker: PermissionChecking {
    public init() {}

    public func accessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }

    public func inputMonitoringGranted() -> Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }
}

/// Central place to check, request and watch the permissions Omnicast uses.
/// Accessibility powers window commands and snippet insertion. Input
/// Monitoring powers the Hyper key and snippet keyword listening.
///
/// Polling exists only while a request is waiting for a grant. The timer is
/// released as soon as every requested permission is granted.
@MainActor
public final class PermissionsService: ObservableObject {
    @Published public private(set) var accessibility: Bool
    @Published public private(set) var inputMonitoring: Bool
    @Published public private(set) var waitingFor: Set<PermissionKind> = []

    /// The app shell uses this to show its floating guide without making the
    /// core service depend on a window implementation.
    public var onRequest: ((PermissionKind) -> Void)?

    private let checker: any PermissionChecking
    private let accessibilityRequester: @MainActor () -> Void
    private let inputMonitoringRequester: @MainActor () -> Void
    private let settingsOpener: @MainActor (URL) -> Void
    private let pollInterval: TimeInterval
    private var pollTimer: Timer?

    public convenience init(
        checker: any PermissionChecking = SystemPermissionChecker(),
        pollInterval: TimeInterval = 2
    ) {
        self.init(
            checker: checker,
            pollInterval: pollInterval,
            accessibilityRequester: Self.promptForAccessibility,
            inputMonitoringRequester: Self.promptForInputMonitoring,
            settingsOpener: Self.openSettingsURL
        )
    }

    public init(
        checker: any PermissionChecking,
        pollInterval: TimeInterval = 2,
        accessibilityRequester: @escaping @MainActor () -> Void,
        inputMonitoringRequester: @escaping @MainActor () -> Void,
        settingsOpener: @escaping @MainActor (URL) -> Void
    ) {
        self.checker = checker
        self.pollInterval = pollInterval
        self.accessibilityRequester = accessibilityRequester
        self.inputMonitoringRequester = inputMonitoringRequester
        self.settingsOpener = settingsOpener
        accessibility = checker.accessibilityGranted()
        inputMonitoring = checker.inputMonitoringGranted()
    }

    deinit {
        pollTimer?.invalidate()
    }

    public var isPolling: Bool {
        pollTimer != nil
    }

    public var grantedPermissions: Set<PermissionKind> {
        var result: Set<PermissionKind> = []
        if accessibility { result.insert(.accessibility) }
        if inputMonitoring { result.insert(.inputMonitoring) }
        return result
    }

    public func refresh() {
        let accessibilityGranted = checker.accessibilityGranted()
        let inputMonitoringGranted = checker.inputMonitoringGranted()
        if accessibility != accessibilityGranted {
            accessibility = accessibilityGranted
        }
        if inputMonitoring != inputMonitoringGranted {
            inputMonitoring = inputMonitoringGranted
        }
        if accessibility { waitingFor.remove(.accessibility) }
        if inputMonitoring { waitingFor.remove(.inputMonitoring) }
        updatePolling()
    }

    public func request(_ kind: PermissionKind) {
        switch kind {
        case .accessibility: requestAccessibility()
        case .inputMonitoring: requestInputMonitoring()
        }
    }

    /// Registers the app with the Accessibility service, opens the exact
    /// privacy pane and starts watching for the grant.
    public func requestAccessibility() {
        refresh()
        guard !accessibility else { return }
        waitingFor.insert(.accessibility)
        updatePolling()
        accessibilityRequester()
        settingsOpener(Self.accessibilitySettingsURL)
        onRequest?(.accessibility)
    }

    /// Registers the app with Input Monitoring, opens the exact privacy pane
    /// and starts watching for the grant.
    public func requestInputMonitoring() {
        refresh()
        guard !inputMonitoring else { return }
        waitingFor.insert(.inputMonitoring)
        updatePolling()
        inputMonitoringRequester()
        settingsOpener(Self.inputMonitoringSettingsURL)
        onRequest?(.inputMonitoring)
    }

    /// Opens the privacy area from Settings and watches any missing grants so
    /// the status rows update while System Settings is in front.
    public func openSystemSettings() {
        if !accessibility { waitingFor.insert(.accessibility) }
        if !inputMonitoring { waitingFor.insert(.inputMonitoring) }
        updatePolling()
        settingsOpener(Self.accessibilitySettingsURL)
    }

    private func updatePolling() {
        if waitingFor.isEmpty {
            pollTimer?.invalidate()
            pollTimer = nil
            return
        }
        guard pollTimer == nil else { return }
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer.tolerance = min(0.4, pollInterval * 0.2)
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private static let accessibilitySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )!
    private static let inputMonitoringSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
    )!

    private static func promptForAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    private static func promptForInputMonitoring() {
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    private static func openSettingsURL(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
