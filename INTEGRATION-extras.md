# Extras integration

## Stored services

In `AppDelegate`, retain the feature services as properties. Create them inside the existing startup `do` block:

```swift
let emojiStore = try EmojiStore()
let emojiPasteService = EmojiPasteService()
let colorHistoryStore = try ColorHistoryStore()
let menuItemIndex = MenuItemIndex()
let calculatorProvider = CalculatorProvider()
```

Retain all five values. Add these providers to the command registry:

```swift
EmojiCommandsProvider()
ColorPickerCommandsProvider(store: colorHistoryStore)
MenuSearchCommandsProvider()
```

Keep the calculator provider outside the registry result list because its `commands()` method is intentionally empty.

In `showLauncher()`, call both of these before showing the panel:

```swift
emojiPasteService?.rememberFrontmostApplication()
menuItemIndex?.captureTargetApplication()
```

Connect `emojiPasteService.didWritePasteboard` to `clipboardMonitor.ignoreCurrentPasteboardContents()` in the same way as the existing paste service.

## Presented views

Add these identifiers to `makePresentingCommands`:

```swift
"emoji:search"
"color:history"
"menu:search"
```

For emoji, create `EmojiGridViewModel` with `EmojiStore`, the retained paste service, and a closure that hides the panel without returning focus. Return `EmojiGridView`, forward query changes to `updateQuery`, and forward launcher keys to `handle`.

For color history, create `ColorHistoryViewModel` with the retained store, `context.clipboard`, and a closure that hides the panel while returning focus. Return `ColorHistoryView` with `showsSearchField` set to false and forward launcher keys to `handle`.

For menu search, create `MenuSearchViewModel` with the retained index and the panel hiding closure. Apply the initial query with `updateQuery`, return `MenuSearchView`, forward query changes, and forward launcher keys to `handle`.

The `color:pick` command needs no presenter. Normal command execution hides the launcher before `NSColorSampler` opens.

## Calculator inline hook

`LauncherViewModel` needs one small shared file change. Retain the `CalculatorProvider` passed by `AppDelegate`. Whenever `query` changes, call `calculatorProvider.inlineResult(for: query)`. If it returns a command, place that command before normal ranked results. Execute it through the existing command path so Enter copies the formatted result and records the launch normally.

Do not add `CalculatorProvider` to `CommandRegistry`. Its empty command collection prevents a permanent calculator row from appearing.
