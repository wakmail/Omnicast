# Omnicast

Native macOS launcher, a Swift port of SuperCmd (Electron). GPL 3, see NOTICE for the MIT credit to SuperCmd.
Upstream reference checkout: ~/Developer/supercmd-upstream (read only, never edit).

## Architecture
- AppKit shell (NSPanel launcher window, global hotkeys, key event routing) hosting SwiftUI views.
- Swift Package at the root. `swift build` produces the executable; `scripts/build-app.sh` wraps it into Omnicast.app in .build-app/.
- Modules: OmnicastCore (models, stores, services, no UI), OmnicastUI (SwiftUI views), Omnicast (app entry, AppKit shell), Helpers (native helper executables lifted from SuperCmd).
- Extensions: Raycast extensions run in a JavaScriptCore host; UI is rendered through a WKWebView bridge first, native SwiftUI per component later.

## Rules
- No Electron, no Node at runtime. WebKit only for the extension bridge.
- Settings and data live in ~/Library/Application Support/Omnicast/.
- Keep files under ~600 lines; split by feature.
- Tests: `swift test`. Run them before reporting done.
- Writing style: no dashes in prose, docs, UI strings, or commit messages. Rephrase instead.
- Never commit on main. Codex runs never commit at all.

See PLAN.md for phases and status.
