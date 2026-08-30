// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation

@MainActor
public final class NotesStore: ObservableObject {
    @Published public private(set) var notes: [Note]
    @Published public private(set) var autosaveError: String?

    public let directoryURL: URL
    public let indexFileURL: URL
    public let notesDirectoryURL: URL

    private let fileManager: FileManager
    private var autosaveTasks: [UUID: Task<Void, Never>] = [:]
    private var pendingBodies: [UUID: String] = [:]

    public init(
        directoryURL: URL = OmnicastDataDirectory.defaultURL,
        fileManager: FileManager = .default
    ) throws {
        self.directoryURL = directoryURL.appendingPathComponent("Notes", isDirectory: true)
        indexFileURL = self.directoryURL.appendingPathComponent("index.json")
        notesDirectoryURL = self.directoryURL.appendingPathComponent("Documents", isDirectory: true)
        self.fileManager = fileManager
        notes = []
        autosaveError = nil

        guard fileManager.fileExists(atPath: indexFileURL.path) else { return }
        let data = try Data(contentsOf: indexFileURL)
        let entries = try JSONDecoder.notesDecoder.decode([NoteIndexEntry].self, from: data)
        notes = try entries.compactMap { entry in
            let fileURL = noteFileURL(id: entry.id)
            guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
            return Note(
                id: entry.id,
                body: try String(contentsOf: fileURL, encoding: .utf8),
                created: entry.created,
                updated: entry.updated,
                pinned: entry.pinned
            )
        }
        sortNotes()
    }

    @discardableResult
    public func create(
        body: String = "",
        pinned: Bool = false,
        at date: Date = Date()
    ) throws -> Note {
        let note = Note(body: body, created: date, pinned: pinned)
        try prepareDirectories()
        try body.write(to: noteFileURL(id: note.id), atomically: true, encoding: .utf8)
        notes.append(note)
        sortNotes()
        do {
            try saveIndex()
        } catch {
            notes.removeAll { $0.id == note.id }
            try? fileManager.removeItem(at: noteFileURL(id: note.id))
            throw error
        }
        return note
    }

    @discardableResult
    public func update(
        id: UUID,
        body: String,
        at date: Date = Date()
    ) throws -> Note? {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return nil }
        try prepareDirectories()
        try body.write(to: noteFileURL(id: id), atomically: true, encoding: .utf8)
        notes[index].body = body
        notes[index].updated = date
        let updated = notes[index]
        sortNotes()
        try saveIndex()
        return updated
    }

    @discardableResult
    public func togglePin(id: UUID, at date: Date = Date()) throws -> Note? {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return nil }
        notes[index].pinned.toggle()
        notes[index].updated = date
        let changedID = notes[index].id
        sortNotes()
        try saveIndex()
        return notes.first { $0.id == changedID }
    }

    @discardableResult
    public func delete(id: UUID) throws -> Bool {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return false }
        autosaveTasks[id]?.cancel()
        autosaveTasks[id] = nil
        pendingBodies[id] = nil
        notes.remove(at: index)
        let fileURL = noteFileURL(id: id)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        try saveIndex()
        return true
    }

    public func note(id: UUID) -> Note? {
        notes.first { $0.id == id }
    }

    public func search(_ query: String) -> [Note] {
        let tokens = query
            .split(whereSeparator: { $0.isWhitespace })
            .map { String($0).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) }
        guard !tokens.isEmpty else { return notes }
        return notes.filter { note in
            let text = "\(note.title)\n\(note.body)"
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return tokens.allSatisfy(text.contains)
        }
    }

    public func scheduleAutosave(
        id: UUID,
        body: String,
        delay: Duration = .milliseconds(450)
    ) {
        guard note(id: id) != nil else { return }
        pendingBodies[id] = body
        autosaveTasks[id]?.cancel()
        autosaveTasks[id] = Task { [weak self] in
            do {
                try await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
                try self?.savePendingBody(id: id)
                self?.autosaveError = nil
            } catch is CancellationError {
                return
            } catch {
                self?.autosaveError = error.localizedDescription
            }
        }
    }

    public func flushAutosave(id: UUID, at date: Date = Date()) throws {
        autosaveTasks[id]?.cancel()
        autosaveTasks[id] = nil
        try savePendingBody(id: id, at: date)
        autosaveError = nil
    }

    public func flushAllAutosaves(at date: Date = Date()) throws {
        for id in Array(pendingBodies.keys) {
            try flushAutosave(id: id, at: date)
        }
    }

    public func noteFileURL(id: UUID) -> URL {
        notesDirectoryURL.appendingPathComponent("\(id.uuidString).md")
    }

    private func savePendingBody(id: UUID, at date: Date = Date()) throws {
        guard let body = pendingBodies[id] else { return }
        _ = try update(id: id, body: body, at: date)
        pendingBodies[id] = nil
        autosaveTasks[id] = nil
    }

    private func prepareDirectories() throws {
        try fileManager.createDirectory(at: notesDirectoryURL, withIntermediateDirectories: true)
    }

    private func saveIndex() throws {
        try prepareDirectories()
        let entries = notes.map(NoteIndexEntry.init)
        try JSONEncoder.notesEncoder.encode(entries).write(to: indexFileURL, options: .atomic)
    }

    private func sortNotes() {
        notes.sort { left, right in
            if left.pinned != right.pinned { return left.pinned }
            if left.updated != right.updated { return left.updated > right.updated }
            return left.id.uuidString < right.id.uuidString
        }
    }
}

private struct NoteIndexEntry: Codable {
    let id: UUID
    let created: Date
    let updated: Date
    let pinned: Bool

    init(note: Note) {
        id = note.id
        created = note.created
        updated = note.updated
        pinned = note.pinned
    }
}

private extension JSONEncoder {
    static var notesEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var notesDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
