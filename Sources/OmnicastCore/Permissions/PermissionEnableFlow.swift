// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation

public enum PermissionFeature: Equatable, Sendable {
    case snippets
    case hyperKey

    public var requiredPermissions: [PermissionKind] {
        switch self {
        case .snippets: [.accessibility, .inputMonitoring]
        case .hyperKey: [.inputMonitoring]
        }
    }

    public var waitingMessage: String {
        switch self {
        case .snippets:
            "Snippet expansion stays off until Accessibility and Input Monitoring are granted."
        case .hyperKey:
            "The Hyper key stays off until Input Monitoring is granted."
        }
    }
}

public enum PermissionEnableState: Equatable, Sendable {
    case off
    case waiting(Set<PermissionKind>)
    case enabled
}

/// The pure enable flow shared by snippets and the Hyper key. A request can
/// wait across several grants, but the feature is enabled only after every
/// permission it needs has landed.
public struct PermissionEnableFlow: Equatable, Sendable {
    public let feature: PermissionFeature
    public private(set) var state: PermissionEnableState

    public init(feature: PermissionFeature, enabled: Bool = false) {
        self.feature = feature
        state = enabled ? .enabled : .off
    }

    public mutating func requestEnable(granted: Set<PermissionKind>) {
        reconcile(granted: granted, preserveOff: false)
    }

    public mutating func permissionsChanged(granted: Set<PermissionKind>) {
        switch state {
        case .off:
            return
        case .waiting:
            reconcile(granted: granted, preserveOff: false)
        case .enabled:
            let missing = Set(feature.requiredPermissions).subtracting(granted)
            if !missing.isEmpty { state = .off }
        }
    }

    public mutating func disable() {
        state = .off
    }

    public var nextPermissionToRequest: PermissionKind? {
        guard case .waiting(let missing) = state else { return nil }
        return feature.requiredPermissions.first { missing.contains($0) }
    }

    private mutating func reconcile(
        granted: Set<PermissionKind>,
        preserveOff: Bool
    ) {
        if preserveOff, state == .off { return }
        let missing = Set(feature.requiredPermissions).subtracting(granted)
        state = missing.isEmpty ? .enabled : .waiting(missing)
    }
}

/// Keeps a pending enable request alive even if the Settings window closes.
/// It asks for one permission at a time, then persists the enabled value when
/// the final grant arrives.
@MainActor
public final class PermissionFeatureController: ObservableObject {
    public let feature: PermissionFeature
    @Published public private(set) var flow: PermissionEnableFlow
    @Published public private(set) var errorMessage: String?

    private let permissions: PermissionsService
    private let persistEnabled: (Bool) throws -> Void
    private var requestedPermission: PermissionKind?
    private var nextRequestWork: DispatchWorkItem?
    private var subscriptions = Set<AnyCancellable>()

    public init(
        feature: PermissionFeature,
        enabled: Bool,
        permissions: PermissionsService,
        persistEnabled: @escaping (Bool) throws -> Void
    ) {
        self.feature = feature
        self.permissions = permissions
        self.persistEnabled = persistEnabled
        flow = PermissionEnableFlow(feature: feature, enabled: enabled)

        permissions.$accessibility
            .combineLatest(permissions.$inputMonitoring)
            .dropFirst()
            .sink { [weak self] _, _ in self?.permissionsChanged() }
            .store(in: &subscriptions)
    }

    public var isEnabled: Bool {
        flow.state == .enabled
    }

    public var isWaiting: Bool {
        if case .waiting = flow.state { return true }
        return false
    }

    public func setEnabled(_ enabled: Bool) {
        if !enabled {
            nextRequestWork?.cancel()
            nextRequestWork = nil
            requestedPermission = nil
            flow.disable()
            persist(false)
            return
        }
        flow.requestEnable(granted: permissions.grantedPermissions)
        driveFlow()
    }

    private func permissionsChanged() {
        let wasEnabled = flow.state == .enabled
        var completedRequest = false
        if let requestedPermission,
           permissions.grantedPermissions.contains(requestedPermission) {
            self.requestedPermission = nil
            completedRequest = true
        }
        flow.permissionsChanged(granted: permissions.grantedPermissions)
        if wasEnabled, flow.state == .off {
            persist(false)
            return
        }
        if completedRequest, case .waiting = flow.state {
            // Let the guide show its success beat before the next privacy pane
            // and guide replace it.
            nextRequestWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.nextRequestWork = nil
                self?.driveFlow()
            }
            nextRequestWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: work)
            return
        }
        driveFlow()
    }

    private func driveFlow() {
        switch flow.state {
        case .off:
            break
        case .enabled:
            requestedPermission = nil
            persist(true)
        case .waiting:
            guard requestedPermission == nil,
                  let next = flow.nextPermissionToRequest else { return }
            requestedPermission = next
            permissions.request(next)
        }
    }

    private func persist(_ enabled: Bool) {
        do {
            try persistEnabled(enabled)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            if enabled { flow.disable() }
        }
    }
}
