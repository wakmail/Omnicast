// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
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
    private var task: URLSessionDataTask?

    func load(_ url: URL?) {
        guard currentURL != url || (image == nil && task == nil) else { return }
        cancel()
        currentURL = url
        image = nil
        guard let url else { return }

        if let cached = RemoteIconCache.shared.image(for: url) {
            image = cached
            return
        }
        if url.isFileURL {
            guard let image = NSImage(contentsOf: url) else { return }
            RemoteIconCache.shared.insert(image, for: url)
            self.image = image
            return
        }

        task = URLSession.shared.dataTask(with: url) { [weak self] data, response, _ in
            guard let data,
                  (response as? HTTPURLResponse).map({ 200..<300 ~= $0.statusCode }) ?? true else {
                Task { @MainActor [weak self] in self?.task = nil }
                return
            }
            Task { @MainActor [weak self] in
                guard let self, self.currentURL == url, let image = NSImage(data: data) else {
                    self?.task = nil
                    return
                }
                RemoteIconCache.shared.insert(image, for: url)
                self.image = image
                self.task = nil
            }
        }
        task?.resume()
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}

@MainActor
private final class RemoteIconCache {
    static let shared = RemoteIconCache()

    private let cache = NSCache<NSURL, NSImage>()

    private init() {
        cache.countLimit = 128
    }

    func image(for url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }

    func insert(_ image: NSImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}
