// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import OmnicastCore
import SwiftUI

struct CommandRowView: View {
    let command: any Command
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: LauncherTheme.Metrics.rowIconTitleSpacing) {
            CommandIconView(icon: command.icon)
                .frame(
                    width: LauncherTheme.Metrics.rowIconSize,
                    height: LauncherTheme.Metrics.rowIconSize
                )

            HStack(spacing: LauncherTheme.Metrics.rowSubtitleSpacing) {
                Text(command.title)
                    .font(LauncherTheme.Typography.rowTitle)
                    .foregroundStyle(LauncherTheme.Palette.primaryText(for: colorScheme))
                    .lineLimit(1)
                    .layoutPriority(1)

                if !command.subtitle.isEmpty {
                    Text(command.subtitle)
                        .font(LauncherTheme.Typography.rowSubtitle)
                        .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: LauncherTheme.Metrics.rowTrailingSpacing)

            Text(command.kind.rawValue)
                .font(LauncherTheme.Typography.rowKind)
                .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
                .lineLimit(1)
        }
        .padding(.horizontal, LauncherTheme.Metrics.rowContentPadding)
        .frame(maxWidth: .infinity, minHeight: LauncherTheme.Metrics.rowHeight, maxHeight: LauncherTheme.Metrics.rowHeight)
        .background {
            RoundedRectangle(
                cornerRadius: LauncherTheme.Metrics.rowCornerRadius,
                style: .continuous
            )
            .fill(isSelected ? LauncherTheme.Palette.selectedRow(for: colorScheme) : Color.clear)
            .overlay {
                RoundedRectangle(
                    cornerRadius: LauncherTheme.Metrics.rowCornerRadius,
                    style: .continuous
                )
                .strokeBorder(
                    isSelected ? LauncherTheme.Palette.borderPrimary(for: colorScheme) : Color.clear,
                    lineWidth: LauncherTheme.Metrics.borderWidth
                )
            }
        }
    }
}

struct CommandIconView: View {
    let icon: CommandIcon

    var body: some View {
        Group {
            switch icon {
            case .sfSymbol(let name):
                Image(systemName: name)
                    .resizable()
                    .scaledToFit()
                    .padding(LauncherTheme.Metrics.symbolIconPadding)
            case .appBundle(let url):
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .scaledToFit()
            case .image(let url):
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Image(systemName: "photo")
                }
            case .emoji(let value):
                Text(value).font(LauncherTheme.Typography.emojiIcon)
            }
        }
    }
}
