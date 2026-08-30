# Raycast Import Integration

## App setup

Create the import store and importer beside the existing stores in `AppDelegate`.

```swift
let raycastImportStore = try RaycastImportStore()
let raycastImporter = try RaycastImporter(
    quicklinkStore: quicklinkStore,
    snippetStore: snippetStore,
    notesStore: notesStore,
    settingsStore: settingsStore,
    importStore: raycastImportStore
)
```

Add `RaycastImportCommandProvider()` to the providers passed to `CommandRegistry`.

Pass `raycastImporter` into `makeLauncherPresentingCommands` and merge its presenter before returning the dictionary.

```swift
presenters.merge(RaycastImportPresentation.presenters(importer: raycastImporter)) {
    _, feature in feature
}
```

## Settings hook

Pass the same importer into `SettingsWindowController` and add this tab to `SettingsTabsView` if the import should also appear in settings.

```swift
ImportView(viewModel: RaycastImportViewModel(importer: raycastImporter))
    .tabItem { Label("Raycast Import", systemImage: "square.and.arrow.down") }
```

## Imported command data

`RaycastImportStore.data` contains script directories, command hotkeys, and disabled command keys. The script command provider and launcher shortcut resolver must merge those values into their existing sources. Extension preferences already use the `extension-preferences` directory read by `ExtensionPersistence`.

The importer returns extension slugs in `extensionsToInstall`. The integrator can show a confirmation and pass each accepted slug to `ExtensionRegistry.install(storeSlug:)`.

## Format details

Raycast backups use OpenSSL AES 256 CBC with no salt and PKCS 7 padding. The password is expanded with the legacy OpenSSL bytes to key procedure using SHA 256. The decrypted bytes contain a gzip stream within the first 64 bytes. That stream expands to one JSON payload.

CryptoKit performs the SHA 256 key derivation. CommonCrypto performs AES CBC because CryptoKit does not expose CBC mode.
