# Omnicast phase 1a: project scaffold and launcher shell

You are implementing the first slice of Omnicast, a native Swift port of SuperCmd. Read CLAUDE.md and PLAN.md in this repo first. Upstream reference is at /Users/prestonchen/Developer/supercmd-upstream (read only; never edit it). These facts are established, do not rediscover them:

- Toolchain: Swift 6.1.2, Xcode 16.4, macOS 15.7. Target macOS 14 minimum.
- No Electron, no Node at runtime. AppKit shell hosting SwiftUI views.
- Package layout (create it): Swift Package at repo root named Omnicast with targets
  - OmnicastCore (library): models, stores, services, no UI imports beyond Foundation and AppKit where unavoidable
  - OmnicastUI (library): SwiftUI views, depends on OmnicastCore
  - Omnicast (executable): @main NSApplicationDelegate, NSPanel launcher window, global hotkey, menu bar item, depends on both
  - OmnicastCoreTests (test target)
- scripts/build-app.sh: runs swift build -c release, assembles .build-app/Omnicast.app with Info.plist (bundle id com.omnicast.app, LSUIElement true, name Omnicast, version 0.1.0), copies the executable, ad hoc codesigns with entitlements. Do not run this script yourself; only swift build and swift test.
- Data dir: ~/Library/Application Support/Omnicast/.

## Deliver in this run

1. The package, targets, build script, Info.plist, Resources/Omnicast.entitlements, and GPL 3 file headers on every Swift file (short SPDX style header: `// SPDX-License-Identifier: GPL-3.0-or-later`).
2. Launcher shell in the Omnicast target:
   - LauncherPanel: NSPanel subclass, nonactivating, floating level, borderless with rounded corners, becomes key, hides on Escape and on losing focus, remembers the previously active app so actions can return focus to it.
   - HotkeyManager: global hotkey via Carbon RegisterEventHotKey (default Option+Space), configurable through settings.
   - Menu bar NSStatusItem with Open, Settings, Quit.
   - Key routing: arrow keys, Enter, Escape, Cmd+K, Cmd+, reach the SwiftUI view through an observable LauncherKeyEvents object, not through SwiftUI focus, because SwiftUI focus is unreliable in nonactivating panels.
3. OmnicastCore:
   - Command protocol: id, title, subtitle, icon (enum: sfSymbol, appBundle URL, image URL, emoji), keywords, kind, and an execute(context) async throws. CommandContext gives access to services (clipboard, opener, toasts).
   - CommandProvider protocol: async commands() -> [Command]; a CommandRegistry that aggregates providers and caches.
   - Providers for this run: ApplicationsProvider (scan /Applications, ~/Applications, /System/Applications, /System/Library/CoreServices for .app bundles, read display name and icon lazily) and SystemCommandsProvider (Sleep, Restart, Shut Down, Lock Screen, Log Out, Empty Trash, Show Desktop; use NSAppleScript or `pmset`/`osascript` like upstream src/main/main.ts does; look there for the exact commands).
   - Fuzzy search: port the ranking approach from upstream src/shared/root-search-ranking-state.ts and src/renderer/src/hooks/useLauncherCommandModel.ts (frecency plus substring and initials matching). Keep it in one file, SearchRanker.swift, with unit tests.
   - SettingsStore: Codable AppSettings persisted as JSON at the data dir, with hotkey, theme, and launch at login. Use ServiceManagement SMAppService for launch at login.
   - FrecencyStore: records launches, persisted JSON.
4. OmnicastUI:
   - LauncherView: search field at top, results list, footer showing selected item and hint for Enter and Cmd+K. Visual target is Raycast: 750pt wide, rows 40pt, section headers, glass material background (NSVisualEffectView via representable, material .hudWindow or .popover).
   - Row view with icon, title, subtitle, right side kind label.
   - Action panel popover for Cmd+K listing actions for the selected command (Open, Show in Finder, Copy path for apps).
   - Toast overlay (bottom of panel, auto dismiss).
5. Tests: SearchRanker (ordering, initials, empty query), SettingsStore round trip, FrecencyStore ordering. Use a temp directory for stores in tests.

## Constraints

- Keep files under 600 lines; split by feature.
- Writing style in comments, docs, and UI strings: no dashes of any kind (em, en, hyphen) in prose. Rephrase. Identifiers and code are exempt.
- Swift 6 language mode is fine but if strict concurrency errors are eating time, set swiftLanguageVersions to v5 in Package.swift and say so in the report.
- Do not commit. Leave changes unstaged.
- Do not touch /Users/prestonchen/Developer/supercmd-upstream.
- Do not run scripts/build-app.sh or anything that writes outside this repo except ~/Library/Application Support/Omnicast during tests (prefer temp dirs).
- It is acceptable to report that some item is not achievable in this run; say which and why rather than stubbing silently.

## Report

At the end, print: what was built, `swift build` and `swift test` true output (including failures), anything stubbed, and confirmed vs suspected problems with what would settle each suspicion.
