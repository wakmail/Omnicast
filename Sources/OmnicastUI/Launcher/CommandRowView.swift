// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import OmnicastCore
import SwiftUI

struct CommandRowView: View {
    let command: any Command
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            CommandIconView(icon: command.icon)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(command.title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                if !command.subtitle.isEmpty {
                    Text(command.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Text(command.kind.rawValue)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .frame(height: 40)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.white.opacity(0.14) : Color.clear)
        }
    }
}

private struct CommandIconView: View {
    let icon: CommandIcon

    var body: some View {
        Group {
            switch icon {
            case .sfSymbol(let name):
                Image(systemName: name)
                    .resizable()
                    .scaledToFit()
                    .padding(4)
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
                Text(value).font(.system(size: 22))
            }
        }
    }
}
