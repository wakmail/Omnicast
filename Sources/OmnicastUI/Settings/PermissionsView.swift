// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import SwiftUI

public struct PermissionsView: View {
    @ObservedObject private var permissions: PermissionsService

    @MainActor
    public init(permissions: PermissionsService) {
        self.permissions = permissions
    }

    public var body: some View {
        Form {
            Section {
                Text("Permissions are requested only when you choose a feature that needs them.")
                    .foregroundStyle(.secondary)
            }

            Section {
                permissionRow(
                    title: "Accessibility",
                    detail: "Used by window commands and snippet insertion.",
                    granted: permissions.accessibility,
                    request: permissions.requestAccessibility
                )
                permissionRow(
                    title: "Input Monitoring",
                    detail: "Used by snippet keyword listening and the Hyper key.",
                    granted: permissions.inputMonitoring,
                    request: permissions.requestInputMonitoring
                )
            }

            Section {
                Button("Open System Settings") {
                    permissions.openSystemSettings()
                }
            }
        }
        .formStyle(.grouped)
        .padding(LauncherTheme.Metrics.searchHorizontalPadding)
        .onAppear { permissions.refresh() }
    }

    private func permissionRow(
        title: String,
        detail: String,
        granted: Bool,
        request: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? Color.green : Color.secondary)
                .font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                    Text(granted ? "Granted" : "Not granted")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !granted {
                Button("Request", action: request)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 5)
    }
}

public struct OnboardingPermissionsView: View {
    private let onContinue: () -> Void

    public init(onContinue: @escaping () -> Void) {
        self.onContinue = onContinue
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome to Omnicast")
                    .font(.title2.weight(.semibold))
                Text("Permissions stay optional until you turn on a feature that needs them.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                featureLine(icon: "macwindow", text: "Window commands use Accessibility.")
                featureLine(
                    icon: "text.quote",
                    text: "Snippet expansion uses Accessibility and Input Monitoring."
                )
                featureLine(icon: "capslock", text: "The Hyper key uses Input Monitoring.")
                featureLine(
                    icon: "checkmark.circle",
                    text: "Everything else works without these permissions."
                )
            }

            Spacer()

            HStack {
                Text("Press Esc or choose Continue")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Continue", action: onContinue)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func featureLine(icon: String, text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)
        }
    }
}
