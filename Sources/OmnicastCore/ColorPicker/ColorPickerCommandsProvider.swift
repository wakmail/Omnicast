// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Foundation

public protocol ColorSampling: Sendable {
    @MainActor
    func sample() async -> NSColor?
}

public final class SystemColorSampler: ColorSampling, @unchecked Sendable {
    public init() {}

    @MainActor
    public func sample() async -> NSColor? {
        let previousApplication = NSWorkspace.shared.frontmostApplication
        NSApp.activate(ignoringOtherApps: true)
        return await withCheckedContinuation { continuation in
            NSColorSampler().show { color in
                previousApplication?.activate()
                continuation.resume(returning: color)
            }
        }
    }
}

public struct PickColorCommand: Command {
    public let id = "color:pick"
    public let title = "Pick Color"
    public let subtitle = "Sample a color from the screen"
    public let icon = CommandIcon.sfSymbol("eyedropper")
    public let keywords = ["color", "picker", "sample", "hex", "eyedropper"]
    public let kind = CommandKind.system

    private let store: ColorHistoryStore
    private let sampler: any ColorSampling

    @MainActor
    public init(store: ColorHistoryStore, sampler: any ColorSampling = SystemColorSampler()) {
        self.store = store
        self.sampler = sampler
    }

    @MainActor
    public func execute(context: CommandContext) async throws {
        guard let selectedColor = await sampler.sample(),
              let color = selectedColor.usingColorSpace(.sRGB) else {
            return
        }
        let hex = Self.hex(red: color.redComponent, green: color.greenComponent, blue: color.blueComponent)
        context.clipboard.writeText(hex)
        try store.record(hex: hex)
        context.toasts.show("Copied \(hex)")
    }

    public static func hex(red: CGFloat, green: CGFloat, blue: CGFloat) -> String {
        let components = [red, green, blue].map { component in
            min(255, max(0, Int((component * 255).rounded())))
        }
        return String(format: "#%02X%02X%02X", components[0], components[1], components[2])
    }
}

public struct ColorHistoryCommand: Command {
    public let id = "color:history"
    public let title = "Color History"
    public let subtitle = "Copy a recently sampled color"
    public let icon = CommandIcon.sfSymbol("paintpalette")
    public let keywords = ["color", "history", "hex", "palette"]
    public let kind = CommandKind.system

    public init() {}

    @MainActor
    public func execute(context: CommandContext) async throws {}
}

public struct ColorPickerCommandsProvider: CommandProvider {
    private let pickCommand: PickColorCommand

    @MainActor
    public init(store: ColorHistoryStore, sampler: any ColorSampling = SystemColorSampler()) {
        pickCommand = PickColorCommand(store: store, sampler: sampler)
    }

    public func commands() async -> [any Command] {
        [pickCommand, ColorHistoryCommand()]
    }
}
