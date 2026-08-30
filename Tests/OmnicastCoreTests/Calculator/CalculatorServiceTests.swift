// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import XCTest

final class CalculatorServiceTests: XCTestCase {
    private let service = CalculatorService(locale: Locale(identifier: "en_US"))

    func testEvaluatesMath() throws {
        let result = try XCTUnwrap(service.evaluate(query: "2 + 2"))

        XCTAssertEqual(result.kind, .math)
        XCTAssertEqual(result.input, "2 + 2")
        XCTAssertEqual(result.inputLabel, "Expression")
        XCTAssertEqual(result.result, "4")
    }

    func testEvaluatesUnitConversion() throws {
        let result = try XCTUnwrap(service.evaluate(query: "10 km in miles"))

        XCTAssertEqual(result.kind, .unit)
        XCTAssertFalse(result.result.isEmpty)
        XCTAssertEqual(result.inputLabel, "From")
        XCTAssertEqual(result.resultLabel, "To")
    }

    func testRejectsLikelySearchQueries() {
        XCTAssertNil(service.evaluate(query: "42"))
        XCTAssertNil(service.evaluate(query: "weather"))
        XCTAssertNotNil(service.evaluate(query: "pi"))
    }

    func testProviderReturnsOnlyInlineResults() async {
        let provider = CalculatorProvider(service: service)
        let commands = await provider.commands()

        XCTAssertTrue(commands.isEmpty)
        XCTAssertEqual(provider.inlineResult(for: "6 * 7")?.subtitle, "42")
    }
}
