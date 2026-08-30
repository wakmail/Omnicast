// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct Note: Equatable, Identifiable, Sendable {
    public let id: UUID
    public var body: String
    public let created: Date
    public var updated: Date
    public var pinned: Bool

    public init(
        id: UUID = UUID(),
        body: String = "",
        created: Date = Date(),
        updated: Date? = nil,
        pinned: Bool = false
    ) {
        self.id = id
        self.body = body
        self.created = created
        self.updated = updated ?? created
        self.pinned = pinned
    }

    public var title: String {
        Self.title(from: body)
    }

    public static func title(from body: String) -> String {
        let firstLine = body.split(separator: "\n", omittingEmptySubsequences: false).first ?? ""
        var title = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        while title.first == "#" {
            title.removeFirst()
        }
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Untitled Note" : title
    }
}
