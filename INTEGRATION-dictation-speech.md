# Dictation and Speech integration

Add these retained properties to `AppDelegate`.

```swift
private var dictationPermissions: DictationPermissions?
private var dictationController: HoldToSpeakController?
private var speechEngine: (any SpeechEngine)?
```

Add this setup inside `applicationDidFinishLaunching` before creating `CommandRegistry`.

```swift
let dictationPermissions = DictationPermissions()
let dictationController = HoldToSpeakController(engine: NativeSpeechEngine())
if dictationPermissions.isGranted { try dictationController.startMonitoring() }
let speechEngine = SystemSpeechEngine(configuration: SystemSpeechConfiguration())
self.dictationPermissions = dictationPermissions
self.dictationController = dictationController
self.speechEngine = speechEngine
```

Add this entry to the provider array passed into `CommandRegistry`.

```swift
SpeechCommandsProvider(engine: speechEngine),
```

Present the two explicit permission request methods from onboarding. Start the retained controller after both requests return granted.

Create `DictationHUDViewModel` with that controller. Attach `DictationHUDView` to a small borderless panel and show the panel whenever the published HUD state is not idle.

Create either `SystemSpeechEngine` with values mapped into `SystemSpeechConfiguration`, or `ElevenLabsEngine` with `SpeechKeyStore`. Add `SpeechCommandsProvider` to the provider list passed into `CommandRegistry`.

Retain the speech engine and provider for the life of `AppDelegate`. Add settings UI for system voice and rate plus the ElevenLabs key and voice identifier when those settings become available.

Add `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` to `Resources/Info.plist` before requesting either permission. The current file does not contain those required keys.
