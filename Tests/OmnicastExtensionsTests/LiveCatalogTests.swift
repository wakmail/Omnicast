import XCTest
@testable import OmnicastExtensions

final class LiveCatalogTests: XCTestCase {
    func testLiveCatalogDecodes() async throws {
        guard ProcessInfo.processInfo.environment["OMNICAST_LIVE"] == "1" else {
            throw XCTSkip("live")
        }
        let client = RaycastStoreClient()
        let results = try await client.search(query: "", limit: 5000)
        XCTAssertGreaterThan(results.total, 100)
        let github = try await client.search(query: "github", limit: 50)
        XCTAssertTrue(github.results.contains { $0.name.contains("github") || $0.title.lowercased().contains("github") })
        print("LIVE catalog total:", results.total, "github matches:", github.results.count)
    }
}
