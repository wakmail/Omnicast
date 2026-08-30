// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import SwiftUI

public struct NotesManagerView: View {
    @StateObject private var model: NotesManagerViewModel
    @Environment(\.colorScheme) private var colorScheme

    @MainActor
    public init(viewModel: NotesManagerViewModel) {
        _model = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            divider
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    noteList
                        .frame(width: max(210, proxy.size.width * 0.34))
                    verticalDivider
                    editor
                }
            }
            divider
            footer
        }
        .background(LauncherTheme.Palette.surface(for: colorScheme))
        .onDisappear { model.flushCurrentNote() }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(secondaryText)
            TextField("Search notes", text: $model.query)
                .textFieldStyle(.plain)
                .font(LauncherTheme.Typography.search)
            Button {
                model.createNote()
            } label: {
                Label("New Note", systemImage: "square.and.pencil")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, LauncherTheme.Metrics.searchHorizontalPadding)
        .frame(height: LauncherTheme.Metrics.searchHeight)
    }

    private var noteList: some View {
        ScrollView {
            LazyVStack(spacing: 3) {
                if model.visibleNotes.isEmpty {
                    Text("No notes found")
                        .font(LauncherTheme.Typography.emptyState)
                        .foregroundStyle(secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 28)
                } else {
                    ForEach(model.visibleNotes) { note in
                        Button {
                            model.select(note.id)
                        } label: {
                            NoteRow(
                                note: note,
                                selected: note.id == model.selectedNoteID,
                                colorScheme: colorScheme
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(7)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var editor: some View {
        if let note = model.selectedNote {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text(note.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(primaryText)
                        .lineLimit(1)
                    Spacer()
                    Toggle("Monospaced", isOn: $model.usesMonospacedFont)
                        .toggleStyle(.checkbox)
                    Button {
                        model.togglePinSelectedNote()
                    } label: {
                        Label(note.pinned ? "Unpin" : "Pin", systemImage: note.pinned ? "pin.slash" : "pin")
                    }
                    .buttonStyle(.borderless)
                    Button(role: .destructive) {
                        model.deleteSelectedNote()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal, 14)
                .frame(height: 44)

                divider

                TextEditor(text: $model.draft)
                    .font(.system(
                        size: 14,
                        design: model.usesMonospacedFont ? .monospaced : .default
                    ))
                    .foregroundStyle(primaryText)
                    .scrollContentBackground(.hidden)
                    .padding(10)
            }
        } else {
            VStack(spacing: 10) {
                Image(systemName: "note.text")
                    .font(.system(size: 26))
                Text("Create a note to begin")
            }
            .foregroundStyle(secondaryText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var footer: some View {
        HStack {
            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(Color.red)
                    .lineLimit(1)
            } else if let note = model.selectedNote {
                Text("Updated \(note.updated.formatted(date: .abbreviated, time: .shortened))")
                    .foregroundStyle(secondaryText)
            } else {
                Text("\(model.visibleNotes.count) notes")
                    .foregroundStyle(secondaryText)
            }
            Spacer()
            Text("Markdown")
                .foregroundStyle(secondaryText)
        }
        .font(LauncherTheme.Typography.footerTitle)
        .padding(.horizontal, LauncherTheme.Metrics.footerHorizontalPadding)
        .frame(height: LauncherTheme.Metrics.footerHeight)
    }

    private var divider: some View {
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

private struct NoteRow: View {
    let note: Note
    let selected: Bool
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: note.pinned ? "pin.fill" : "note.text")
                .font(.system(size: 14))
                .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(note.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(note.body.replacingOccurrences(of: "\n", with: " "))
                    .font(.system(size: 11))
                    .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))
                    .lineLimit(1)
            }
            .foregroundStyle(LauncherTheme.Palette.primaryText(for: colorScheme))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 9)
        .frame(minHeight: 50)
        .background(
            selected ? LauncherTheme.Palette.selectedRow(for: colorScheme) : Color.clear,
            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
        )
        .contentShape(Rectangle())
    }
}
