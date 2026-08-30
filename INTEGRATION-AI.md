# AI integration

The feature is complete but is not connected to the application shell.

In `AppDelegate`, retain an `AIChatStore`, an `AIChatViewModel`, and an `NSWindow`. Create the key store and providers after the existing stores are created:

```swift
let aiKeys = AIKeyStore()
let aiChats = try AIChatStore()
let aiProviders: [any AIProvider] = [
    OpenAIProvider(keyStore: aiKeys),
    AnthropicProvider(keyStore: aiKeys),
    GeminiProvider(keyStore: aiKeys),
    OllamaProvider()
]
let aiViewModel = AIChatViewModel(store: aiChats, providers: aiProviders)
```

Create an `NSWindow` whose content view is `NSHostingView(rootView: AIChatView(viewModel: aiViewModel))`. In the command registry provider array, add this entry and make the closure show that window:

```swift
AICommandsProvider { [weak self] destination in
    self?.showAIChat(destination)
}
```

For `AICommandDestination.ask`, call `newChat()` before showing the window. For `AICommandDestination.chat`, preserve the selected conversation. Store keys with `AIKeyStore.setAPIKey(_:for:)` from the settings interface. Add a second `OpenAIProvider` with `compatible: true` and the configured base URL when custom endpoints are enabled.

No package manifest change is needed because SwiftPM discovers every new source file automatically.
