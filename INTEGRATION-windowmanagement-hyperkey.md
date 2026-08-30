# Window management and Hyper key integration

Add `WindowCommandsProvider()` to the providers passed into `CommandRegistry` in `AppDelegate`.

Create one `HyperKeyManager` on the main actor from the Hyper key values folded into `AppSettings`. Keep it alive for the application lifetime. Call `enable()` after creation when the loaded setting is enabled. Call `update(_:)` whenever settings change, and call `disable()` during application termination so the Caps Lock mapping is removed.

The default mapping target is `function18`. Pass `rightControl` to the manager initializer if that compatibility mapping is preferred.

The application must request Accessibility for window movement and Input Monitoring for Hyper key events. `WindowAdjuster` and `HyperKeyManager` expose the corresponding permission checks and requests.
