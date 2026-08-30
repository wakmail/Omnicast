// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OmnicastCore
import XCTest

final class RayconfigDropValidationTests: XCTestCase {
    func testAcceptsOneRayconfigOrJSONFile() throws {
        let rayconfig = URL(fileURLWithPath: "/tmp/Backup.RAYCONFIG")
        let json = URL(fileURLWithPath: "/tmp/backup.json")

        XCTAssertEqual(try RayconfigDropValidator.validate([rayconfig]), rayconfig)
        XCTAssertEqual(try RayconfigDropValidator.validate([json]), json)
    }

    func testRejectsMissingOrMultipleFiles() {
        XCTAssertThrowsError(try RayconfigDropValidator.validate([])) { error in
            XCTAssertEqual(error as? RayconfigDropValidationError, .invalidFileCount)
        }
        XCTAssertThrowsError(
            try RayconfigDropValidator.validate([
                URL(fileURLWithPath: "/tmp/one.rayconfig"),
                URL(fileURLWithPath: "/tmp/two.rayconfig")
            ])
        ) { error in
            XCTAssertEqual(error as? RayconfigDropValidationError, .invalidFileCount)
        }
    }

    func testRejectsUnsupportedExtensions() {
        XCTAssertThrowsError(
            try RayconfigDropValidator.validate([URL(fileURLWithPath: "/tmp/backup.zip")])
        ) { error in
            XCTAssertEqual(error as? RayconfigDropValidationError, .unsupportedExtension)
        }
    }
}
