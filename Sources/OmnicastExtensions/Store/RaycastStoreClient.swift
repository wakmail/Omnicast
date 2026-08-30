// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct RaycastStoreCommand: Codable, Equatable, Sendable {
    public let name: String
    public let title: String
    public let description: String

    public init(name: String, title: String, description: String) {
        self.name = name
        self.title = title
        self.description = description
    }
}

public struct RaycastStoreExtension: Decodable, Equatable, Sendable {
    public let name: String
    public let title: String
    public let description: String
    public let author: String
    public let iconURL: URL?
    public let screenshotURLs: [URL]
    public let categories: [String]
    public let platforms: [String]
    public let commands: [RaycastStoreCommand]
    public let installCount: Int

    enum CodingKeys: String, CodingKey {
        case name
        case title
        case description
        case author
        case iconURL
        case iconUrl
        case iconURLSnake = "icon_url"
        case screenshotURLs
        case screenshotUrls
        case screenshotURLsSnake = "screenshot_urls"
        case categories
        case platforms
        case commands
        case installCount
        case installCountSnake = "install_count"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? name
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        author = try container.decodeIfPresent(String.self, forKey: .author) ?? ""
        let icon = try container.decodeIfPresent(String.self, forKey: .iconURL)
            ?? container.decodeIfPresent(String.self, forKey: .iconUrl)
            ?? container.decodeIfPresent(String.self, forKey: .iconURLSnake)
        iconURL = icon.flatMap(URL.init(string:))
        let screenshots = try container.decodeIfPresent([String].self, forKey: .screenshotURLs)
            ?? container.decodeIfPresent([String].self, forKey: .screenshotUrls)
            ?? container.decodeIfPresent([String].self, forKey: .screenshotURLsSnake)
            ?? []
        screenshotURLs = screenshots.compactMap(URL.init(string:))
        categories = try container.decodeIfPresent([String].self, forKey: .categories) ?? []
        platforms = try container.decodeIfPresent([String].self, forKey: .platforms) ?? []
        commands = try container.decodeIfPresent([RaycastStoreCommand].self, forKey: .commands) ?? []
        installCount = try container.decodeIfPresent(Int.self, forKey: .installCount)
            ?? container.decodeIfPresent(Int.self, forKey: .installCountSnake)
            ?? 0
    }

    public init(
        name: String,
        title: String,
        description: String,
        author: String,
        iconURL: URL? = nil,
        screenshotURLs: [URL] = [],
        categories: [String] = [],
        platforms: [String] = [],
        commands: [RaycastStoreCommand] = [],
        installCount: Int = 0
    ) {
        self.name = name
        self.title = title
        self.description = description
        self.author = author
        self.iconURL = iconURL
        self.screenshotURLs = screenshotURLs
        self.categories = categories
        self.platforms = platforms
        self.commands = commands
        self.installCount = installCount
    }
}

public struct RaycastStoreSearchResults: Equatable, Sendable {
    public let results: [RaycastStoreExtension]
    public let total: Int

    public init(results: [RaycastStoreExtension], total: Int) {
        self.results = results
        self.total = total
    }
}

public struct RaycastExtensionBundle: Sendable {
    public let data: Data
    public let sourceURL: URL
    public let type: String

    public init(data: Data, sourceURL: URL, type: String = "bundle") {
        self.data = data
        self.sourceURL = sourceURL
        self.type = type
    }
}

public protocol RaycastStoreServing: Sendable {
    func search(
        query: String,
        category: String?,
        limit: Int,
        offset: Int
    ) async throws -> RaycastStoreSearchResults
    func metadata(for slug: String) async throws -> RaycastStoreExtension
    func screenshots(for slug: String) async throws -> [URL]
    func downloadBundle(for slug: String) async throws -> RaycastExtensionBundle
}

public enum RaycastStoreError: LocalizedError {
    case invalidResponse
    case requestFailed(Int, String)
    case invalidBundleURL
    case sourceArchiveUnsupported

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "The extension store returned an invalid response"
        case .requestFailed(let status, let body):
            "The extension store request failed with status \(status): \(body)"
        case .invalidBundleURL:
            "The extension store returned an invalid bundle URL"
        case .sourceArchiveUnsupported:
            "The store returned source code instead of a prepared command bundle"
        }
    }
}

public final class RaycastStoreClient: RaycastStoreServing, @unchecked Sendable {
    public static let defaultBaseURL = URL(string: "https://api.supercmd.sh")!

    private let baseURL: URL
    private let session: URLSession
    private let decoder = JSONDecoder()

    public init(
        baseURL: URL = RaycastStoreClient.defaultBaseURL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    public func search(
        query: String,
        category: String? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> RaycastStoreSearchResults {
        var components = URLComponents(
            url: endpoint("extensions/catalog"),
            resolvingAgainstBaseURL: false
        )!
        var items = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]
        if let category, !category.isEmpty {
            items.append(URLQueryItem(name: "category", value: category))
        }
        components.queryItems = items
        let response: SearchResponse = try await request(components.url!)
        return RaycastStoreSearchResults(results: response.results, total: response.total)
    }

    public func metadata(for slug: String) async throws -> RaycastStoreExtension {
        try await request(
            endpoint("extensions").appendingPathComponent(slug)
        )
    }

    public func screenshots(for slug: String) async throws -> [URL] {
        let values: [String] = try await request(
            endpoint("extensions")
                .appendingPathComponent(slug)
                .appendingPathComponent("screenshots")
        )
        return values.compactMap(URL.init(string:))
    }

    public func downloadBundle(for slug: String) async throws -> RaycastExtensionBundle {
        let descriptor: BundleDescriptor = try await request(
            endpoint("extensions")
                .appendingPathComponent(slug)
                .appendingPathComponent("bundle")
        )
        guard descriptor.type == "bundle" else {
            throw RaycastStoreError.sourceArchiveUnsupported
        }
        guard let bundleURL = URL(string: descriptor.url) else {
            throw RaycastStoreError.invalidBundleURL
        }
        let (data, response) = try await session.data(from: bundleURL)
        try validate(response: response, data: data)
        return RaycastExtensionBundle(data: data, sourceURL: bundleURL, type: descriptor.type)
    }

    private func endpoint(_ path: String) -> URL {
        path.split(separator: "/").reduce(baseURL) { url, component in
            url.appendingPathComponent(String(component))
        }
    }

    private func request<Value: Decodable>(_ url: URL) async throws -> Value {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("Omnicast", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(Value.self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let response = response as? HTTPURLResponse else {
            throw RaycastStoreError.invalidResponse
        }
        guard 200..<300 ~= response.statusCode else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw RaycastStoreError.requestFailed(response.statusCode, body)
        }
    }
}

private struct SearchResponse: Decodable {
    let results: [RaycastStoreExtension]
    let total: Int
}

private struct BundleDescriptor: Decodable {
    let url: String
    let type: String
}
