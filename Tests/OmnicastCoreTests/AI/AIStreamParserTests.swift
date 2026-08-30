// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import XCTest

final class AIStreamParserTests: XCTestCase {
    func testOpenAISample() {
        let payload = """
        data: {"choices":[{"delta":{"content":"Hello"}}]}

        data: {"choices":[{"delta":{"content":" world"}}]}
        data: [DONE]
        """

        XCTAssertEqual(AIStreamParser.parseOpenAI(payload), ["Hello", " world"])
    }

    func testAnthropicSample() {
        let payload = """
        event: content_block_delta
        data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"Hello"}}

        data: {"type":"message_delta","delta":{"stop_reason":"end_turn"}}
        data: {"type":"content_block_delta","delta":{"type":"text_delta","text":" Claude"}}
        """

        XCTAssertEqual(AIStreamParser.parseAnthropic(payload), ["Hello", " Claude"])
    }

    func testGeminiSampleJoinsTextParts() {
        let payload = """
        data: {"candidates":[{"content":{"role":"model","parts":[{"text":"Hello"},{"text":" Gemini"}]}}]}
        data: {"candidates":[{"finishReason":"STOP"}]}
        """

        XCTAssertEqual(AIStreamParser.parseGemini(payload), ["Hello Gemini"])
    }

    func testOllamaChatSample() {
        let payload = """
        {"model":"llama3","message":{"role":"assistant","content":"Hello"},"done":false}
        malformed
        {"model":"llama3","message":{"role":"assistant","content":" Ollama"},"done":false}
        {"model":"llama3","message":{"role":"assistant","content":""},"done":true}
        """

        XCTAssertEqual(AIStreamParser.parseOllama(payload), ["Hello", " Ollama", ""])
    }

    func testOnlyDataLinesAreAccepted() {
        XCTAssertNil(AIStreamParser.eventData(fromLine: "event: message"))
        XCTAssertNil(AIStreamParser.eventData(fromLine: "data:{\"value\":1}"))
        XCTAssertEqual(AIStreamParser.eventData(fromLine: "  data: value  "), "value")
    }
}
