// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import SwiftUI

public struct MenuSearchView: View {
    @StateObject private var model: MenuSearchViewModel
    @Environment(\.colorScheme) private var colorScheme

    @MainActor
    public init(model: MenuSearchViewModel) {
        _model = StateObject(wrappedValue: model)
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let error = model.errorMessage {
                VStack(spacing: 10) {
                    Image(systemName: model.isAccessibilityGranted ? "exclamationmark.triangle" : "lock.shield")
                        .font(.system(size: 28))
                    Text(error)
                        .font(LauncherTheme.Typography.emptyState)
                    if !model.isAccessibilityGranted {
                        Text("Grant Accessibility access in System Settings, then reopen this search")
                            .font(.system(size: 12))
                            .foregroundStyle(secondaryText)
                    }
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.visibleItems.isEmpty {
                Text("No menu items found")
                    .font(LauncherTheme.Typography.emptyState)
                    .foregroundStyle(secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 3) {
                            ForEach(Array(model.visibleItems.enumerated()), id: \.element.id) { position, item in
                                Button {
                                    model.select(position)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "menubar.rectangle")
                                            .frame(width: 24)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.title)
                                                .font(.system(size: 13, weight: .medium))
                                            if !item.path.isEmpty {
                                                Text(item.path)
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(secondaryText)
                                            }
                                        }
                                        Spacer()
                                        if let shortcut = item.shortcut {
                                            Text(shortcut)
                                                .font(.system(size: 12, design: .rounded))
                                                .foregroundStyle(secondaryText)
                                        }
                                    }
                                    .foregroundStyle(item.isEnabled ? Color.primary : secondaryText)
                                    .padding(.horizontal, 10)
                                    .frame(height: 46)
                                    .background(
                                        position == model.selectedIndex
                                            ? Color.accentColor.opacity(0.18)
                                            : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                                    .opacity(item.isEnabled ? 1 : 0.6)
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
                Text(model.applicationName)
                Spacer()
                Text("Enter runs menu item")
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
