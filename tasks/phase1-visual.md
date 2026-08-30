# Omnicast phase 1b: make the launcher look like SuperCmd and Raycast

Read CLAUDE.md first. The launcher works but looks wrong. Your job is a visual pass on the Omnicast launcher panel only. Do not add features.

## References, these are facts
- Target look: docs/reference/supercmd-launcher.png (SuperCmd's own launcher). Match it closely.
- Current look: docs/reference/omnicast-before.png. The panel is the top center window.
- SuperCmd dark theme tokens from upstream src/renderer/styles/index.css (.dark block, line 128 onward):
  bg overlay rgba(7, 9, 13, 0.92); text primary white at 0.92; text secondary white at 0.74; border primary white at 0.08; border secondary white at 0.18; accent #4ea2ff.
- Upstream reference checkout is /Users/prestonchen/Developer/supercmd-upstream, read only. Row and list styling lives in src/renderer/src/raycast-api/list-runtime-renderers.tsx and src/renderer/styles/index.css if you want exact paddings.
- SwiftUI sources: Sources/OmnicastUI/Launcher/. AppKit panel: Sources/Omnicast/Launcher/LauncherPanel.swift.

## What is wrong now
1. Background: NSVisualEffectView .hudWindow smears the desktop into a muddy blob. Use a near opaque dark surface: a dark fill at about 0.92 alpha over a light blur (material .underWindowBackground or .popover with a dark overlay), so the panel reads as a solid dark card with only a hint of what is behind it. Follow the system appearance: dark values above, and a matching light variant (white at 0.94 with dark text) when the system is light.
2. Panel edge: add a 1pt border at white 0.08 (dark) and a continuous 12pt corner radius. Shadow is already present.
3. Search field: no rounded box. Bare text line, 20pt regular, placeholder "Search for apps and commands", 16pt horizontal padding, 56pt tall, then a 1pt divider at border primary.
4. Section headers: 11pt semibold, uppercase, secondary color, 16pt leading padding, 8pt top and 4pt bottom.
5. Rows: 40pt tall, 16pt horizontal padding, icon 24pt, title 14pt medium primary, subtitle 13pt secondary placed inline right after the title with 8pt gap (not on a second line), kind label on the far right in 12pt secondary. Selected row: white 0.10 fill (dark) with a 6pt inset from the panel edge and 8pt radius, and a 1pt border at white 0.08. No hover state changes needed.
6. Footer: 44pt tall, divider on top, left side shows the selected command icon at 16pt and title in 13pt secondary; right side shows "Open" then a key cap "Enter", then "Actions" then key caps "⌘" "K". Key caps are 11pt, monospaced digits, white 0.10 fill, 4pt radius, 20pt tall.
7. Overall width 750pt, list height fits 8 rows, total panel about 480pt.

## Checking your work
scripts/dev-screenshot.sh /tmp/omnicast-after.png builds, relaunches the app, opens the panel, and captures the screen. Run it after each meaningful change and look at the result. If the script cannot run in your sandbox (screencapture or open blocked), say so in the report and stop iterating rather than guessing; the operator will screenshot for you.

## Constraints
- Keep files under 600 lines. Split styling constants into a LauncherTheme.swift with all colors, sizes, and fonts in one place so later views reuse them.
- No dashes of any kind in prose, comments, or UI strings. Rephrase.
- swift build and swift test must pass. Do not commit. Do not edit the upstream checkout.
- Reporting "this item already matches" is acceptable.

## Report
What changed, what the screenshot shows versus the reference, remaining differences you can see, and the true swift build and swift test output.
