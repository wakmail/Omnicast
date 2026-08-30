# Extensions integration

Add `OmnicastExtensions` to the dependency list for the `Omnicast` executable target. Then add `import OmnicastExtensions` to `AppDelegate.swift`.

Retain these properties on `AppDelegate`:

```swift
private let extensionRegistry = ExtensionRegistry()
private var extensionHost: ExtensionHost?
```

After choosing an installed extension and command, replace the panel content with the host view:

```swift
let callbacks = ExtensionHostCallbacks(
    showToast: { [weak self] in self?.toastCenter.show($0) },
    showHUD: { [weak self] in self?.toastCenter.show($0) },
    closeMainWindow: { [weak self] in self?.panel?.hide(returningFocus: true) }
)
let host = try ExtensionHost(
    installedExtension: extension,
    commandName: commandName,
    directoryURL: OmnicastDataDirectory.defaultURL,
    clipboard: SystemClipboardService(),
    opener: WorkspaceOpenerService(),
    callbacks: callbacks
)
extensionHost = host
panel?.contentView = NSHostingView(rootView: ExtensionHostView(host: host))
```

Call `await extensionRegistry.install(storeSlug:)` from the extension store interface. Call `listInstalled()` to populate commands and `uninstall(slug:)` to remove an extension.

# Current limits

The JavaScript resources provide a compact React 18 compatible global runtime. They are not the official React and ReactDOM UMD distribution files. Replacing both resource files with the official 18.3.1 UMD builds is still required before claiming broad extension compatibility.

The managed test sandbox could not launch the WebKit content process, so the WebKit rendering test is explicitly skipped in that environment. Run the same test or open the fixture host from the application outside that sandbox to settle runtime rendering.

Store network access was unavailable during this run. The GitLab store manifest was parsed, but no live store archive was downloaded or executed.
