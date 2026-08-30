// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Carbon
import OmnicastCore
import SwiftUI

public struct ShortcutRecorderView: View {
    @Binding private var shortcut: HotkeySettings
    private let onRecordingChanged: (Bool) -> Void

    @State private var isRecording = false
    @State private var pendingModifiers: UInt32 = 0
    @State private var explanation: String?

    public init(
        shortcut: Binding<HotkeySettings>,
        onRecordingChanged: @escaping (Bool) -> Void
    ) {
        _shortcut = shortcut
        self.onRecordingChanged = onRecordingChanged
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Global shortcut")
                Spacer()

                Button(action: beginRecording) {
                    HStack(spacing: 4) {
                        ForEach(Array(displayedKeyCaps.enumerated()), id: \.offset) { _, cap in
                            ShortcutKeyCap(cap)
                        }
                    }
                    .frame(minWidth: 100, minHeight: 24)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background {
                    ShortcutCaptureView(
                        isRecording: isRecording,
                        onKeyDown: captureKeyDown,
                        onFlagsChanged: captureFlagsChanged,
                        onCancel: finishRecording
                    )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            isRecording ? Color.accentColor : Color.secondary.opacity(0.35),
                            lineWidth: isRecording ? 2 : 1
                        )
                }

                Button("Clear", action: clearShortcut)
                    .disabled(shortcut == .optionSpace && !isRecording)
            }

            Text(explanation ?? "Press the shortcut field, then type a key combination.")
                .font(.caption)
                .foregroundStyle(explanation == nil ? Color.secondary : Color.red)
                .lineLimit(1)
        }
        .onDisappear { finishRecording() }
    }

    private var displayedKeyCaps: [String] {
        if isRecording {
            let pending = ShortcutKeySymbols.keyCaps(keyCode: nil, modifiers: pendingModifiers)
            return pending.isEmpty ? ["Type shortcut"] : pending
        }
        return ShortcutKeySymbols.keyCaps(
            keyCode: shortcut.keyCode,
            modifiers: shortcut.modifiers
        )
    }

    private func beginRecording() {
        guard !isRecording else { return }
        pendingModifiers = 0
        explanation = nil
        isRecording = true
        onRecordingChanged(true)
    }

    private func finishRecording() {
        guard isRecording else { return }
        isRecording = false
        pendingModifiers = 0
        onRecordingChanged(false)
    }

    private func clearShortcut() {
        shortcut = .optionSpace
        explanation = nil
        finishRecording()
    }

    private func captureKeyDown(_ event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            explanation = nil
            finishRecording()
            return
        }

        let modifiers = ShortcutKeySymbols.carbonModifiers(from: event.modifierFlags)
        switch ShortcutValidator.validate(
            keyCode: UInt32(event.keyCode),
            modifiers: modifiers
        ) {
        case .accepted:
            let keyCode = UInt32(event.keyCode)
            let name = ShortcutKeySymbols.keyCaps(
                keyCode: keyCode,
                modifiers: modifiers
            ).joined(separator: " ")
            shortcut = HotkeySettings(
                keyCode: keyCode,
                modifiers: modifiers,
                displayName: name
            )
            explanation = nil
            finishRecording()
        case .rejected(let message):
            explanation = message
        }
    }

    private func captureFlagsChanged(_ event: NSEvent) {
        let modifiers = ShortcutKeySymbols.carbonModifiers(from: event.modifierFlags)
        if modifiers == 0, pendingModifiers != 0 {
            if case .rejected(let message) = ShortcutValidator.validate(
                keyCode: nil,
                modifiers: pendingModifiers
            ) {
                explanation = message
            }
        } else if modifiers != 0 {
            explanation = nil
        }
        pendingModifiers = modifiers
    }
}

private struct ShortcutKeyCap: View {
    let label: String

    init(_ label: String) {
        self.label = label
    }

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.13), in: RoundedRectangle(cornerRadius: 4))
    }
}

private struct ShortcutCaptureView: NSViewRepresentable {
    let isRecording: Bool
    let onKeyDown: (NSEvent) -> Void
    let onFlagsChanged: (NSEvent) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> ShortcutCaptureNSView {
        let view = ShortcutCaptureNSView()
        update(view)
        return view
    }

    func updateNSView(_ nsView: ShortcutCaptureNSView, context: Context) {
        update(nsView)
        if isRecording {
            DispatchQueue.main.async { [weak nsView] in
                nsView?.window?.makeFirstResponder(nsView)
            }
        } else if nsView.window?.firstResponder === nsView {
            nsView.window?.makeFirstResponder(nil)
        }
    }

    private func update(_ view: ShortcutCaptureNSView) {
        view.isRecording = isRecording
        view.onKeyDown = onKeyDown
        view.onFlagsChanged = onFlagsChanged
        view.onCancel = onCancel
    }
}

private final class ShortcutCaptureNSView: NSView {
    var isRecording = false
    var onKeyDown: ((NSEvent) -> Void)?
    var onFlagsChanged: ((NSEvent) -> Void)?
    var onCancel: (() -> Void)?
    private var closeObserver: NSObjectProtocol?

    override var acceptsFirstResponder: Bool { isRecording }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let closeObserver {
            NotificationCenter.default.removeObserver(closeObserver)
        }
        guard let window else { return }
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.onCancel?()
        }
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        onKeyDown?(event)
    }

    override func flagsChanged(with event: NSEvent) {
        guard isRecording else {
            super.flagsChanged(with: event)
            return
        }
        onFlagsChanged?(event)
    }

    deinit {
        if let closeObserver {
            NotificationCenter.default.removeObserver(closeObserver)
        }
    }
}

private enum ShortcutKeySymbols {
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= ShortcutValidator.commandModifier }
        if flags.contains(.shift) { result |= ShortcutValidator.shiftModifier }
        if flags.contains(.option) { result |= ShortcutValidator.optionModifier }
        if flags.contains(.control) { result |= ShortcutValidator.controlModifier }
        return result
    }

    static func keyCaps(keyCode: UInt32?, modifiers: UInt32) -> [String] {
        var result: [String] = []
        if modifiers & ShortcutValidator.controlModifier != 0 { result.append("⌃") }
        if modifiers & ShortcutValidator.optionModifier != 0 { result.append("⌥") }
        if modifiers & ShortcutValidator.shiftModifier != 0 { result.append("⇧") }
        if modifiers & ShortcutValidator.commandModifier != 0 { result.append("⌘") }
        if let keyCode { result.append(keyLabel(for: keyCode)) }
        return result
    }

    private static func keyLabel(for keyCode: UInt32) -> String {
        keyLabels[keyCode] ?? "Key \(keyCode)"
    }

    private static let keyLabels: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "−", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
        38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
        45: "N", 46: "M", 47: ".", 49: "Space", 50: "`", 36: "↩", 48: "⇥",
        51: "⌫", 53: "Esc", 65: ".", 67: "*", 69: "+", 71: "⌧", 75: "/",
        76: "⌤", 78: "−", 81: "=", 82: "0", 83: "1", 84: "2", 85: "3",
        86: "4", 87: "5", 88: "6", 89: "7", 91: "8", 92: "9", 96: "F5",
        97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11",
        105: "F13", 106: "F16", 107: "F14", 109: "F10", 111: "F12",
        113: "F15", 115: "↖", 116: "⇞", 117: "⌦", 118: "F4", 119: "↘",
        120: "F2", 121: "⇟", 122: "F1", 123: "←", 124: "→", 125: "↓",
        126: "↑"
    ]
}
