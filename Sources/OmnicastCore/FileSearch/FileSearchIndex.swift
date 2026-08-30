// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation

public struct FileSearchResult: Identifiable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case file
        case directory
        case application
        case other
    }

    public let url: URL
    public let displayName: String
    public let kind: Kind
    public let modifiedDate: Date?

    public var id: URL { url }

    public init(
        url: URL,
        displayName: String,
        kind: Kind,
        modifiedDate: Date?
    ) {
        self.url = url
        self.displayName = displayName
        self.kind = kind
        self.modifiedDate = modifiedDate
    }
}

@MainActor
public final class FileSearchIndex: ObservableObject {
    @Published public private(set) var results: [FileSearchResult] = []
    @Published public private(set) var isSearching = false

    public private(set) var protectedRoots: [URL]
    public let debounceNanoseconds: UInt64

    private var pendingSearch: Task<Void, Never>?
    private var spotlightSession: SpotlightSearchSession?

    public init(
        protectedRoots: [URL] = [],
        debounceNanoseconds: UInt64 = 250_000_000
    ) {
        self.protectedRoots = Self.uniqueStandardizedURLs(protectedRoots)
        self.debounceNanoseconds = debounceNanoseconds
    }

    public func setProtectedRoots(_ roots: [URL]) {
        protectedRoots = Self.uniqueStandardizedURLs(roots)
    }

    public func updateQuery(_ query: String, limit: Int = 80) {
        pendingSearch?.cancel()
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            spotlightSession?.cancel()
            results = []
            isSearching = false
            return
        }

        isSearching = true
        pendingSearch = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: debounceNanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            let found = await search(query: normalized, limit: limit)
            guard !Task.isCancelled else { return }
            results = found
            isSearching = false
        }
    }

    public func search(query: String, limit: Int = 80) async -> [FileSearchResult] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, limit > 0 else { return [] }

        async let spotlight = spotlightResults(query: normalized, limit: limit * 4)
        async let walked = Self.walk(
            roots: protectedRoots,
            matching: normalized,
            limit: limit * 4
        )
        let combined = await spotlight + walked
        return Self.mergeAndRank(combined, query: normalized, limit: limit)
    }

    public nonisolated static func shouldExclude(
        _ url: URL,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> Bool {
        let components = url.standardizedFileURL.pathComponents
        let lowered = components.map { $0.lowercased() }
        let excludedNames: Set<String> = [
            "node_modules", "dist", "build", "out", ".next", ".nuxt",
            ".turbo", ".cache", "coverage", "target", "vendor",
            "__pycache__", ".venv", "venv", "tmp", "temp", "logs",
            "log", "deriveddata", ".terraform", ".pnpm-store", ".npm",
            ".git", ".hg", ".svn"
        ]
        if lowered.contains(where: excludedNames.contains) {
            return true
        }

        if components.dropFirst().contains(where: { $0.hasPrefix(".") }) {
            return true
        }

        let home = homeDirectory.standardizedFileURL.pathComponents
        if components.starts(with: home) {
            let relative = Array(lowered.dropFirst(home.count))
            if relative.first == "library" {
                return true
            }
        }

        for index in lowered.indices where lowered[index] == "library" {
            let next = lowered.index(after: index)
            if next < lowered.endIndex, lowered[next] == "caches" {
                return true
            }
        }
        return false
    }

    public nonisolated static func fallbackResults(
        roots: [URL],
        matching query: String,
        limit: Int = 80
    ) async -> [FileSearchResult] {
        await walk(roots: roots, matching: query, limit: limit)
    }

    private func spotlightResults(query: String, limit: Int) async -> [FileSearchResult] {
        spotlightSession?.cancel()
        return await withCheckedContinuation { continuation in
            let session = SpotlightSearchSession(
                searchText: query,
                limit: limit,
                filter: { !Self.shouldExclude($0) }
            ) { [weak self] found in
                self?.spotlightSession = nil
                continuation.resume(returning: found)
            }
            spotlightSession = session
            session.start()
        }
    }

    private nonisolated static func walk(
        roots: [URL],
        matching query: String,
        limit: Int
    ) async -> [FileSearchResult] {
        await Task.detached(priority: .userInitiated) {
            walkSynchronously(roots: roots, matching: query, limit: limit)
        }.value
    }

    private nonisolated static func walkSynchronously(
        roots: [URL],
        matching query: String,
        limit: Int
    ) -> [FileSearchResult] {
        let manager = FileManager.default
        let keys: [URLResourceKey] = [
            .isDirectoryKey,
            .isApplicationKey,
            .contentModificationDateKey,
            .nameKey
        ]
        let terms = normalizedTerms(query)
        var found: [FileSearchResult] = []
        var seen = Set<URL>()

        for root in uniqueStandardizedURLs(roots) {
            guard let enumerator = manager.enumerator(
                at: root,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else {
                continue
            }

            for case let candidate as URL in enumerator {
                if shouldExclude(candidate) {
                    enumerator.skipDescendants()
                    continue
                }
                let canonical = candidate.standardizedFileURL
                guard seen.insert(canonical).inserted else { continue }
                guard matches(canonical, terms: terms) else { continue }
                if let result = makeResult(url: canonical) {
                    found.append(result)
                }
                if found.count >= limit {
                    return found
                }
            }
        }
        return found
    }

    private nonisolated static func makeResult(url: URL) -> FileSearchResult? {
        let values = try? url.resourceValues(forKeys: [
            .isDirectoryKey,
            .isApplicationKey,
            .contentModificationDateKey,
            .nameKey
        ])
        let kind: FileSearchResult.Kind
        if values?.isApplication == true || url.pathExtension.lowercased() == "app" {
            kind = .application
        } else if values?.isDirectory == true {
            kind = .directory
        } else {
            kind = .file
        }
        return FileSearchResult(
            url: url,
            displayName: values?.name ?? url.lastPathComponent,
            kind: kind,
            modifiedDate: values?.contentModificationDate
        )
    }

    private nonisolated static func mergeAndRank(
        _ values: [FileSearchResult],
        query: String,
        limit: Int
    ) -> [FileSearchResult] {
        let normalized = query.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
        var byURL: [URL: FileSearchResult] = [:]
        for value in values {
            byURL[value.url.standardizedFileURL] = value
        }
        return byURL.values.sorted { left, right in
            let leftName = left.displayName.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            let rightName = right.displayName.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            let leftPrefix = leftName.hasPrefix(normalized)
            let rightPrefix = rightName.hasPrefix(normalized)
            if leftPrefix != rightPrefix { return leftPrefix }
            if leftName.count != rightName.count { return leftName.count < rightName.count }
            return leftName.localizedStandardCompare(rightName) == .orderedAscending
        }.prefix(limit).map { $0 }
    }

    private nonisolated static func matches(_ url: URL, terms: [String]) -> Bool {
        let text = (url.lastPathComponent + " " + url.path).folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
        return terms.allSatisfy(text.contains)
    }

    private nonisolated static func normalizedTerms(_ query: String) -> [String] {
        query.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        ).split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    private nonisolated static func uniqueStandardizedURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<URL>()
        return urls.map(\.standardizedFileURL).filter { seen.insert($0).inserted }
    }
}

