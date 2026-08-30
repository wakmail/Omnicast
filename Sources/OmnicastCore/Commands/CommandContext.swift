// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

@MainActor
public protocol ClipboardService: AnyObject {
    func readText() -> String?
    func writeText(_ text: String)
}

@MainActor
public protocol OpenerService: AnyObject {
    func open(_ url: URL) async throws
    func reveal(_ url: URL)
}

@MainActor
public protocol ToastService: AnyObject {
    func show(_ message: String)
}

public struct CommandContext {
    public let clipboard: any ClipboardService
    public let opener: any OpenerService
    public let toasts: any ToastService

    @MainActor
    public init(
        clipboard: any ClipboardService,
        opener: any OpenerService,
        toasts: any ToastService
    ) {
        self.clipboard = clipboard
        self.opener = opener
        self.toasts = toasts
    }
}
