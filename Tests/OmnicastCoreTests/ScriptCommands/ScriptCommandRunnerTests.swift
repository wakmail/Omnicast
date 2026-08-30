// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OmnicastCore
import XCTest

final class ScriptCommandRunnerTests: XCTestCase {
    func testRunsShebangAndCapturesOutput() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let scriptURL = directory.appendingPathComponent("example.sh")
        let source = """
        #!/bin/sh
        # @raycast.schemaVersion 1
        # @raycast.title Echo Values
        # @raycast.mode compact
        # @raycast.argument1 {"type":"text","placeholder":"Value"}
        printf 'first line\\n'
        printf '%s\\n' "$1"
        """
        try source.write(to: scriptURL, atomically: true, encoding: .utf8)
        let command = try XCTUnwrap(try ScriptCommandParser.parse(contentsOf: scriptURL))
        let runner = ScriptCommandRunner(
            timeout: 3,
            environment: ["SHELL": "/bin/sh", "PATH": "/usr/bin:/bin"],
            loginShellPath: "/bin/sh"
        )

        let result = try await runner.run(command, arguments: ["argument1": "last line"])

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.firstLine, "first line")
        XCTAssertEqual(result.lastLine, "last line")
        XCTAssertEqual(result.mode, .compact)
        XCTAssertFalse(result.timedOut)
    }

    func testReportsMissingRequiredArguments() async throws {
        let command = try XCTUnwrap(
            ScriptCommandParser.parse(
                source: """
                #!/bin/sh
                # @raycast.schemaVersion 1
                # @raycast.title Required Value
                # @raycast.mode silent
                # @raycast.argument1 {"type":"text","placeholder":"Value"}
                """,
                scriptURL: URL(fileURLWithPath: "/tmp/required.sh")
            )
        )

        do {
            _ = try await ScriptCommandRunner().run(command)
            XCTFail("Expected a missing argument error")
        } catch let error as ScriptCommandExecutionError {
            XCTAssertEqual(error, .missingArguments(["argument1"]))
        }
    }

    func testDisplayLinesRemovesTerminalFormatting() {
        XCTAssertEqual(
            ScriptCommandRunner.displayLines(from: "\u{001B}[31mRed\u{001B}[0m\n\nBlue"),
            ["Red", "Blue"]
        )
    }
}
