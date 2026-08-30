// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum ScriptCommandMode: String, Codable, CaseIterable, Sendable {
    case silent
    case compact
    case fullOutput
    case inline
}

public enum ScriptArgumentType: String, Codable, Sendable {
    case text
    case password
    case dropdown
}

public struct ScriptArgumentOption: Codable, Equatable, Sendable {
    public let title: String?
    public let value: String?

    public init(title: String? = nil, value: String? = nil) {
        self.title = title
        self.value = value
    }
}

public struct ScriptArgument: Codable, Equatable, Sendable {
    public let name: String
    public let index: Int
    public let type: ScriptArgumentType
    public let placeholder: String
    public let required: Bool
    public let percentEncoded: Bool
    public let options: [ScriptArgumentOption]

    public init(
        name: String,
        index: Int,
        type: ScriptArgumentType,
        placeholder: String,
        required: Bool,
        percentEncoded: Bool = false,
        options: [ScriptArgumentOption] = []
    ) {
        self.name = name
        self.index = index
        self.type = type
        self.placeholder = placeholder
        self.required = required
        self.percentEncoded = percentEncoded
        self.options = options
    }
}

public struct ScriptCommand: Equatable, Sendable {
    public let id: String
    public let title: String
    public let mode: ScriptCommandMode
    public let packageName: String
    public let icon: String?
    public let scriptURL: URL
    public let arguments: [ScriptArgument]
    public let needsConfirmation: Bool
    public let refreshTime: String?
    public let refreshInterval: TimeInterval?
    public let description: String?
    public let keywords: [String]

    public init(
        id: String,
        title: String,
        mode: ScriptCommandMode,
        packageName: String,
        icon: String?,
        scriptURL: URL,
        arguments: [ScriptArgument],
        needsConfirmation: Bool,
        refreshTime: String?,
        refreshInterval: TimeInterval?,
        description: String?,
        keywords: [String]
    ) {
        self.id = id
        self.title = title
        self.mode = mode
        self.packageName = packageName
        self.icon = icon
        self.scriptURL = scriptURL
        self.arguments = arguments
        self.needsConfirmation = needsConfirmation
        self.refreshTime = refreshTime
        self.refreshInterval = refreshInterval
        self.description = description
        self.keywords = keywords
    }
}

public enum ScriptCommandParser {
    public static func parse(contentsOf url: URL) throws -> ScriptCommand? {
        let source = try String(contentsOf: url, encoding: .utf8)
        return parse(source: source, scriptURL: url)
    }

    public static func parse(source: String, scriptURL: URL) -> ScriptCommand? {
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        var metadata: [String: String] = [:]
        var arguments: [Int: ScriptArgument] = [:]
        for line in source.components(separatedBy: .newlines).prefix(120) {
            guard let field = metadataField(from: line) else { continue }
            if field.key.hasPrefix("argument"),
               let index = Int(field.key.dropFirst("argument".count)),
               (1...3).contains(index),
               let argument = parseArgument(field.value, index: index) {
                arguments[index] = argument
            } else {
                metadata[field.key] = field.value
            }
        }

        guard metadata["schemaVersion"]?.trimmingCharacters(in: .whitespaces) == "1" else {
            return nil
        }
        guard let title = nonempty(metadata["title"]) else { return nil }
        guard let rawMode = metadata["mode"], let parsedMode = ScriptCommandMode(rawValue: rawMode) else {
            return nil
        }

        let refresh = normalizeRefreshTime(metadata["refreshTime"])
        let mode: ScriptCommandMode = parsedMode == .inline && refresh == nil ? .compact : parsedMode
        let scriptURL = scriptURL.standardizedFileURL
        let directoryName = scriptURL.deletingLastPathComponent().lastPathComponent
        let packageName = nonempty(metadata["packageName"]) ?? directoryName
        let description = nonempty(metadata["description"])
        let icon = nonempty(metadata["iconDark"]) ?? nonempty(metadata["icon"])
        let sortedArguments = arguments.values.sorted { $0.index < $1.index }
        let keywordSource = [
            title,
            description ?? "",
            packageName,
            scriptURL.deletingPathExtension().lastPathComponent,
            "script command"
        ]
        let keywords = uniqueKeywords(keywordSource)

        return ScriptCommand(
            id: stableIdentifier(for: scriptURL),
            title: title,
            mode: mode,
            packageName: packageName,
            icon: icon,
            scriptURL: scriptURL,
            arguments: sortedArguments,
            needsConfirmation: parseBoolean(metadata["needsConfirmation"]),
            refreshTime: refresh?.text,
            refreshInterval: mode == .inline ? refresh?.seconds : nil,
            description: description,
            keywords: keywords
        )
    }

