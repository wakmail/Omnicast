// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct SnippetPlaceholderContext: Sendable {
    public var clipboard: String
    public var selection: String
    public var date: Date
    public var locale: Locale
    public var timeZone: TimeZone
    public var uuid: UUID

    public init(
        clipboard: String = "",
        selection: String = "",
        date: Date,
        locale: Locale = .current,
        timeZone: TimeZone = .current,
        uuid: UUID
    ) {
        self.clipboard = clipboard
        self.selection = selection
        self.date = date
        self.locale = locale
        self.timeZone = timeZone
        self.uuid = uuid
    }
}

public struct RenderedSnippet: Equatable, Sendable {
    public let text: String
    public let cursorOffsetFromEnd: Int?

    public init(text: String, cursorOffsetFromEnd: Int?) {
        self.text = text
        self.cursorOffsetFromEnd = cursorOffsetFromEnd
    }
}

public enum SnippetPlaceholderRenderer {
    public static func render(
        _ template: String,
        context: SnippetPlaceholderContext
    ) -> RenderedSnippet {
        let marker = "\u{0}OMNICAST_CURSOR\u{0}"
        let expression = try? NSRegularExpression(pattern: #"\{([^}]+)\}"#)
        let source = template as NSString
        let matches = expression?.matches(
            in: template,
            range: NSRange(location: 0, length: source.length)
        ) ?? []
        var result = template

        for match in matches.reversed() {
            let fullRange = match.range(at: 0)
            let token = source.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
            guard let replacement = replacement(
                for: token,
                marker: marker,
                context: context
            ) else { continue }
            result = (result as NSString).replacingCharacters(in: fullRange, with: replacement)
        }

        guard let firstMarker = result.range(of: marker) else {
            return RenderedSnippet(text: result, cursorOffsetFromEnd: nil)
        }
        let prefixCount = result[..<firstMarker.lowerBound].count
        let text = result.replacingOccurrences(of: marker, with: "")
        return RenderedSnippet(
            text: text,
            cursorOffsetFromEnd: text.count - prefixCount
        )
    }

    private static func replacement(
        for token: String,
        marker: String,
        context: SnippetPlaceholderContext
    ) -> String? {
        switch token {
        case "clipboard":
            return context.clipboard
        case "selection":
            return context.selection
        case "cursor", "cursor-position":
            return marker
        case "date":
            return styledDate(context, dateStyle: .short, timeStyle: .none)
        case "time":
            return styledDate(context, dateStyle: .none, timeStyle: .medium)
        case "uuid", "random:UUID":
            return context.uuid.uuidString
        default:
            if token.hasPrefix("date:") {
                return customDate(String(token.dropFirst(5)), context: context)
            }
            if token.hasPrefix("time:") {
                return customDate(String(token.dropFirst(5)), context: context)
            }
            return nil
        }
    }

    private static func styledDate(
        _ context: SnippetPlaceholderContext,
        dateStyle: DateFormatter.Style,
        timeStyle: DateFormatter.Style
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = context.locale
        formatter.timeZone = context.timeZone
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter.string(from: context.date)
    }

    private static func customDate(
        _ format: String,
        context: SnippetPlaceholderContext
    ) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(
            in: context.timeZone,
            from: context.date
        )
        let values = [
            "YYYY": String(format: "%04d", components.year ?? 0),
            "MM": String(format: "%02d", components.month ?? 0),
            "DD": String(format: "%02d", components.day ?? 0),
            "HH": String(format: "%02d", components.hour ?? 0),
            "mm": String(format: "%02d", components.minute ?? 0),
            "ss": String(format: "%02d", components.second ?? 0)
        ]
        var rendered = format
        for token in ["YYYY", "MM", "DD", "HH", "mm", "ss"] {
            rendered = rendered.replacingOccurrences(of: token, with: values[token] ?? "")
        }
        return rendered
    }
}
