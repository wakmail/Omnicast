// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import SwiftUI

public struct ImportView: View {
    @StateObject private var model: RaycastImportViewModel
    @State private var isDropTargeted = false

    @MainActor
    public init(viewModel: RaycastImportViewModel) {
        _model = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Import from Raycast")
                    .font(.title2.bold())
                if let result = model.result {
                    resultSummary(result)
                } else if let failure = model.importFailureMessage {
                    failureSummary(failure)
                } else {
                    importForm
                }
            }
            .padding(24)
            .frame(maxWidth: 620, alignment: .leading)
        }
    }

    private var importForm: some View {
        Group {
            filePicker
            SecureField("Backup Password", text: $model.password)
                .textFieldStyle(.roundedBorder)
            categoryPicker
            importButton
            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
    }

    private var filePicker: some View {
        Button(action: model.chooseFile) {
            VStack(spacing: 8) {
                Image(systemName: model.fileURL == nil ? "square.and.arrow.down" : "doc.fill")
                    .font(.title2)
                if let fileURL = model.fileURL {
                    Text(fileURL.lastPathComponent)
                        .font(.headline)
                        .lineLimit(1)
                    Text("Drop another backup or click to choose")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Drag your .rayconfig here")
                        .font(.headline)
                    Text("or click to choose from Downloads")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 116)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            isDropTargeted ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.45),
                    style: StrokeStyle(lineWidth: isDropTargeted ? 2 : 1, dash: [6])
                )
        }
        .onDrop(
            of: RayconfigDropReceiver.typeIdentifiers,
            isTargeted: $isDropTargeted,
            perform: model.acceptDrop
        )
        .accessibilityLabel(model.fileURL == nil ? "Choose Raycast backup" : "Change Raycast backup")
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Categories")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading) {
                ForEach(RaycastImportCategory.allCases) { category in
                    Toggle(
                        category.title,
                        isOn: Binding(
                            get: { model.selectedCategories.contains(category) },
                            set: { model.setSelected(category, selected: $0) }
                        )
                    )
                }
            }
        }
    }

    private var importButton: some View {
        Button(action: model.runImport) {
            if model.isImporting {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text("Run Import")
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(!model.canRunImport)
    }

    private func resultSummary(_ result: RaycastImportResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Import Complete")
                .font(.headline)
            if let version = result.raycastVersion {
                Text("Raycast version \(version)")
                    .foregroundStyle(.secondary)
            }
            ForEach(RaycastImportCategory.allCases) { category in
                if let summary = result.categories[category] {
                    HStack {
                        Text(category.title)
                        Spacer()
                        Text("\(summary.imported) imported, \(summary.skipped) skipped, \(summary.failed) failed")
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
            }
            if !result.extensionsToInstall.isEmpty {
                Text("Extensions ready to install")
                    .font(.headline)
                    .padding(.top, 4)
                Text(result.extensionsToInstall.joined(separator: ", "))
                    .foregroundStyle(.secondary)
            }
            if !result.skippedItems.isEmpty {
                DisclosureGroup("Skipped Item Details") {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(result.skippedItems) { issue in
                            Text("\(issue.item): \(issue.reason)")
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    private func failureSummary(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Import Failed", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.red)
            Text(message)
                .foregroundStyle(.secondary)
            Button("Try Again", action: model.prepareToRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding(14)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}