    public static func normalizedRefreshTime(_ value: String?) -> String? {
        normalizeRefreshTime(value)?.text
    }

    private static func metadataField(from line: String) -> (key: String, value: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let body: Substring
        if trimmed.hasPrefix("//") {
            body = trimmed.dropFirst(2)
        } else if trimmed.hasPrefix("#") {
            body = trimmed.dropFirst()
        } else if trimmed.hasPrefix("--") {
            body = trimmed.dropFirst(2)
        } else {
            return nil
        }

        let content = body.drop(while: { $0.isWhitespace })
        guard content.hasPrefix("@raycast.") else { return nil }
        let field = content.dropFirst("@raycast.".count)
        let key = String(field.prefix(while: { !$0.isWhitespace }))
        guard !key.isEmpty, key.allSatisfy({ $0.isLetter || $0.isNumber }) else { return nil }
        let value = String(field.dropFirst(key.count)).trimmingCharacters(in: .whitespaces)
        return (key, value)
    }

    private static func parseArgument(_ raw: String, index: Int) -> ScriptArgument? {
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        let type = ScriptArgumentType(
            rawValue: string(object["type"])?.lowercased() ?? "text"
        ) ?? .text
        let placeholder = nonempty(string(object["placeholder"])) ?? "Argument \(index)"
        let required: Bool
        if object["required"] != nil {
            required = parseBoolean(object["required"])
        } else {
            required = !parseBoolean(object["optional"])
        }
        let options: [ScriptArgumentOption]
        if type == .dropdown, let values = object["data"] as? [[String: Any]] {
            options = values.compactMap { value in
                let title = nonempty(string(value["title"]))
                let optionValue = nonempty(string(value["value"]))
                guard title != nil || optionValue != nil else { return nil }
                return ScriptArgumentOption(title: title, value: optionValue)
            }
        } else {
            options = []
        }
        return ScriptArgument(
            name: "argument\(index)",
            index: index,
            type: type,
            placeholder: placeholder,
            required: required,
            percentEncoded: parseBoolean(object["percentEncoded"]),
            options: options
        )
    }

    private static func normalizeRefreshTime(_ input: String?) -> (text: String, seconds: TimeInterval)? {
        guard let value = nonempty(input), let unit = value.last?.lowercased() else { return nil }
        guard ["s", "m", "h", "d"].contains(unit),
              let amount = Int(value.dropLast().trimmingCharacters(in: .whitespaces)),
              amount > 0
        else {
            return nil
        }
        let normalizedAmount = unit == "s" ? max(10, amount) : amount
        let multiplier: TimeInterval
        switch unit {
        case "m": multiplier = 60
        case "h": multiplier = 3_600
        case "d": multiplier = 86_400
        default: multiplier = 1
        }
        return ("\(normalizedAmount)\(unit)", TimeInterval(normalizedAmount) * multiplier)
    }

    private static func stableIdentifier(for url: URL) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in url.path.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return "script-" + String(hash, radix: 16)
    }

    private static func parseBoolean(_ value: Any?) -> Bool {
        if let value = value as? Bool { return value }
        guard let text = string(value)?.trimmingCharacters(in: .whitespaces).lowercased() else {
            return false
        }
        return ["1", "true", "yes"].contains(text)
    }

    private static func string(_ value: Any?) -> String? {
        if let value = value as? String { return value }
        if let value = value as? NSNumber { return value.stringValue }
        return nil
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else {
            return nil
        }
        return trimmed
    }

    private static func uniqueKeywords(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            for part in value.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
                let keyword = String(part)
                if seen.insert(keyword).inserted {
                    result.append(keyword)
                }
            }
        }
        return result
    }
}
