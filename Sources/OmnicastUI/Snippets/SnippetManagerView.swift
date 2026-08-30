// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import SwiftUI

public struct SnippetManagerView: View {
    @StateObject private var model: SnippetManagerViewModel

    @MainActor
    public init(store: SnippetStore) {
        _model = StateObject(wrappedValue: SnippetManagerViewModel(store: store))
    }

    public var body: some View {
        HSplitView {
            snippetList
                .frame(minWidth: 230, idealWidth: 280)
            editor
                .frame(minWidth: 360, idealWidth: 480)
        }
        .frame(minWidth: 680, minHeight: 440)
    }

    private var snippetList: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search snippets", text: $model.query)
                    .textFieldStyle(.roundedBorder)
                Button(action: model.createNew) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Create snippet")
            }
            .padding(12)

            Divider()

            if model.visibleSnippets.isEmpty {
                ContentUnavailableView(
                    "No Snippets",
                    systemImage: "text.quote",
                    description: Text("Create a snippet to reuse text anywhere")
                )
            } else {
                List(model.visibleSnippets) { snippet in
                    Button {
                        model.select(snippet.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(snippet.name)
                                .font(.headline)
                                .lineLimit(1)
                            Text(snippet.keyword ?? snippet.content)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 3)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        snippet.id == model.selectedID
                            ? Color.accentColor.opacity(0.16)
                            : Color.clear
                    )
                }
                .listStyle(.sidebar)
            }
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(model.isCreating ? "Create Snippet" : "Edit Snippet")
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Snippet name", text: $model.name)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Keyword")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Optional keyword", text: $model.keyword)
                Text("Typing the complete keyword expands it immediately")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Content")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $model.content)
                    .font(.body.monospaced())
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 7))
                    .frame(minHeight: 180)
                Text("Use {clipboard}, {selection}, {date}, {time}, {uuid}, and {cursor}")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()

            HStack {
                if model.selectedID != nil, !model.isCreating {
                    Button("Delete", role: .destructive, action: model.deleteSelected)
                }
                Spacer()
                Button("Save", action: model.save)
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
    }
}
