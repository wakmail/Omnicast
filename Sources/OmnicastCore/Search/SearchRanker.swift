// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct RankedCommand {
    public let command: any Command
    public let score: Double

    public init(command: any Command, score: Double) {
        self.command = command
        self.score = score
    }
}

public enum SearchRanker {
    private static let day: TimeInterval = 86_400

    public static func rank(
        _ commands: [any Command],
        query: String,
        frecency: [String: FrecencyEntry] = [:],
        now: Date = Date()
    ) -> [RankedCommand] {
        let normalizedQuery = normalize(query)

        return commands.compactMap { command in
            let matchScore: Double
            if normalizedQuery.isEmpty {
                matchScore = 0
            } else {
                guard let score = score(command: command, query: normalizedQuery) else {
                    return nil
                }
                matchScore = score
            }

            let kindBoost = command.kind == .application ? 155.0 : 75.0
            let learnedBoost = frecencyBoost(
                for: command.id,
                query: normalizedQuery,
                entries: frecency,
                now: now
            )
            return RankedCommand(
                command: command,
                score: matchScore + kindBoost + learnedBoost
            )
        }
        .sorted { left, right in
            if abs(left.score - right.score) >= 0.001 {
                return left.score > right.score
            }
            if left.command.title.count != right.command.title.count {
                return left.command.title.count < right.command.title.count
            }
            return left.command.title.localizedStandardCompare(right.command.title) == .orderedAscending
        }
    }

    public static func normalize(_ value: String) -> String {
        let folded = value.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        let scalars = folded.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(String(scalar)) : " "
        }
        return String(scalars)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private static func score(command: any Command, query: String) -> Double? {
        let terms = query.split(separator: " ").map(String.init)
        let fields: [(String, Double, Bool)] = [
            (command.title, 1.0, false),
            (command.subtitle, 0.72, true)
        ] + command.keywords.map { ($0, 0.70, true) }

        var total = 0.0
        for term in terms {
            let best = fields.compactMap { value, weight, isSecondary in
                score(term: term, fullQuery: query, value: value, weight: weight, isSecondary: isSecondary)
            }.max() ?? 0
            guard best > 0 else { return nil }
            total += best
        }
        return total / Double(max(terms.count, 1))
    }

    private static func score(
        term: String,
        fullQuery: String,
        value: String,
        weight: Double,
        isSecondary: Bool
    ) -> Double? {
        let normalized = normalize(value)
        guard !normalized.isEmpty else { return nil }
        let compactValue = normalized.replacingOccurrences(of: " ", with: "")
        let compactTerm = term.replacingOccurrences(of: " ", with: "")
        let tokens = normalized.split(separator: " ").map(String.init)
        let initials = tokens.compactMap(\.first).map(String.init).joined()

        let base: Double
        if normalized == fullQuery || normalized == term {
            base = 1000
        } else if normalized.hasPrefix(term) {
            base = 900
        } else if tokens.contains(where: { $0.hasPrefix(term) }) {
            base = 780
        } else if compactValue.hasPrefix(compactTerm) {
            base = 740
        } else if compactTerm.count >= 2, initials.hasPrefix(compactTerm) {
            let compactness = max(0, 1 - Double(max(0, compactValue.count - compactTerm.count)) / 24)
            base = 620 + (compactness * 110).rounded()
        } else if term.count >= 2, normalized.contains(term) {
            base = 560
        } else if compactTerm.count >= 2, isSubsequence(compactTerm, of: compactValue) {
            let density = Double(compactTerm.count) / Double(max(compactValue.count, compactTerm.count))
            base = 380 + min(140, density * 170).rounded()
        } else {
            return nil
        }

        var adjusted = base
        if isSecondary, base < 900 {
            adjusted = min(500, max(260, (base * 0.72).rounded()))
        }
        let compactnessBoost = base >= 900
            ? Double(max(0, 36 - max(0, compactValue.count - compactTerm.count) * 2))
            : 0
        return ((adjusted + compactnessBoost) * weight).rounded()
    }

    private static func isSubsequence(_ needle: String, of haystack: String) -> Bool {
        var needleIndex = needle.startIndex
        for character in haystack where needleIndex < needle.endIndex {
            if character == needle[needleIndex] {
                needle.formIndex(after: &needleIndex)
            }
        }
        return needleIndex == needle.endIndex
    }

    private static func frecencyBoost(
        for id: String,
        query: String,
        entries: [String: FrecencyEntry],
        now: Date
    ) -> Double {
        guard let entry = entries[id] else { return 0 }
        let ageDays = max(0, now.timeIntervalSince(entry.lastUsedAt) / day)
        let decayed = max(0, entry.score) * pow(0.5, ageDays / 30)
        let generalBoost = min(180, 70 * log1p(decayed))
        guard !query.isEmpty else { return generalBoost }

        let adaptiveBoost = entry.inputHistory.reduce(0.0) { current, pair in
            let input = pair.key
            guard input.hasPrefix(query) || query.hasPrefix(input) else { return current }
            let inputAge = max(0, now.timeIntervalSince(pair.value.lastUsedAt) / day)
            let inputScore = max(0, pair.value.score) * pow(0.5, inputAge / 14)
            return max(current, min(260, 95 * inputScore))
        }
        return generalBoost + adaptiveBoost
    }
}
