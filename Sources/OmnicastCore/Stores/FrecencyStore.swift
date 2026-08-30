// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct InputHistoryEntry: Codable, Equatable, Sendable {
    public var useCount: Int
    public var lastUsedAt: Date
    public var score: Double

    public init(useCount: Int, lastUsedAt: Date, score: Double) {
        self.useCount = useCount
        self.lastUsedAt = lastUsedAt
        self.score = score
    }
}

public struct FrecencyEntry: Codable, Equatable, Sendable {
    public var useCount: Int
    public var lastUsedAt: Date
    public var score: Double
    public var inputHistory: [String: InputHistoryEntry]

    public init(
        useCount: Int,
        lastUsedAt: Date,
        score: Double,
        inputHistory: [String: InputHistoryEntry] = [:]
    ) {
        self.useCount = useCount
        self.lastUsedAt = lastUsedAt
        self.score = score
        self.inputHistory = inputHistory
    }
}

public final class FrecencyStore {
    public private(set) var entries: [String: FrecencyEntry]
    public let fileURL: URL

    private static let day: TimeInterval = 86_400

    public init(directoryURL: URL = OmnicastDataDirectory.defaultURL) throws {
        fileURL = directoryURL.appendingPathComponent("frecency.json")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            entries = try JSONDecoder().decode([String: FrecencyEntry].self, from: data)
        } else {
            entries = [:]
        }
    }

    public func recordLaunch(
        commandID: String,
        query: String,
        at date: Date = Date()
    ) throws {
        guard !commandID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        var entry = entries[commandID] ?? FrecencyEntry(
            useCount: 0,
            lastUsedAt: date,
            score: 0
        )
        let ageDays = max(0, date.timeIntervalSince(entry.lastUsedAt) / Self.day)
        entry.score = max(0, entry.score) * pow(0.5, ageDays / 30) + 1
        entry.useCount += 1
        entry.lastUsedAt = date

        let inputKey = SearchRanker.normalize(query).prefix(120)
        if !inputKey.isEmpty {
            let key = String(inputKey)
            var input = entry.inputHistory[key] ?? InputHistoryEntry(
                useCount: 0,
                lastUsedAt: date,
                score: 0
            )
            let inputAge = max(0, date.timeIntervalSince(input.lastUsedAt) / Self.day)
            input.score = max(0, input.score) * pow(0.5, inputAge / 14) + 1
            input.useCount += 1
            input.lastUsedAt = date
            entry.inputHistory[key] = input
        }

        entries[commandID] = entry
        try save()
    }

    public func orderedCommandIDs(at date: Date = Date()) -> [String] {
        entries.sorted { left, right in
            let leftAge = max(0, date.timeIntervalSince(left.value.lastUsedAt) / Self.day)
            let rightAge = max(0, date.timeIntervalSince(right.value.lastUsedAt) / Self.day)
            let leftScore = left.value.score * pow(0.5, leftAge / 30)
            let rightScore = right.value.score * pow(0.5, rightAge / 30)
            if abs(leftScore - rightScore) >= 0.0001 {
                return leftScore > rightScore
            }
            return left.key < right.key
        }.map(\.key)
    }

    private func save() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(entries).write(to: fileURL, options: .atomic)
    }
}
