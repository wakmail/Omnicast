# Snippets integration

Create one `SnippetStore` during application startup. Retain one `SnippetExpander`, request permissions during onboarding, then start it after permissions are granted.

```swift
let snippetStore = try SnippetStore()
let snippetExpander = SnippetExpander(store: snippetStore)
snippetExpander.start()
```

Add `SnippetCommandsProvider` to the providers passed into `CommandRegistry`. Its callback should hide the launcher and present a window whose root view is `SnippetManagerView(store: snippetStore)`.

```swift
SnippetCommandsProvider(store: snippetStore) {
    presentSnippetManager(SnippetManagerView(store: snippetStore))
}
```

Retain both objects for the application lifetime. Refresh the command registry after snippet changes so newly created commands appear. The expander observes store changes itself.

Accessibility and Input Monitoring usage descriptions must remain present in the application metadata. If `snippetExpander.isAvailable` is false, call `requestPermission()` from an explicit onboarding action.
