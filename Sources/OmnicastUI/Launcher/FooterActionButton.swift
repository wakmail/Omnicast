// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

public struct FooterActionButton: View {
    private let label: String
    private let keys: [String]
    private let action: () -> Void

    public init(
        _ label: String,
        keys: [String],
        action: @escaping () -> Void
    ) {
        self.label = label
        self.keys = keys
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: LauncherTheme.Metrics.footerLabelSpacing) {
                Text(label)
                    .font(LauncherTheme.Typography.footerAction)
                HStack(spacing: LauncherTheme.Metrics.keyCapSpacing) {
                    ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                        FooterKeyCap(key)
                    }
                }
            }
        }
        .buttonStyle(FooterActionButtonStyle())
        .focusable(false)
    }
}

private struct FooterActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        FooterActionButtonStyleBody(configuration: configuration)
    }
}

private struct FooterActionButtonStyleBody: View {
    let configuration: ButtonStyle.Configuration

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    var body: some View {
        configuration.label
            .foregroundStyle(LauncherTheme.Palette.primaryText(for: colorScheme))
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                LauncherTheme.Palette.selectedRow(for: colorScheme)
                    .opacity(backgroundOpacity),
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .opacity(isEnabled ? 1 : 0.42)
            .onHover { isHovering = $0 }
    }

    private var backgroundOpacity: Double {
        guard isEnabled else { return 0 }
        if configuration.isPressed { return 1 }
        return isHovering ? 0.72 : 0
    }
}

private struct FooterKeyCap: View {
    let label: String

    @Environment(\.colorScheme) private var colorScheme

    init(_ label: String) {
        self.label = label
    }

    var body: some View {
        Text(label)
            .font(LauncherTheme.Typography.keyCap)
            .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
            .padding(.horizontal, LauncherTheme.Metrics.keyCapHorizontalPadding)
            .frame(
                minWidth: LauncherTheme.Metrics.keyCapMinimumWidth,
                minHeight: LauncherTheme.Metrics.keyCapHeight,
                maxHeight: LauncherTheme.Metrics.keyCapHeight
            )
            .background(
                LauncherTheme.Palette.keyCap(for: colorScheme),
                in: RoundedRectangle(
                    cornerRadius: LauncherTheme.Metrics.keyCapCornerRadius,
                    style: .continuous
                )
            )
    }
}
