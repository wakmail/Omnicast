// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import XCTest

final class LauncherInteractionStateTests: XCTestCase {
    func testNavigationPushAndPopPreserveStackOrder() {
        var stack = LauncherNavigationStack<String>()

        stack.push("Clipboard")
        stack.push("Extension")

        XCTAssertEqual(stack.depth, 2)
        XCTAssertEqual(stack.current, "Extension")
        XCTAssertEqual(stack.pop(), "Extension")
        XCTAssertEqual(stack.current, "Clipboard")
        XCTAssertEqual(stack.pop(), "Clipboard")
        XCTAssertTrue(stack.isRoot)
    }

    func testEscapePopsUntilRootThenHides() {
        var stack = LauncherNavigationStack(destinations: ["Files", "Preview"])

        XCTAssertEqual(stack.handleEscape(), .pop)
        XCTAssertEqual(stack.current, "Files")
        XCTAssertEqual(stack.handleEscape(), .pop)
        XCTAssertTrue(stack.isRoot)
        XCTAssertEqual(stack.handleEscape(), .hide)
    }

    func testArgumentStateRequiresValuesAndCollectsInOrder() {
        var state = LauncherArgumentState(definitions: [
            LauncherArgumentDefinition(
                name: "project",
                placeholder: "Project name",
                isRequired: true
            ),
            LauncherArgumentDefinition(
                name: "branch",
                placeholder: "Branch name",
                isRequired: false
            )
        ])

        XCTAssertEqual(state.submit(""), .needsValue("Project name"))
        XCTAssertEqual(
            state.submit("Omnicast"),
            .next(LauncherArgumentDefinition(
                name: "branch",
                placeholder: "Branch name",
                isRequired: false
            ))
        )
        XCTAssertEqual(
            state.submit("", allowingEmpty: true),
            .complete(["project": "Omnicast", "branch": ""])
        )
    }

    func testUnmatchedQuerySelectsOneWebFallbackRow() throws {
        let results = LauncherSearchResults.resolve(
            commands: [TestCommand(id: "calendar", title: "Calendar")],
            query: "!g swift actors"
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].command.id, "web-search-fallback")
        let command = try XCTUnwrap(results[0].command as? WebSearchFallbackCommand)
        XCTAssertEqual(command.title, "Search Google for swift actors")
        XCTAssertEqual(command.url.host, "www.google.com")
    }
}
