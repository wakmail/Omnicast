<div align="center">
    <h1>Omnicast</h1>
    <p>A native, free launcher for macOS that runs Raycast extensions.</p>
</div>

![Platform](https://img.shields.io/badge/platform-macOS-blue?style=flat-square)
![Requirements](https://img.shields.io/badge/requirements-macOS%2014%2B-fa4e49?style=flat-square)
[![License](https://img.shields.io/badge/license-GPLv3-green?style=flat-square)](LICENSE)

> [!NOTE]
> Omnicast is a Swift port of [SuperCmd](https://github.com/SuperCmdLabs/SuperCmd) by Shobhit Bhosure, an Electron launcher that runs Raycast extensions. SuperCmd 1.x is MIT licensed and its full history is preserved in this repo. SuperCmd 2 went closed source and paid. Omnicast picks up where the open version stopped and rebuilds it as a native Mac app.

## The idea

Raycast is excellent and its extension store is the best part. It is also a company product, and the free tier is whatever the company decides it is this year. SuperCmd showed that the extension ecosystem can run outside Raycast. Omnicast takes that further: the same extensions, but in a Swift app with real macOS windows, controls, and permissions, no Electron and no bundled browser.

What that buys you:

- **Raycast extensions** install from the Raycast store and run unmodified
- **Native** AppKit and SwiftUI throughout, so it launches fast, idles at near zero, and matches the system look
- **The whole kit** from SuperCmd: app and file search, clipboard history, snippets, quick links, window tiling, hyper key, AI chat with your own provider, dictation, read aloud, notes, canvas, calendar
- **GPL 3** so it stays free for everyone, forever

## Status

Very early. The launcher shell and core commands are being built first, then the extension host, then AI and voice, then the rest. See [PLAN.md](PLAN.md) for the order and what is done. Nothing is released yet.

## Building

Requires Xcode 16.4 or newer.

    swift build
    scripts/build-app.sh

The second command assembles `Omnicast.app` in `.build-app/`.

## License

GNU GPLv3. See [LICENSE](LICENSE). Code derived from SuperCmd keeps its MIT copyright notice, see [NOTICE](NOTICE).

## Thanks

- [Shobhit Bhosure](https://github.com/shobhit99) for building SuperCmd and releasing 1.x under MIT
- The Raycast team for the extension API and the store that make this worth doing
