// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import OmnicastCore
import SwiftUI

public struct ClipboardHistoryView: View {
    @StateObject private var model: ClipboardHistoryViewModel
    private let showsChrome: Bool
    @Environment(\.colorScheme) private var colorScheme

    @MainActor
    public init(viewModel: ClipboardHistoryViewModel, showsChrome: Bool = true) {
        _model = StateObject(wrappedValue: viewModel)
        self.showsChrome = showsChrome
    }

    public var body: some View {
        ZStack {
            LauncherTheme.Palette.surface(for: colorScheme)

            VStack(spacing: 0) {
                if showsChrome {
                    searchField
                    horizontalDivider
                }
                GeometryReader { proxy in
                    HStack(spacing: 0) {
                        itemList
                            .frame(width: proxy.size.width * 0.4)
                        verticalDivider
                        preview
                    }
                }
                if showsChrome {
                    horizontalDivider
                    footer
                }
            }

            keyboardShortcuts
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(secondaryText)
            TextField("Search clipboard history", text: $model.query)
                .textFieldStyle(.plain)
                .font(LauncherTheme.Typography.search)
            if !model.query.isEmpty {
                Button {
                    model.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(secondaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, LauncherTheme.Metrics.searchHorizontalPadding)
        .frame(height: LauncherTheme.Metrics.searchHeight)
    }

    private var itemList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    if model.visibleItems.isEmpty {
                        Text("No clipboard items found")
                            .font(LauncherTheme.Typography.emptyState)
                            .foregroundStyle(secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 28)
                    } else {
                        ForEach(Array(model.visibleItems.enumerated()), id: \.element.id) { index, item in
                            Button {
                                model.select(index)
                            } label: {
                                ClipboardItemRow(
                                    item: item,
                                    index: index,
                                    isSelected: index == model.selectedIndex,
                                    colorScheme: colorScheme
                                )
                            }
                            .buttonStyle(.plain)
                            .id(item.id)
                        }
                    }
                }
                .padding(6)
            }
            .scrollIndicators(.hidden)
            .onChange(of: model.selectedIndex) {
                if let item = model.selectedItem {
                    proxy.scrollTo(item.id, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let item = model.selectedItem {
            VStack(spacing: 0) {
                Group {
                    switch item.kind {
                    case .text:
                        ScrollView {
                            Text(item.textContent ?? item.previewText)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(primaryText)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .padding(18)
                        }
                    case .image:
                        ClipboardStoredImageView(url: item.imageURL)
                            .padding(18)
                    case .files:
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(item.fileURLs, id: \.self) { url in
                                    Label(url.path, systemImage: "doc")
                                        .font(.system(size: 13))
                                        .foregroundStyle(primaryText)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(18)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                horizontalDivider
                metadata(for: item)
            }
        } else {
            Text("Select an item to preview")
                .font(LauncherTheme.Typography.emptyState)
                .foregroundStyle(secondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func metadata(for item: ClipboardItem) -> some View {
        VStack(spacing: 7) {
            metadataRow(label: "Copied", value: item.createdAt.formatted(date: .abbreviated, time: .shortened))
            if let source = item.sourceApplication?.name {
                metadataRow(label: "Source", value: source)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .foregroundStyle(secondaryText)
            Spacer()
            Text(value)
                .foregroundStyle(primaryText)
                .lineLimit(1)
        }
        .font(.system(size: 12))
    }

    private var footer: some View {
        HStack(spacing: 14) {
            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(Color.red)
                    .lineLimit(1)
            } else {
                Text("\(model.visibleItems.count) items")
                    .foregroundStyle(secondaryText)
            }
            Spacer()
            ClipboardFooterHint(label: "Paste", keys: ["Enter"])
            ClipboardFooterHint(label: "Copy", keys: ["⌘", "Enter"])
            ClipboardFooterHint(label: "Pin", keys: ["⌘", "P"])
            ClipboardFooterHint(label: "Delete", keys: ["⌘", "⌫"])
        }
        .font(LauncherTheme.Typography.footerTitle)
        .padding(.horizontal, LauncherTheme.Metrics.footerHorizontalPadding)
        .frame(height: LauncherTheme.Metrics.footerHeight)
    }

    private var keyboardShortcuts: some View {
        Group {
            shortcutButton(.pasteSelected, key: .return, modifiers: [])
            shortcutButton(.copySelected, key: .return, modifiers: .command)
            shortcutButton(.togglePinSelected, key: "p", modifiers: .command)
            shortcutButton(.deleteSelected, key: .delete, modifiers: .command)
            ForEach(0..<9, id: \.self) { index in
                shortcutButton(
                    .pasteVisibleItem(index),
                    key: KeyEquivalent(Character(String(index + 1))),
                    modifiers: .command
                )
            }
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    private func shortcutButton(
        _ action: ClipboardHistoryAction,
        key: KeyEquivalent,
        modifiers: EventModifiers
    ) -> some View {
        Button {
            model.handle(action)
        } label: {
            Color.clear
        }
        .keyboardShortcut(key, modifiers: modifiers)
    }

    private var horizontalDivider: some View {
        LauncherTheme.Palette.borderPrimary(for: colorScheme)
            .frame(height: 1)
    }

    private var verticalDivider: some View {
        LauncherTheme.Palette.borderPrimary(for: colorScheme)
            .frame(width: 1)
    }

    private var primaryText: Color {
        LauncherTheme.Palette.primaryText(for: colorScheme)
    }

    private var secondaryText: Color {
        LauncherTheme.Palette.secondaryText(for: colorScheme)
    }
}

private struct ClipboardItemRow: View {
    let item: ClipboardItem
    let index: Int
    let isSelected: Bool
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 9) {
            itemIcon
                .frame(width: 28, height: 28)
            Text(item.previewText)
                .font(.system(size: 13))
                .foregroundStyle(LauncherTheme.Palette.primaryText(for: colorScheme))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
            }
            if index < 9 {
                ClipboardKeyCap("⌘\(index + 1)", colorScheme: colorScheme)
            }
        }
        .padding(.horizontal, 9)
        .frame(minHeight: 46)
        .background(
            isSelected
                ? LauncherTheme.Palette.selectedRow(for: colorScheme)
                : Color.clear,
            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var itemIcon: some View {
        if item.kind == .image, let url = item.imageURL, let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            Image(systemName: symbolName)
                .font(.system(size: 15))
                .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
        }
    }

    private var symbolName: String {
        switch item.kind {
        case .text: "doc.text"
        case .image: "photo"
        case .files: "doc.on.doc"
        }
    }
}

private struct ClipboardStoredImageView: View {
    let url: URL?

    var body: some View {
        if let url, let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView("Image unavailable", systemImage: "photo.badge.exclamationmark")
        }
    }
}

private struct ClipboardFooterHint: View {
    let label: String
    let keys: [String]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 5) {
            Text(label)
                .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
            ForEach(keys, id: \.self) { key in
                ClipboardKeyCap(key, colorScheme: colorScheme)
            }
        }
    }
}

private struct ClipboardKeyCap: View {
    let value: String
    let colorScheme: ColorScheme

    init(_ value: String, colorScheme: ColorScheme) {
        self.value = value
        self.colorScheme = colorScheme
    }

    var body: some View {
        Text(value)
            .font(LauncherTheme.Typography.keyCap)
            .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
            .padding(.horizontal, 5)
            .frame(minWidth: 20, minHeight: 20)
            .background(
                LauncherTheme.Palette.keyCap(for: colorScheme),
                in: RoundedRectangle(cornerRadius: 4, style: .continuous)
            )
    }
}
