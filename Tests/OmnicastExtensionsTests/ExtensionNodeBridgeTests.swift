// SPDX-License-Identifier: GPL-3.0-or-later

@testable import OmnicastExtensions
import XCTest

final class ExtensionNodeBridgeTests: XCTestCase {
    func testExecUsesWorkingDirectoryAndEnvironment() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "OmnicastNodeBridgeTests.\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let result = try await ExtensionNodeBridge().executeProcess(payload: [
            "kind": .string("exec"),
            "command": .string("printf '%s:%s' \"$OMNICAST_VALUE\" \"$PWD\""),
            "arguments": .array([]),
            "options": .object([
                "cwd": .string(directory.path),
                "env": .object(["OMNICAST_VALUE": .string("present")]),
                "timeout": .number(5_000)
            ])
        ])

        guard case .object(let values) = result else {
            return XCTFail("The process bridge returned an invalid result")
        }
        XCTAssertEqual(values["status"], .number(0))
        guard case .string(let stdout) = values["stdout"] else {
            return XCTFail("The process bridge did not return standard output")
        }
        XCTAssertTrue(stdout.hasPrefix("present:"))
        XCTAssertTrue(stdout.hasSuffix(directory.lastPathComponent))
    }

    func testExecFileListsProcesses() async throws {
        let bridge = ExtensionNodeBridge()
        let result = try await bridge.executeProcess(payload: [
            "kind": .string("execFile"),
            "command": .string("ps"),
            "arguments": .array([
                .string("-eo"),
                .string("pid,ppid,pcpu,rss,comm")
            ]),
            "options": .object([
                "timeout": .number(5_000),
                "maxBuffer": .number(10 * 1_024 * 1_024)
            ])
        ])

        guard case .object(let values) = result,
              case .number(let status) = values["status"],
              case .string(let stdout) = values["stdout"],
              case .string(let stderr) = values["stderr"] else {
            return XCTFail("The process bridge returned an invalid result")
        }
        if status == 126, stderr.contains("Operation not permitted") {
            throw XCTSkip("Process enumeration is unavailable in this test sandbox")
        }
        XCTAssertEqual(status, 0)
        XCTAssertTrue(stdout.contains("PID"))
        XCTAssertGreaterThan(stdout.split(whereSeparator: \.isNewline).count, 1)
    }
}
