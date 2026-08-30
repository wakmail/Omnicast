# Clipboard integration

Add `ClipboardCommandsProvider()` to the providers passed to `CommandRegistry`.

Create `ClipboardHistoryStore`, `ClipboardMonitor`, and `PasteService` properties in `AppDelegate`. Connect `pasteService.didWritePasteboard` to `monitor.ignoreCurrentPasteboardContents()`, then call `monitor.start()` after launch and `monitor.stop()` during termination.

Before each panel presentation, call `pasteService.rememberFrontmostApplication()`.

When the selected command id is `clipboard:history`, present `ClipboardHistoryView(viewModel: ClipboardHistoryViewModel(store: store, pasteService: pasteService, onDismiss: { panel.hide(returningFocus: false) }))` in the panel. The current launcher has no command routing callback, so the integrator must add that routing point to `LauncherView` or its model.
