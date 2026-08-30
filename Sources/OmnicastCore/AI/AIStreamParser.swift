// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum AIStreamParser {
    public static func eventData(in payload: String) -> [String] {
        payload.components(separatedBy: "\n").compactMap(eventData(fromLine:))
    }

    public static func eventData(fromLine line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data: ") else { return nil }
        return String(trimmed.dropFirst(6))
    }

    public static func openAIText(from data: String) -> String? {
        guard data != "[DONE]", let object = jsonObject(data) else { return nil }
        return (((object["choices"] as? [[String: Any]])?.first?["delta"] as? [String: Any])?["content"] as? String)
    }

    public static func anthropicText(from data: String) -> String? {
        guard
            let object = jsonObject(data),
            object["type"] as? String == "content_block_delta",
            let delta = object["delta"] as? [String: Any]
        else { return nil }
        return delta["text"] as? String
    }

    public static func geminiText(from data: String) -> String? {
        guard
            let object = jsonObject(data),
            let candidate = (object["candidates"] as? [[String: Any]])?.first,
            let content = candidate["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]]
        else { return nil }
        let text = parts.compactMap { $0["text"] as? String }.joined()
        return text.isEmpty ? nil : text
    }

    public static func ollamaText(from line: String) -> String? {
        guard let object = jsonObject(line) else { return nil }
        if let message = object["message"] as? [String: Any] {
            return message["content"] as? String
        }
        return object["response"] as? String
    }

    public static func parseOpenAI(_ payload: String) -> [String] {
        eventData(in: payload).compactMap(openAIText(from:))
    }

    public static func parseAnthropic(_ payload: String) -> [String] {
        eventData(in: payload).compactMap(anthropicText(from:))
    }

    public static func parseGemini(_ payload: String) -> [String] {
        eventData(in: payload).compactMap(geminiText(from:))
    }

    public static func parseOllama(_ payload: String) -> [String] {
        payload.components(separatedBy: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : ollamaText(from: trimmed)
        }
    }

    private static func jsonObject(_ text: String) -> [String: Any]? {
        guard let data = text.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}
