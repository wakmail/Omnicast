# Task: window management and hyper key

Feature dir name: WindowManagement and HyperKey. Upstream: src/native/window-adjust.swift (already Swift: 24 placements, halves, thirds, quarters, center, maximize, nudge and resize by 10px, using the Accessibility API on the focused window, with screen visible frame math), src/native/hyper-key-monitor.swift and src/native/hyper-key-manager (Caps Lock to Hyper via CGEvent tap and hidutil), src/renderer/src/WindowManagerPanel.tsx for the command names and icons, and src/main/main.ts for how the placements are exposed as commands (search for window-adjust).

Build in OmnicastCore/WindowManagement:
- WindowPlacement enum with all 24 cases and display names matching upstream.
- WindowAdjuster: applies a placement to the frontmost window of the frontmost app through AXUIElement. Port the geometry from window-adjust.swift faithfully, including multi display handling and the minimum size fallbacks. Expose `accessibilityGranted` and `requestAccessibility()`.
- WindowCommandsProvider: one command per placement, kind .window, keywords like "left half", icons as sfSymbols.
- Pure geometry function `frame(for placement:, in visibleFrame:, current:)` with unit tests covering halves, thirds, quarters, center, and nudges at screen edges.

Build in OmnicastCore/HyperKey:
- HyperKeyManager: enable and disable Caps Lock remapping. Use hidutil property mapping (via Process) to map Caps Lock to F18 or right control as upstream does, plus a CGEvent tap that turns the remapped key into Cmd+Ctrl+Opt+Shift when held with another key and, if tapped alone, either Escape or nothing, configurable. Port the exact behavior modes from upstream.
- A small HyperKeySettings Codable struct in your directory (mode, enabled). The integrator will fold it into AppSettings.

No UI in this task beyond nothing; settings UI comes later.
