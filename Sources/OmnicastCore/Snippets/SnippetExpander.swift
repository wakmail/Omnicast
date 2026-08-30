// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import ApplicationServices
import Combine
import Foundation

public final class SnippetExpander: @unchecked Sendable {
    private let store: SnippetStore
    private let stateLock = NSLock()
    private var matcher: SnippetKeywordMatcher
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var subscriptions = Set<AnyCancellable>()

    @MainActor
    public init(store: SnippetStore) {
        self.store = store
        matcher = SnippetKeywordMatcher(keywords: Self.keywords(from: store.snippets))
        store.$snippets
            .sink { [weak self] snippets in
                self?.replaceKeywords(Self.keywords(from: snippets))
            }
            .store(in: &subscriptions)
    }

    public var isAvailable: Bool {
        AXIsProcessTrusted() && CGPreflightListenEventAccess()
    }

    @MainActor
    @discardableResult
    public func start() -> Bool {
        guard eventTap == nil else { return true }
        guard isAvailable else { return false }
        let mask = CGEventMask(1) << CGEventType.keyDown.rawValue
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: snippetEventCallback,
            userInfo: context
        ) else {
            return false
        }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return false
        }
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    @MainActor
    public func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        runLoopSource = nil
        eventTap = nil
        withMatcher { $0.reset() }
    }

    @MainActor
    public func requestPermission() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        _ = CGRequestListenEventAccess()

        let pane = AXIsProcessTrusted()
            ? "Privacy_ListenEvent"
            : "Privacy_Accessibility"
        if let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?\(pane)"
        ) {
            NSWorkspace.shared.open(url)
        }
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }
        guard event.getIntegerValueField(.eventSourceUserData) != SnippetPasteEvent.syntheticEventMarker else {
            return Unmanaged.passUnretained(event)
        }
        let flags = event.flags
        guard
            !flags.contains(.maskCommand),
            !flags.contains(.maskControl),
            !flags.contains(.maskAlternate)
        else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if keyCode == 51 {
            withMatcher { $0.processBackspace() }
            return Unmanaged.passUnretained(event)
        }

        let characters = Self.typedCharacters(from: event)
        guard !characters.isEmpty else {
            withMatcher { $0.reset() }
            return Unmanaged.passUnretained(event)
        }
        for character in characters {
            let match = withMatcher { $0.process(character) }
            if let match {
                Task { @MainActor [weak self] in
                    await self?.expand(match)
                }
            }
        }
        return Unmanaged.passUnretained(event)
    }

    @MainActor
    private func expand(_ match: SnippetKeywordMatch) async {
        guard let snippet = store.snippet(keyword: match.keyword) else { return }
        let clipboard = NSPasteboard.general.string(forType: .string) ?? ""
        let selection = SnippetSelectionReader.selectedText()
        let rendered = SnippetPlaceholderRenderer.render(
            snippet.content,
            context: SnippetPlaceholderContext(
                clipboard: clipboard,
                selection: selection,
                date: Date(),
                uuid: UUID()
            )
        )
        guard !rendered.text.isEmpty || rendered.cursorOffsetFromEnd != nil else { return }

        let fullText = rendered.text + match.delimiter
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(fullText, forType: .string)
        try? await Task.sleep(nanoseconds: 20_000_000)

        let cursorOffset = (rendered.cursorOffsetFromEnd ?? 0) + match.delimiter.count
        do {
            try await SnippetPasteHelper.replaceTypedText(
                backspaceCount: match.keyword.count + match.delimiter.count,
                cursorOffsetFromEnd: cursorOffset
            )
            _ = try? store.recordUse(id: snippet.id)
            try? await Task.sleep(nanoseconds: 80_000_000)
            pasteboard.clearContents()
            pasteboard.setString(clipboard, forType: .string)
        } catch {
            pasteboard.clearContents()
            pasteboard.setString(clipboard, forType: .string)
        }
    }

    private func replaceKeywords(_ keywords: [String]) {
        withMatcher { $0.updateKeywords(keywords) }
    }

    private func withMatcher<Result>(
        _ operation: (inout SnippetKeywordMatcher) -> Result
    ) -> Result {
        stateLock.lock()
        defer { stateLock.unlock() }
        return operation(&matcher)
    }

    private static func keywords(from snippets: [Snippet]) -> [String] {
        snippets.compactMap { snippet in
            let keyword = snippet.keyword?.trimmingCharacters(in: .whitespacesAndNewlines)
            return keyword?.isEmpty == false ? keyword : nil
        }
    }

    private static func typedCharacters(from event: CGEvent) -> String {
        var length = 0
        event.keyboardGetUnicodeString(
            maxStringLength: 0,
            actualStringLength: &length,
            unicodeString: nil
        )
        guard length > 0 else { return "" }
        var buffer = [UniChar](repeating: 0, count: length)
        event.keyboardGetUnicodeString(
            maxStringLength: length,
            actualStringLength: &length,
            unicodeString: &buffer
        )
        return String(utf16CodeUnits: buffer, count: length)
    }
}

private let snippetEventCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let expander = Unmanaged<SnippetExpander>.fromOpaque(userInfo).takeUnretainedValue()
    return expander.handle(type: type, event: event)
}

private enum SnippetSelectionReader {
    static func selectedText() -> String {
        let system = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            system,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success, let focusedValue else {
            return ""
        }
        let focused = focusedValue as! AXUIElement
        var selectedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            focused,
            kAXSelectedTextAttribute as CFString,
            &selectedValue
        ) == .success else {
            return ""
        }
        return selectedValue as? String ?? ""
    }
}
