// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OmnicastCore
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

    func testReportsMalformedCiphertextAsCorrupt() {
        XCTAssertThrowsError(try RayconfigReader().read(data: Data([1, 2, 3]), password: "password")) { error in
            guard case .corruptFile = error as? RayconfigReaderError else {
                return XCTFail("Expected a corrupt file error")
            }
        }
    }

    func testSyntheticFixtureUsesTheOpenSSLFormat() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let inputURL = directory.appendingPathComponent("fixture.rayconfig")
        let outputURL = directory.appendingPathComponent("fixture.gzip")
        let payload = try JSONEncoder().encode(RaycastBackup(raycastVersion: "1.99.0"))
        try RayconfigFixtureWriter.make(payload: payload, password: "format password")
            .write(to: inputURL)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        process.arguments = [
            "enc", "-d", "-aes-256-cbc", "-nosalt",
            "-in", inputURL.path, "-out", outputURL.path,
            "-k", "format password"
        ]
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertEqual(Array(try Data(contentsOf: outputURL).prefix(3)), [0x1F, 0x8B, 0x08])
    }
}
