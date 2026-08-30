# Task: file search, script commands, quick links, web search

Feature dir names: FileSearch, ScriptCommands, Quicklinks, WebSearch. Upstream: src/main/file-search-index.ts, src/renderer/src/FileSearchExtension.tsx, src/main/script-command-runner.ts and the script command parsing part of src/main/commands.ts (Raycast script command header format: `@raycast.schemaVersion`, `title`, `mode` (silent, compact, fullOutput, inline), `packageName`, `icon`, `argument1..3`, `needsConfirmation`, `refreshTime`), src/main/quicklink-store.ts and src/renderer/src/QuickLinkManager.tsx, src/main/web-search-bangs.ts.

Build in OmnicastCore/FileSearch:
- FileSearchIndex: NSMetadataQuery (Spotlight) backed search with a fallback directory walk for protected roots the user adds. Results carry URL, display name, kind, modified date. Debounced query API. Respect the exclusion list from upstream (node_modules, .git, Library caches).
- FileSearchCommand (kind .file, "Search Files") and a provider.

Build in OmnicastCore/ScriptCommands:
- ScriptCommandParser: parses the Raycast script command header comments into a ScriptCommand struct. Unit tests with real examples from the Raycast script commands repo format.
- ScriptCommandRunner: runs the script with Process, captures stdout and stderr, respects mode (silent shows nothing, compact shows the last line as a toast, fullOutput returns full text, inline is the refreshable one liner). Honors the shebang and PATH from the user's login shell.
- ScriptCommandsProvider: scans the configured script directories (default ~/Library/Application Support/Omnicast/scripts) and returns commands of kind .script.

Build in OmnicastCore/Quicklinks:
- Quicklink model (id, name, url template with {query} placeholder, open with app bundle id optional, icon) and QuicklinkStore (JSON, CRUD, import from Raycast quicklink JSON export).
- QuicklinkCommandsProvider: one command per quicklink, kind .quicklink. Commands with {query} need an argument; expose `requiresArgument` on the command via a protocol `ArgumentTakingCommand` in your directory and describe it in INTEGRATION.

Build in OmnicastCore/WebSearch:
- WebSearchBangs: port the bang table (!g, !yt, !gh, and the rest) and a `resolve(query:) -> URL?` plus a default search engine fallback. Tests.

Build in OmnicastUI/Quicklinks: QuicklinkManagerView (list, create, edit, delete) driven by a view model.
