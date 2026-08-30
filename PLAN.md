# Omnicast plan

Swift port of SuperCmd 1.0.26. Upstream reference: ~/Developer/supercmd-upstream.

## Phase 1: core launcher (done except polish)
- SwiftPM package, app bundling script, Info.plist, entitlements, GPL headers
- AppKit shell: NSPanel launcher window, global hotkey (default Option+Space), show/hide, key routing
- SwiftUI launcher: search field, results list, detail pane, action panel (Cmd+K), toasts, HUD
- Command model: app search (Spotlight metadata + /Applications scan), system commands, script commands (Raycast script command format), quicklinks, web search bangs
- Settings store (JSON in ~/Library/Application Support/Omnicast), settings window
- Clipboard history (poll NSPasteboard, store, Cmd+1 to 9 paste)
- Snippets (store, expander lifted from upstream snippet-expander.swift)
- Window tiling (lifted from window-adjust.swift), hyper key (lifted from hyper-key-monitor.swift)
- File search (indexed, protected roots)
- Menu bar item, launch at login, onboarding permissions flow (Accessibility, Input Monitoring)

## Phase 2: Raycast extension host (in progress: WKWebView host renders the kill-process fixture; store install works through the SuperCmd backend)
- JavaScriptCore runtime with Node compat layer (fetch, Buffer, process, fs, path, timers, child_process)
- WKWebView bridge running upstream's web based @raycast/api shim (src/renderer/src/raycast-api)
- API bridges to Swift: Clipboard, LocalStorage, preferences, toast, HUD, open, selected text, OAuth, AI
- Extension registry: install from Raycast store, update, uninstall, preferences UI
- Later: native SwiftUI rendering per component (List, Detail, Form, Grid, ActionPanel, MenuBarExtra), retiring the web bridge

## Phase 3: AI and voice (AI providers, key store, and chat done; native dictation and read aloud in progress)
- AI providers: OpenAI, Anthropic, Ollama, Gemini, OpenAI compatible; streaming
- AI chat view, cursor prompt, Supermemory
- Dictation: native SFSpeechRecognizer, Whisper, Parakeet (lift upstream helpers)
- Read aloud: Edge TTS, ElevenLabs

## Phase 4: the rest (notes and calendar in progress)
- Notes, Canvas, Calendar (EventKit), color picker, emoji picker, calculator
- Raycast .rayconfig import
- Sparkle updater, localization (9 languages), theming and glass effects
