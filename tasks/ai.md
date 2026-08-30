# Task: AI providers and chat

Feature dir name: AI. Upstream: src/main/ai-provider.ts (streaming for OpenAI, Anthropic, Ollama, Gemini, and OpenAI compatible endpoints, including request shapes, headers, SSE parsing, and error mapping), src/main/ai-chat-store.ts (conversation persistence), src/renderer/src/views/AiChatView.tsx and src/renderer/src/hooks/useAiChat.ts (UI behavior), src/main/safe-storage.ts (keys are stored encrypted; use the macOS Keychain here).

Build in OmnicastCore/AI:
- AIProvider protocol: `stream(messages:, model:, options:) -> AsyncThrowingStream<String, Error>` plus `listModels()`. Implementations: OpenAIProvider (also used for OpenAI compatible with a custom base URL), AnthropicProvider (messages API with SSE), GeminiProvider, OllamaProvider. Use URLSession bytes(for:) for streaming. Port the exact request bodies and SSE parsing from upstream. Default models: use whatever upstream defaults to. For Anthropic, the current model ids are claude-sonnet-5 and claude-opus-5 (facts, use them as defaults).
- AIKeyStore: Keychain backed storage of API keys per provider (SecItem with service "com.omnicast.ai"). Tests may use an in memory implementation behind a protocol.
- AIChatStore: JSON persistence of conversations (id, title, provider, model, messages with role and content and date). CRUD, search.
- SSE parsing as pure functions with unit tests using captured sample payloads for each provider (write the samples from the upstream shapes).

Build in OmnicastUI/AI:
- AIChatView: conversation list on the left, messages on the right with streaming markdown rendering (use AttributedString markdown, not a web view), input field, provider and model picker, stop button. Driven by a view model. Keep it functional over pretty; theme constants are still in flux.

Provide AICommandsProvider with "Ask AI" and "AI Chat" commands, kind .ai.
