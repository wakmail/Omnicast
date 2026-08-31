// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OmnicastExtensions
import XCTest

final class RaycastStoreClientTests: XCTestCase {
    func testSearchMetadataAndBundleDownload() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StoreURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let baseURL = URL(string: "https://store.example")!
        let client = RaycastStoreClient(baseURL: baseURL, session: session)
        StoreURLProtocol.handler = { request in
            let path = try XCTUnwrap(request.url?.path)
            let body: Data
            switch path {
            case "/extensions/catalog":
                let components = try XCTUnwrap(URLComponents(
                    url: try XCTUnwrap(request.url),
                    resolvingAgainstBaseURL: false
                ))
                XCTAssertEqual(
                    components.queryItems?.first(where: { $0.name == "q" })?.value,
                    "gitlab"
                )
                body = Data(Self.searchResponse.utf8)
            case "/extensions/gitlab":
                body = Data(Self.metadataResponse.utf8)
            case "/extensions/gitlab/screenshots":
                body = Data("[\"https://store.example/screenshot.png\"]".utf8)
            case "/extensions/gitlab/bundle":
                body = Data("""
                {"url":"https://downloads.example/gitlab.tar.gz","type":"bundle"}
                """.utf8)
            case "/gitlab.tar.gz":
                body = Data([0x1f, 0x8b, 0x08])
            default:
                XCTFail("Unexpected request path \(path)")
                body = Data()
            }
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, body)
        }
        defer { StoreURLProtocol.handler = nil }

        let search = try await client.search(query: "gitlab")
        let metadata = try await client.metadata(for: "gitlab")
        let screenshots = try await client.screenshots(for: "gitlab")
        let bundle = try await client.downloadBundle(for: "gitlab")

        XCTAssertEqual(search.total, 1)
        XCTAssertEqual(search.results.first?.installCount, 42)
        XCTAssertEqual(metadata.title, "GitLab")
        XCTAssertEqual(metadata.commands.first?.name, "search-projects")
        XCTAssertEqual(
            metadata.screenshotURLs.map(\.absoluteString),
            ["https://store.example/catalog-screenshot.png"]
        )
        XCTAssertEqual(screenshots.map(\.absoluteString), ["https://store.example/screenshot.png"])
        XCTAssertEqual(bundle.data, Data([0x1f, 0x8b, 0x08]))
        XCTAssertEqual(bundle.type, "bundle")
    }

    private static let metadataResponse = """
    {
      "name": "gitlab",
      "title": "GitLab",
      "description": "Manage GitLab",
      "author": "tonka3000",
      "icon_url": "https://store.example/icon.png",
      "screenshot_urls": ["https://store.example/catalog-screenshot.png"],
      "categories": ["Developer Tools"],
      "platforms": ["macOS"],
      "commands": [
        {"name":"search-projects","title":"Search Projects","description":"Search"}
      ],
      "install_count": 42
    }
    """

    private static let searchResponse = """
    [\(metadataResponse)]
    """
}

private final class StoreURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let handler = try XCTUnwrap(Self.handler)
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
