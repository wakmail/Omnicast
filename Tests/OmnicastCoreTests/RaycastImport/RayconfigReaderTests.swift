// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
@testable import OmnicastCore
import XCTest

final class RayconfigReaderTests: XCTestCase {
    func testReadsEncryptedSyntheticBackup() throws {
        let expected = RaycastBackup(
            raycastVersion: "1.99.0",
            quicklinksPackage: RaycastQuicklinksPackage(
                quicklinks: [RaycastQuicklinkRecord(name: "Search", url: "https://example.com?q={argument}")]
            ),
            snippetsPackage: RaycastSnippetsPackage(
                snippets: [RaycastSnippetRecord(name: "Greeting", text: "Hello")]
            )
        )
        let payload = try JSONEncoder().encode(expected)
        let fixture = try RayconfigFixtureWriter.make(payload: payload, password: "correct horse")

        let decoded = try RayconfigReader().read(data: fixture, password: "correct horse")

        XCTAssertEqual(decoded, expected)
    }

    func testReportsWrongPasswordSeparately() throws {
        let payload = try JSONEncoder().encode(RaycastBackup(raycastVersion: "1.99.0"))
        let fixture = try RayconfigFixtureWriter.make(payload: payload, password: "right password")

        XCTAssertThrowsError(try RayconfigReader().read(data: fixture, password: "wrong password")) { error in
            XCTAssertEqual(error as? RayconfigReaderError, .wrongPassword)
        }
    }

    func testReportsMalformedContainerAsCorrupt() {
        XCTAssertThrowsError(try RayconfigReader().read(data: Data([1, 2, 3]), password: "password")) { error in
            guard case .corruptFile = error as? RayconfigReaderError else {
                return XCTFail("Expected a corrupt file error")
            }
        }
    }

    func testParsesClassicContainerOffsets() throws {
        let initializationVector = Data((0..<16).map(UInt8.init))
        let ciphertext = Data(repeating: 0xA5, count: 32)

        let container = try RayconfigContainer.parse(initializationVector + ciphertext)

        XCTAssertEqual(container.version, .classic)
        XCTAssertEqual(RayconfigContainer.initializationVectorRange, 0..<16)
        XCTAssertEqual(RayconfigContainer.ciphertextOffset, 16)
        XCTAssertNil(RayconfigContainer.saltRange)
        XCTAssertEqual(RayconfigContainer.hmacLength, 0)
        XCTAssertEqual(container.initializationVector, initializationVector)
        XCTAssertEqual(container.ciphertext, ciphertext)
    }

    func testRejectsContainerWithoutOneCiphertextBlock() {
        let initializationVectorOnly = Data(repeating: 0, count: 16)

        XCTAssertThrowsError(try RayconfigContainer.parse(initializationVectorOnly)) { error in
            guard case .corruptFile = error as? RayconfigReaderError else {
                return XCTFail("Expected a corrupt file error")
            }
        }
    }

    func testRejectsMisalignedCiphertext() {
        let malformed = Data(repeating: 0, count: 33)

        XCTAssertThrowsError(try RayconfigContainer.parse(malformed)) { error in
            guard case .corruptFile = error as? RayconfigReaderError else {
                return XCTFail("Expected a corrupt file error")
            }
        }
    }

    func testSyntheticFixtureUsesRaycastContainerLayout() throws {
        let payload = try JSONEncoder().encode(RaycastBackup(raycastVersion: "1.99.0"))
        let fixture = try RayconfigFixtureWriter.make(payload: payload, password: "format password")
        let container = try RayconfigContainer.parse(fixture)

        XCTAssertEqual(container.initializationVector, RayconfigFixtureWriter.defaultInitializationVector)
        XCTAssertTrue(container.ciphertext.count.isMultiple(of: 16))
    }

    func testReportsZipPayloadAsUnsupportedVersion() throws {
        let fixture = try RayconfigFixtureWriter.makeUncompressed(
            payload: Data([0x50, 0x4B, 0x03, 0x04]),
            password: "format password"
        )

        XCTAssertThrowsError(try RayconfigReader().read(data: fixture, password: "format password")) { error in
            XCTAssertEqual(error as? RayconfigReaderError, .unsupportedVersion)
        }
    }
}
