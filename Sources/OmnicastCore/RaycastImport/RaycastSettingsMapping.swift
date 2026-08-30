// SPDX-License-Identifier: GPL-3.0-or-later

func normalizeRaycastWindowMode(_ value: String) -> LauncherWindowMode? {
    switch value.lowercased() {
    case "compact": .compact
    case "default", "expanded", "standard": .standard
    default: nil
    }
}

func normalizeRaycastNavigationStyle(_ value: String) -> LauncherNavigationStyle? {
    switch value.lowercased() {
    case "vim": .vim
    case "macos": .macOS
    default: nil
    }
}
