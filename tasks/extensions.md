# Task: Raycast extension host, first slice

Feature dir name: Extensions. This is the start of phase 2. You may add ONE new SwiftPM target: `OmnicastExtensions` (library, depends on OmnicastCore) with sources under Sources/OmnicastExtensions/ and tests under Tests/OmnicastExtensionsTests/. This is the one task allowed to edit Package.swift, and only to add that target and test target. Touch nothing else outside your directories.

Goal for this run: install a Raycast extension from the store and run one of its commands end to end inside a WKWebView, with the extension's JavaScript executed by the web view's own engine and the @raycast/api surface provided by a bundled JavaScript shim. Native rendering comes later; for now the extension's React tree renders as HTML inside the web view.

Upstream is the map. Read these before writing code:
- src/main/extension-registry.ts: how extensions are discovered and installed from the Raycast store (the store API endpoints, the download and unpack format, package.json command manifest, preferences schema). Port the install and manifest parsing.
- src/main/extension-runner.ts: how a command is bundled with esbuild and executed with a require shim. We do not have esbuild at runtime; instead, ship extensions as they come from the store (they are prebuilt bundles per command) and load the command's built JS file. Find in the registry code which file is executed per command.
- src/renderer/src/raycast-api/: the web @raycast/api runtime. Reuse its approach; the shim you bundle can be a copy of the relevant parts if the build is simple enough, otherwise write a minimal one covering List, List.Item, List.Section, Detail (markdown), ActionPanel, Action, Action.OpenInBrowser, Action.CopyToClipboard, showToast, showHUD, getPreferenceValues, LocalStorage, Clipboard, open, environment, and closeMainWindow. Everything else can throw a clear "not yet supported" error.
- src/main/extension-api.ts and preload.ts: the message contract between the extension side and the host. Define your own JSON message protocol between the web view and Swift via WKScriptMessageHandler and evaluateJavaScript.

Build in Sources/OmnicastExtensions:
- ExtensionManifest (Codable for the store package.json shape), ExtensionRegistry (list installed, install by store slug, uninstall, storage at data dir/extensions), RaycastStoreClient (search and fetch metadata, download).
- ExtensionHostView (NSViewRepresentable around WKWebView) and ExtensionHost (loads the shim plus the command bundle, routes bridge messages).
- Host bridges implemented in Swift: LocalStorage (JSON per extension), preferences (JSON per extension), Clipboard, open, toast and HUD (callbacks the integrator hooks to the launcher's toast center), closeMainWindow (callback).
- A tiny React and react-dom presence: the store bundles expect `react` and `@raycast/api` as externals. Bundle React 18 UMD builds as resources (no network at runtime). Note the license files.

Tests: manifest parsing from a real store package.json, registry install and uninstall against a temp dir using a fixture bundle you create, bridge message encoding and decoding.

Report which real store extension you tested with and how far it got.
