// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import SwiftUI

public struct ColorHistoryView: View {
    @StateObject private var model: ColorHistoryViewModel
    @Environment(\.colorScheme) private var colorScheme

    @MainActor
    public init(model: ColorHistoryViewModel) {
        _model = StateObject(wrappedValue: model)
    }

    public var body: some View {
        VStack(spacing: 0) {
            if model.items.isEmpty {
                Text("No colors sampled yet")
                    .font(LauncherTheme.Typography.emptyState)
                    .foregroundStyle(secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                                Button {
                                    model.select(index)
                                } label: {
                                    HStack(spacing: 12) {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color(hex: item.hex) ?? .clear)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color.primary.opacity(0.15))
                                            )
                                            .frame(width: 34, height: 34)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.hex)
                                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                            Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                                                .font(.system(size: 11))
                                                .foregroundStyle(secondaryText)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 10)
                                    .frame(height: 48)
                                    .background(
                                        index == model.selectedIndex
                                            ? Color.accentColor.opacity(0.18)
                                            : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                                }
                                .buttonStyle(.plain)
                                .id(item.id)
                            }
                        }
                        .padding(8)
                    }
                    .onChange(of: model.selectedIndex) {
                        if let selected = model.selectedItem {
                            proxy.scrollTo(selected.id, anchor: .center)
                        }
                    }
                }
            }

            LauncherTheme.Palette.borderPrimary(for: colorScheme)
                .frame(height: 1)
            HStack {
                Text("\(model.items.count) colors")
                Spacer()
                Text("Enter copies")
            }
            .font(LauncherTheme.Typography.footerTitle)
            .foregroundStyle(secondaryText)
            .padding(.horizontal, LauncherTheme.Metrics.footerHorizontalPadding)
            .frame(height: LauncherTheme.Metrics.footerHeight)
        }
        .background(LauncherTheme.Palette.surface(for: colorScheme))
    }

    private var secondaryText: Color {
        LauncherTheme.Palette.secondaryText(for: colorScheme)
    }
}

private extension Color {
    init?(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6, let rgb = UInt64(value, radix: 16) else { return nil }
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
