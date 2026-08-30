# Task: clipboard history

Feature dir name: Clipboard. Port SuperCmd's clipboard manager. Upstream reference: src/main/clipboard-manager.ts (store, dedupe, pinning, image handling, limits) and src/renderer/src/ClipboardManager.tsx (UI). Native fast paste: src/native/fast-paste-addon/fast_paste.mm.

Build in OmnicastCore/Clipboard:
- ClipboardMonitor: polls NSPasteboard.general.changeCount every 0.5s on a timer, captures text, file URLs, and images (PNG data saved to files under the data dir, never inline in JSON), records the source app bundle id and name via NSWorkspace.frontmostApplication. Skips concealed and transient pasteboard types (org.nspasteboard.ConcealedType, TransientType).
- ClipboardHistoryStore: JSON index of ClipboardItem (id, kind text or image or files, preview text, file path for images, source app, created date, pinned flag). Dedupes consecutive identical text, keeps the newest 500 unpinned items, pinned never evicted. Search over preview text.
- PasteService: writes an item to the pasteboard and pastes into the previously active app by posting Cmd+V through CGEvent (keyDown and keyUp with kVK_ANSI_V and the command flag), same as upstream fast_paste. Also a plain "copy only" path.

Build in OmnicastUI/Clipboard:
- ClipboardHistoryView: a two pane layout inside the launcher panel, list on the left with search field, preview on the right (text preview or image), footer hints. Cmd+1 through Cmd+9 paste the nth visible item. Enter pastes, Cmd+Enter copies only, Cmd+P toggles pin, Cmd+Backspace deletes. Keep the view driven by an ObservableObject view model so keyboard handling can come from the panel later.

Also a ClipboardHistoryCommand (kind .clipboard, title "Clipboard History") whose execute does nothing but is the launcher entry; the integrator will route it to the view. Provide a ClipboardCommandsProvider returning that command.
