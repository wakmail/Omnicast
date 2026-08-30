# Search providers integration

All implementation files are isolated in the requested feature directories. No existing application file was changed.

## AppDelegate setup

1. Create one `FileSearchIndex` and retain it for the lifetime of the application. Add `FileSearchProvider()` to the command registry. Route `omnicast://file-search` to the launcher file search presentation and pass search field changes to `updateQuery`.

2. Add `ScriptCommandsProvider()` to the command registry. Before execution, cast a selected command to `ScriptArgumentTakingCommand`, collect its declared arguments, and call `execute(arguments:context:)`. Cast to `ConfirmationRequiringCommand` before running and present confirmation when its value is true. Schedule inline commands using `refreshInterval` and use `ScriptCommandRunner.run` when the full output view needs the returned text.

3. Create `QuicklinkStore()` once and retain it. Add `QuicklinkCommandsProvider()` to the command registry. Present `QuicklinkManagerView(store:)` from the settings window. When a launcher result conforms to `ArgumentTakingCommand` and `requiresArgument` is true, collect text using `argumentPlaceholder`, then call `execute(argument:context:)`.

4. To honor the optional application bundle identifier, make the application opener conform to `ApplicationBundleOpener` and use `NSWorkspace` to open the URL with the chosen application. The command safely uses the normal opener when this conformance is absent.

5. Retain a `WebSearchBangs` value in AppDelegate. When launcher text does not select a command, call `resolve(query:)` and open the returned URL through the command context opener.

## Existing API limits

The current `Command` protocol has no argument, confirmation, inline refresh, or full output presentation contract. The feature protocols above expose those needs without changing the shared command API. The launcher integrator must perform the casts described above.
