// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
import Combine
import Foundation
import Speech

public enum DictationPermissionState: Equatable, Sendable {
    case notDetermined
    case granted
    case denied
    case restricted
    case unknown
}

@MainActor
public final class DictationPermissions: ObservableObject {
    @Published public private(set) var microphone: DictationPermissionState
    @Published public private(set) var speechRecognition: DictationPermissionState

    public init() {
        microphone = Self.microphoneState()
        speechRecognition = Self.speechState()
    }

    public var isGranted: Bool {
        microphone == .granted && speechRecognition == .granted
    }

    public func refresh() {
        microphone = Self.microphoneState()
        speechRecognition = Self.speechState()
    }

    @discardableResult
    public func requestMicrophone() async -> DictationPermissionState {
        _ = await AVCaptureDevice.requestAccess(for: .audio)
        let state = Self.microphoneState()
        microphone = state
        return state
    }

    @discardableResult
    public func requestSpeechRecognition() async -> DictationPermissionState {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        let state = Self.map(status)
        speechRecognition = state
        return state
    }

    private static func microphoneState() -> DictationPermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined: .notDetermined
        case .authorized: .granted
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .unknown
        }
    }

    private static func speechState() -> DictationPermissionState {
        map(SFSpeechRecognizer.authorizationStatus())
    }

    private static func map(
        _ status: SFSpeechRecognizerAuthorizationStatus
    ) -> DictationPermissionState {
        switch status {
        case .notDetermined: .notDetermined
        case .authorized: .granted
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .unknown
        }
    }
}
