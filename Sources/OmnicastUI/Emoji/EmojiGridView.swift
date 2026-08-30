// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import SwiftUI

public struct EmojiGridView: View {
    @StateObject private var model: EmojiGridViewModel
    @Environment(\.colorScheme) private var colorScheme

    @MainActor
    public init(model: EmojiGridViewModel) {
        _model = StateObject(wrappedValue: model)
    }

    public var body: some View {
        VStack(spacing: 0) {
            if model.emojis.isEmpty {
                Text("No emoji found")
                    .font(LauncherTheme.Typography.emptyState)
                    .foregroundStyle(secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVGrid(
                            columns: Array(
                                repeating: GridItem(.flexible(), spacing: 6),
                                count: model.columnCount
                            ),
                            spacing: 6
                        ) {
                            ForEach(Array(model.emojis.enumerated()), id: \.offset) { index, entry in
                                Button {
                                    model.select(index)
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(entry.emoji)
                                            .font(.system(size: 30))
                                        Text(entry.name.replacingOccurrences(of: "_", with: " "))
                                            .font(.system(size: 9))
                                            .foregroundStyle(secondaryText)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 58)
                                    .background(
                                        index == model.selectedIndex
                                            ? Color.accentColor.opacity(0.22)
                                            : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                                }
                                .buttonStyle(.plain)
                                .id(index)
                            }
                        }
                        .padding(10)
                    }
                    .onChange(of: model.selectedIndex) {
                        proxy.scrollTo(model.selectedIndex, anchor: .center)
                    }
                }
            }

            LauncherTheme.Palette.borderPrimary(for: colorScheme)
                .frame(height: 1)
            HStack {
                if let errorMessage = model.errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                } else if let selected = model.selectedEmoji {
                    Text(selected.name.replacingOccurrences(of: "_", with: " "))
                        .foregroundStyle(secondaryText)
                }
                Spacer()
                Text("Arrow keys move   Enter pastes")
                    .foregroundStyle(secondaryText)
            }
            .font(LauncherTheme.Typography.footerTitle)
            .padding(.horizontal, LauncherTheme.Metrics.footerHorizontalPadding)
            .frame(height: LauncherTheme.Metrics.footerHeight)

            keyboardShortcuts
        }
        .background(LauncherTheme.Palette.surface(for: colorScheme))
    }

    private var keyboardShortcuts: some View {
        Group {
            shortcut(.leftArrow) { model.moveLeft() }
            shortcut(.rightArrow) { model.moveRight() }
            shortcut(.upArrow) { model.moveUp() }
            shortcut(.downArrow) { model.moveDown() }
            shortcut(.return) { model.pasteSelected() }
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    private func shortcut(_ key: KeyEquivalent, action: @escaping () -> Void) -> some View {
        Button(action: action) { Color.clear }
            .keyboardShortcut(key, modifiers: [])
    }

    private var secondaryText: Color {
        LauncherTheme.Palette.secondaryText(for: colorScheme)
    }
}
