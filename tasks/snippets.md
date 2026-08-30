# Task: snippets and expansion

Feature dir name: Snippets. Port SuperCmd's snippets. Upstream: src/main/snippet-store.ts (model, keyword triggers, dynamic placeholders like {clipboard}, {date}, {cursor}), src/native/snippet-expander.swift (the keyboard trigger monitor, this is already Swift, port it in process), src/renderer/src/SnippetManager.tsx (UI).

Build in OmnicastCore/Snippets:
- Snippet model (id, name, keyword, content, created, lastUsed) and SnippetStore (JSON, CRUD, search, import from Raycast snippet JSON export format, see upstream for the shape).
- SnippetExpander: in process CGEvent tap (needs Accessibility and Input Monitoring; expose `isAvailable` and a `requestPermission()` that opens the right System Settings pane). Watches typed characters, matches a keyword ending with a trigger, deletes the typed keyword with backspaces and types the expansion. Handles placeholders: {clipboard}, {date}, {time}, {cursor} (moves the caret back after insertion), {uuid}, {selection} where feasible. Follow the exact matching rules in the upstream Swift file.
- Placeholder rendering as a pure function with tests.

Build in OmnicastUI/Snippets:
- SnippetManagerView: list with search, detail editor (name, keyword, content), create, delete. Driven by a view model.

Provide SnippetCommandsProvider: a "Search Snippets" command (kind .snippet) plus one command per snippet whose execute pastes the rendered content (write to pasteboard, then Cmd+V via CGEvent, same approach as the clipboard task; implement your own small paste helper in your directory, the integrator will unify later).
