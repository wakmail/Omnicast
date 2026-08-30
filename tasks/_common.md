# Shared rules for every Omnicast task (read first)

Omnicast is a native Swift port of SuperCmd. Read CLAUDE.md and PLAN.md. Upstream reference is /Users/prestonchen/Developer/supercmd-upstream, read only, never edit. Facts, do not rediscover: Swift 6.1.2 toolchain, Swift 5 language mode, macOS 14 minimum, SwiftPM package with targets OmnicastCore (models, stores, services), OmnicastUI (SwiftUI views), Omnicast (AppKit app shell), OmnicastCoreTests.

You are one of several agents working in parallel in separate git worktrees. To avoid merge conflicts:
- Create new files only, under Sources/OmnicastCore/<YourFeature>/, Sources/OmnicastUI/<YourFeature>/, and Tests/OmnicastCoreTests/<YourFeature>/. Do not edit any existing file. If an existing type genuinely blocks you, write the needed change into INTEGRATION-<yourfeature>.md at the repo root and work around it locally (for example with a protocol or extension in your own directory).
- Do not edit Package.swift, AppDelegate.swift, LauncherView.swift, or the launcher panel unless your task says so.
- Do not wire your feature into the running app. Expose a public entry point (a CommandProvider, a store, a view) and describe in INTEGRATION-<yourfeature>.md exactly what the integrator must add to AppDelegate to turn it on, in a few lines.

Existing core API you build on (in Sources/OmnicastCore):
- `protocol Command: Sendable { id, title, subtitle, icon: CommandIcon, keywords, kind: CommandKind, resourceURL; @MainActor func execute(context: CommandContext) async throws }`
- `enum CommandIcon { sfSymbol(String), appBundle(URL), image(URL), emoji(String) }`
- `enum CommandKind: String { application, system, clipboard, snippet, quicklink, script, file, window, ai, extensionCommand }`
- `protocol CommandProvider: Sendable { func commands() async -> [any Command] }`
- `struct CommandContext { clipboard: ClipboardService, opener: OpenerService, toasts: ToastService }` with `ClipboardService { readText, writeText }`, `OpenerService { open(URL) async throws, reveal(URL) }`, `ToastService { show(String) }`, all @MainActor.
- `SettingsStore` (ObservableObject, JSON at `OmnicastDataDirectory.defaultURL`), `FrecencyStore`, `SearchRanker`.
- Data directory: `OmnicastDataDirectory.defaultURL` is ~/Library/Application Support/Omnicast. Every store takes a `directoryURL` init parameter so tests can use a temp dir.

Conventions:
- GPL header on every Swift file: `// SPDX-License-Identifier: GPL-3.0-or-later`
- Files under 600 lines, split by feature.
- No dashes of any kind (em, en, hyphen) in prose, comments, docs, or UI strings. Rephrase. Code identifiers exempt.
- Unit tests for every store and pure function, using temp directories. `swift build` and `swift test` must pass; report their true output including failures.
- Do not commit. Leave changes unstaged. Do not run scripts/build-app.sh or scripts/dev-screenshot.sh. Do not write outside the worktree except temp dirs.
- Saying that a part is not achievable in this run, and why, is acceptable. Do not stub silently.

Report at the end: what was built, integration notes, true build and test output, confirmed versus suspected problems and what would settle each suspicion.
