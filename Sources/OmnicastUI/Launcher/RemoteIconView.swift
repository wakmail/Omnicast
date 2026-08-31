// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import OmnicastCore
import SwiftUI

@MainActor
public struct RemoteIconView<Placeholder: View>: View {
    private let url: URL?
    private let placeholder: Placeholder
    @StateObject private var loader = RemoteIconLoader()

    public init(
        url: URL?,
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.url = url
        self.placeholder = placeholder()
    }

    public var body: some View {
        Group {
            if let image = loader.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                placeholder
            }
        }
        .task(id: url) {
            loader.load(url)
        }
        .onDisappear {
            loader.cancel()
        }
    }
}

@MainActor
private final class RemoteIconLoader: ObservableObject {
    @Published private(set) var image: NSImage?

    private var currentURL: URL?
    private var task: Task<Void, Never>?

    func load(_ url: URL?) {
        guard currentURL != url || (image == nil && task == nil) else { return }
        cancel()
        currentURL = url
        image = nil
        guard let url else { return }

        task = Task { [weak self] in
            let loadedImage = await RemoteIconCache.shared.load(url)
            guard !Task.isCancelled,
                  let self,
                  self.currentURL == url else {
                return
            }
            self.image = loadedImage
            self.task = nil
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}

@MainActor
final class RemoteIconCache {
    static let shared = RemoteIconCache()

    private let cache = NSCache<NSURL, NSImage>()
    private var inFlight: [URL: Task<NSImage?, Never>] = [:]

    private init() {
        cache.countLimit = 128
    }

    func image(for url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }

    func insert(_ image: NSImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }

    func load(_ url: URL) async -> NSImage? {
        if let image = image(for: url) { return image }
        if let task = inFlight[url] { return await task.value }

        let task = Task<NSImage?, Never> {
            if url.isFileURL {
                return NSImage(contentsOf: url)
            }
            if let data = await IconDiskCache.shared.data(for: url),
               let image = NSImage(data: data) {
                return image
            }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let response = response as? HTTPURLResponse,
                   !(200..<300).contains(response.statusCode) {
                    return nil
                }
                guard let image = NSImage(data: data) else { return nil }
                try? await IconDiskCache.shared.store(data, for: url)
                return image
            } catch {
                return nil
            }
        }
        inFlight[url] = task
        let loadedImage = await task.value
        inFlight[url] = nil
        if let loadedImage {
            insert(loadedImage, for: url)
        }
        return loadedImage
    }
}

@MainActor
enum RemoteIconPrefetcher {
    static func prefetch(_ urls: [URL]) {
        for url in Set(urls) where RemoteIconCache.shared.image(for: url) == nil {
            Task {
                _ = await RemoteIconCache.shared.load(url)
            }
        }
    }
}
