// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import SwiftUI

public struct QuicklinkManagerView: View {
    @StateObject private var viewModel: QuicklinkManagerViewModel

    public init(store: QuicklinkStore) {
        _viewModel = StateObject(
            wrappedValue: QuicklinkManagerViewModel(store: store)
        )
    }

    public var body: some View {
        NavigationSplitView {
            List(selection: $viewModel.selectedID) {
                ForEach(viewModel.quicklinks) { quicklink in
                    Button {
                        viewModel.beginEditing(quicklink)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: symbolName(for: quicklink.icon))
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(quicklink.name)
                                Text(quicklink.urlTemplate)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .tag(quicklink.id)
                }
            }
            .navigationTitle("Quick Links")
            .toolbar {
                Button {
                    viewModel.beginCreate()
                } label: {
                    Label("Create Quick Link", systemImage: "plus")
                }

                Button(role: .destructive) {
                    viewModel.deleteSelected()
                } label: {
                    Label("Delete Quick Link", systemImage: "trash")
                }
                .disabled(viewModel.selectedID == nil)
            }
        } detail: {
            if viewModel.isEditing {
                editor
            } else {
                ContentUnavailableView(
                    "Quick Links",
                    systemImage: "link",
                    description: Text("Select a quick link or create one.")
                )
            }
        }
        .frame(minWidth: 720, minHeight: 440)
    }

    private var editor: some View {
        Form {
            TextField("Name", text: $viewModel.name)
            TextField("URL template", text: $viewModel.urlTemplate)
            TextField("Application bundle identifier", text: $viewModel.bundleIdentifier)
            TextField("Icon", text: $viewModel.icon)

            Text("Use {query} where the search text belongs in the URL.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    viewModel.cancelEditing()
                }
                Button("Save") {
                    viewModel.save()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(viewModel.name.isEmpty ? "Quick Link" : viewModel.name)
    }

    private func symbolName(for icon: String) -> String {
        switch icon.lowercased() {
        case "search": return "magnifyingglass"
        case "globe": return "globe"
        case "bolt": return "bolt"
        default: return "link"
        }
    }
}
