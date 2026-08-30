// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import OmnicastCore
import SwiftUI

@MainActor
public final class FileSearchViewModel: ObservableObject {
    @Published public private(set) var results: [FileSearchResult] = []
    @Published public private(set) var selectedIndex = 0
    @Published public private(set) var isSearching = false

    private let index: FileSearchIndex
    private let context: CommandContext
    private let onOpen: () -> Void
    private var subscriptions = Set<AnyCancellable>()

    public init(
        index: FileSearchIndex,
        context: CommandContext,
        onOpen: @escaping () -> Void = {}
    ) {
        self.index = index
        self.context = context
        self.onOpen = onOpen
        index.$results
            .sink { [weak self] results in
                self?.results = results
                self?.selectedIndex = min(
                    self?.selectedIndex ?? 0,
                    max(0, results.count - 1)
                )
            }
            .store(in: &subscriptions)
        index.$isSearching
            .assign(to: &$isSearching)
    }

    public var selectedResult: FileSearchResult? {
        guard results.indices.contains(selectedIndex) else { return nil }
        return results[selectedIndex]
    }

    public func updateQuery(_ query: String) {
        index.updateQuery(query)
    }

    public func select(_ index: Int) {
        guard results.indices.contains(index) else { return }
        selectedIndex = index
    }

    public func handle(_ key: LauncherKey) -> Bool {
        switch key {
        case .moveUp:
            selectedIndex = max(0, selectedIndex - 1)
            return true
        case .moveDown:
            selectedIndex = min(max(0, results.count - 1), selectedIndex + 1)
            return true
        case .enter, .commandEnter:
            openSelected()
            return true
        default:
            return false
        }
    }

    public func openSelected() {
        guard let selectedResult else { return }
        onOpen()
        Task {
            do {
                try await context.opener.open(selectedResult.url)
            } catch {
                context.toasts.show(error.localizedDescription)
            }
        }
    }
}

public struct FileSearchView: View {
    @ObservedObject private var model: FileSearchViewModel
    @Environment(\.colorScheme) private var colorScheme

    public init(model: FileSearchViewModel) {
        self.model = model
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if model.isSearching, model.results.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, LauncherTheme.Metrics.sectionTopPadding * 4)
                    } else if model.results.isEmpty {
                        Text("Type to search files and folders")
                            .font(LauncherTheme.Typography.emptyState)
                            .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
                            .frame(maxWidth: .infinity)
                            .padding(.top, LauncherTheme.Metrics.sectionTopPadding * 4)
                    } else {
                        ForEach(Array(model.results.enumerated()), id: \.element.id) { index, result in
                            Button {
                                model.select(index)
                                model.openSelected()
                            } label: {
                                HStack(spacing: LauncherTheme.Metrics.rowIconTitleSpacing) {
                                    Image(systemName: symbol(for: result.kind))
                                        .frame(
                                            width: LauncherTheme.Metrics.rowIconSize,
                                            height: LauncherTheme.Metrics.rowIconSize
                                        )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.displayName)
                                            .font(LauncherTheme.Typography.rowTitle)
                                            .foregroundStyle(
                                                LauncherTheme.Palette.primaryText(for: colorScheme)
                                            )
                                        Text(result.url.deletingLastPathComponent().path)
                                            .font(LauncherTheme.Typography.rowSubtitle)
                                            .foregroundStyle(
                                                LauncherTheme.Palette.secondaryText(for: colorScheme)
                                            )
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, LauncherTheme.Metrics.rowContentPadding)
                                .frame(height: LauncherTheme.Metrics.rowHeight)
                                .background(
                                    index == model.selectedIndex
                                        ? LauncherTheme.Palette.selectedRow(for: colorScheme)
                                        : Color.clear,
                                    in: RoundedRectangle(
                                        cornerRadius: LauncherTheme.Metrics.rowCornerRadius
                                    )
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, LauncherTheme.Metrics.rowOuterInset)
                            .id(result.id)
                            .onHover { hovering in
                                if hovering { model.select(index) }
                            }
                        }
                    }
                }
                .padding(.top, LauncherTheme.Metrics.sectionTopPadding)
            }
            .scrollIndicators(.hidden)
            .onChange(of: model.selectedIndex) {
                if let result = model.selectedResult {
                    proxy.scrollTo(result.id, anchor: .center)
                }
            }
        }
    }

    private func symbol(for kind: FileSearchResult.Kind) -> String {
        switch kind {
        case .file: "doc"
        case .directory: "folder"
        case .application: "app"
        case .other: "questionmark.square"
        }
    }
}
