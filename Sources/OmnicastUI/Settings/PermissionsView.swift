// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import SwiftUI

public struct PermissionsView: View {
    private let windowAdjuster: WindowAdjuster
    private let hyperKeyManager: HyperKeyManager
    private let snippetExpander: SnippetExpander?
    @State private var refreshToken = UUID()
    @Environment(\.colorScheme) private var colorScheme

    @MainActor
    public init(
        windowAdjuster: WindowAdjuster,
        hyperKeyManager: HyperKeyManager,
        snippetExpander: SnippetExpander? = nil
    ) {
        self.windowAdjuster = windowAdjuster
        self.hyperKeyManager = hyperKeyManager
        self.snippetExpander = snippetExpander
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: LauncherTheme.Metrics.footerGroupSpacing) {
            Text("Permissions")
                .font(LauncherTheme.Typography.search)
                .foregroundStyle(LauncherTheme.Palette.primaryText(for: colorScheme))

            Text("Omnicast uses these permissions for window commands, the Hyper key, and snippet expansion.")
                .font(LauncherTheme.Typography.rowSubtitle)
                .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))

            permissionRow(
                title: "Accessibility",
                detail: "Move windows and expand snippets",
                granted: windowAdjuster.accessibilityGranted,
                request: {
                    _ = windowAdjuster.requestAccessibility()
                    refresh()
                }
            )

            permissionRow(
                title: "Input Monitoring",
                detail: "Read Hyper key and snippet keystrokes",
                granted: hyperKeyManager.inputMonitoringGranted,
                request: {
                    _ = hyperKeyManager.requestInputMonitoring()
                    snippetExpander?.requestPermission()
                    refresh()
                }
            )

            Button("Refresh Status", action: refresh)
                .buttonStyle(.bordered)
        }
        .padding(LauncherTheme.Metrics.searchHorizontalPadding)
        .id(refreshToken)
    }

    private func permissionRow(
        title: String,
        detail: String,
        granted: Bool,
        request: @escaping () -> Void
    ) -> some View {
        HStack(spacing: LauncherTheme.Metrics.rowIconTitleSpacing) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(granted ? Color.green : LauncherTheme.Palette.accent)
                .frame(
                    width: LauncherTheme.Metrics.rowIconSize,
                    height: LauncherTheme.Metrics.rowIconSize
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(LauncherTheme.Typography.rowTitle)
                    .foregroundStyle(LauncherTheme.Palette.primaryText(for: colorScheme))
                Text(detail)
                    .font(LauncherTheme.Typography.rowSubtitle)
                    .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
            }
            Spacer()
            if granted {
                Text("Granted")
                    .font(LauncherTheme.Typography.footerTitle)
                    .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
            } else {
                Button("Request", action: request)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(LauncherTheme.Metrics.rowContentPadding)
        .background(
            LauncherTheme.Palette.selectedRow(for: colorScheme),
            in: RoundedRectangle(cornerRadius: LauncherTheme.Metrics.rowCornerRadius)
        )
    }

    private func refresh() {
        refreshToken = UUID()
    }
}

public struct OnboardingPermissionsView: View {
    private let windowAdjuster: WindowAdjuster
    private let hyperKeyManager: HyperKeyManager
    private let snippetExpander: SnippetExpander?

    @MainActor
    public init(
        windowAdjuster: WindowAdjuster,
        hyperKeyManager: HyperKeyManager,
        snippetExpander: SnippetExpander? = nil
    ) {
        self.windowAdjuster = windowAdjuster
        self.hyperKeyManager = hyperKeyManager
        self.snippetExpander = snippetExpander
    }

    public var body: some View {
        PermissionsView(
            windowAdjuster: windowAdjuster,
            hyperKeyManager: hyperKeyManager,
            snippetExpander: snippetExpander
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
