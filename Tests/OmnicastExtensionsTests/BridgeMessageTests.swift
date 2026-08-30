// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastExtensions
import XCTest

final class BridgeMessageTests: XCTestCase {
    func testRequestEncodingAndDecoding() throws {
        let request = ExtensionBridgeRequest(
            id: "request1",
            operation: .localStorageSetItem,
            payload: [
                "key": .string("selection"),
                "value": .object([
                    "title": .string("Example"),
                    "count": .number(3),
                    "enabled": .bool(true)
                ])
            ]
        )

        let data = try JSONEncoder().encode(request)
        XCTAssertEqual(try JSONDecoder().decode(ExtensionBridgeRequest.self, from: data), request)
    }

    func testResponseEncodingAndDecoding() throws {
        let success = ExtensionBridgeResponse.success(
            id: "request2",
            result: .array([.string("one"), .null])
        )
        let failure = ExtensionBridgeResponse.failure(
            id: "request3",
            error: "Not supported"
        )

        XCTAssertEqual(
            try JSONDecoder().decode(
                ExtensionBridgeResponse.self,
                from: JSONEncoder().encode(success)
            ),
            success
        )
        XCTAssertEqual(
            try JSONDecoder().decode(
                ExtensionBridgeResponse.self,
                from: JSONEncoder().encode(failure)
            ),
            failure
        )
    }
}