@MainActor
private final class SpotlightSearchSession {
    private let metadataQuery = NSMetadataQuery()
    private let searchText: String
    private let limit: Int
    private let filter: (URL) -> Bool
    private var completion: (([FileSearchResult]) -> Void)?
    private var observer: NSObjectProtocol?
    private var timeout: DispatchWorkItem?

    init(
        searchText: String,
        limit: Int,
        filter: @escaping (URL) -> Bool,
        completion: @escaping ([FileSearchResult]) -> Void
    ) {
        self.searchText = searchText
        self.limit = limit
        self.filter = filter
        self.completion = completion
    }

    func start() {
        metadataQuery.searchScopes = [NSMetadataQueryUserHomeScope]
        metadataQuery.predicate = NSPredicate(
            format: "%K ==[cd] %@",
            NSMetadataItemFSNameKey,
            "*\(searchText)*"
        )
        observer = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: metadataQuery,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.finishWithCurrentResults()
            }
        }
        let timeout = DispatchWorkItem { [weak self] in
            self?.finishWithCurrentResults()
        }
        self.timeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: timeout)
        if !metadataQuery.start() {
            finish([])
        }
    }

    func cancel() {
        finish([])
    }

    private func finishWithCurrentResults() {
        metadataQuery.disableUpdates()
        var found: [FileSearchResult] = []
        for index in 0..<min(metadataQuery.resultCount, limit) {
            guard
                let item = metadataQuery.result(at: index) as? NSMetadataItem,
                let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL,
                filter(url),
                let result = makeResult(item: item, url: url)
            else {
                continue
            }
            found.append(result)
        }
        finish(found)
    }

    private func makeResult(item: NSMetadataItem, url: URL) -> FileSearchResult? {
        let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .isApplicationKey])
        let kind: FileSearchResult.Kind
        if resourceValues?.isApplication == true || url.pathExtension.lowercased() == "app" {
            kind = .application
        } else if resourceValues?.isDirectory == true {
            kind = .directory
        } else {
            kind = .file
        }
        return FileSearchResult(
            url: url.standardizedFileURL,
            displayName: (item.value(forAttribute: NSMetadataItemDisplayNameKey) as? String)
                ?? url.lastPathComponent,
            kind: kind,
            modifiedDate: item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date
        )
    }

    private func finish(_ results: [FileSearchResult]) {
        guard let completion else { return }
        self.completion = nil
        timeout?.cancel()
        timeout = nil
        metadataQuery.stop()
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        self.observer = nil
        completion(results)
    }
}
