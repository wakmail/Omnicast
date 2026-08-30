// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import XCTest

final class AIKeyStoreTests: XCTestCase {
    func testInMemoryStorageIsScopedByProvider() throws {
        let store = InMemoryAIKeyStore()
        try store.setAPIKey("openai secret", for: .openAI)
        try store.setAPIKey("anthropic secret", for: .anthropic)

        XCTAssertEqual(try store.apiKey(for: .openAI), "openai secret")
        XCTAssertEqual(try store.apiKey(for: .anthropic), "anthropic secret")
        XCTAssertNil(try store.apiKey(for: .gemini))

        try store.deleteAPIKey(for: .openAI)
        XCTAssertNil(try store.apiKey(for: .openAI))
        XCTAssertEqual(try store.apiKey(for: .anthropic), "anthropic secret")
    }

    func testEmptyValueDeletesKey() throws {
        let store = InMemoryAIKeyStore(keys: [.gemini: "secret"])
        try store.setAPIKey("", for: .gemini)
        XCTAssertNil(try store.apiKey(for: .gemini))
    }
}
