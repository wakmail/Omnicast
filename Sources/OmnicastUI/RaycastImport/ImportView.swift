// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import SwiftUI

public struct ImportView: View {
    @StateObject private var model: RaycastImportViewModel

    @MainActor
    public init(viewModel: RaycastImportViewModel) {
        _model = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Import from Raycast")
                    .font(.title2.bold())
                filePicker
                SecureField("Backup Password", text: $model.password)
                    .textFieldStyle(.roundedBorder)
                categoryPicker
                importButton
                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
                if let result = model.result {
                    resultSummary(result)
                }
            }
            .padding(24)
            .frame(maxWidth: 620, alignment: .leading)
        }
    }

    private var filePicker: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Backup File")
                    .font(.headline)
                Text(model.fileURL?.path ?? "No file chosen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button("Choose File", action: model.chooseFile)
        }
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
        .disabled(model.fileURL == nil || model.selectedCategories.isEmpty || model.isImporting)
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
}
