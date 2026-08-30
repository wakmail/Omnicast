// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import XCTest

final class ClipboardContentTests: XCTestCase {
    func testTextNormalizationAndPreview() {
        XCTAssertEqual(ClipboardTextContent.normalized("  One\r\nTwo  "), "One\nTwo")
        let text = String(repeating: "a", count: ClipboardTextContent.previewLength + 1)
        XCTAssertEqual(ClipboardTextContent.preview(for: text).count, ClipboardTextContent.previewLength + 1)
        XCTAssertTrue(ClipboardTextContent.preview(for: text).hasSuffix("…"))
    }

    func testPrivatePasteboardTypesAreSkippedCaseInsensitively() {
        XCTAssertTrue(ClipboardCapturePolicy.shouldSkip(typeNames: [
            "ORG.NSPASTEBOARD.CONCEALEDTYPE"
        ]))
        XCTAssertTrue(ClipboardCapturePolicy.shouldSkip(typeNames: [
            ClipboardCapturePolicy.transientTypeName
        ]))
        XCTAssertFalse(ClipboardCapturePolicy.shouldSkip(typeNames: ["public.utf8.plaintext"]))
    }
}
