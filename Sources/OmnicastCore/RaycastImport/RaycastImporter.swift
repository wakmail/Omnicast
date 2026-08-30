// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

@MainActor
public final class RaycastImporter {
    private let quicklinkStore: QuicklinkStore
    private let snippetStore: SnippetStore
    private let notesStore: NotesStore
    private let settingsStore: SettingsStore
    private let importStore: RaycastImportStore

    public init(
        quicklinkStore: QuicklinkStore,
        snippetStore: SnippetStore,
        notesStore: NotesStore,
        settingsStore: SettingsStore,
        importStore: RaycastImportStore? = nil
    ) throws {
        self.quicklinkStore = quicklinkStore
        self.snippetStore = snippetStore
        self.notesStore = notesStore
        self.settingsStore = settingsStore
        self.importStore = try importStore ?? RaycastImportStore(
            directoryURL: settingsStore.fileURL.deletingLastPathComponent()
        )
    }

    public func run(
        backup: RaycastBackup,
        selections: RaycastImportSelections = RaycastImportSelections()
    ) throws -> RaycastImportResult {
        var results: [RaycastImportCategory: RaycastCategoryImportResult] = [:]
        var issues: [RaycastImportIssue] = []

        results[.settings] = try importSettings(backup, selections: selections, issues: &issues)
        results[.hotkeys] = try importHotkeys(backup, selections: selections, issues: &issues)
        let extensionResult = importExtensions(backup, selections: selections, issues: &issues)
        results[.extensions] = extensionResult.result
        results[.scriptDirectories] = try importScriptDirectories(backup, selections: selections, issues: &issues)
        results[.quicklinks] = try importQuicklinks(backup, selections: selections, issues: &issues)
        results[.snippets] = try importSnippets(backup, selections: selections, issues: &issues)
        results[.notes] = try importNotes(backup, selections: selections, issues: &issues)
        results[.extensionPreferences] = try importExtensionPreferences(
            backup,
            selections: selections,
            issues: &issues
        )

        return RaycastImportResult(
            raycastVersion: backup.raycastVersion,
            categories: results,
            skippedItems: issues,
            extensionsToInstall: extensionResult.slugs
        )
    }

    private func importSettings(
        _ backup: RaycastBackup,
        selections: RaycastImportSelections,
        issues: inout [RaycastImportIssue]
    ) throws -> RaycastCategoryImportResult {
        let preferences = backup.preferencesPackage
        let unsupported: [(String, Bool)] = [
            ("Window mode", nonempty(preferences?.preferencesAppearance?.raycastPreferredWindowMode)),
            ("Navigation style", nonempty(preferences?.preferencesAdvanced?.navigationCommandStyleIdentifierKey)),
            ("Return timeout", preferences?.preferencesAdvanced?.popToRootTimeout != nil)
        ]
        let disabledKeys = disabledCommandKeys(in: backup)
        let found = unsupported.filter(\.1).count + disabledKeys.count
        guard selections.contains(.settings) else {
            appendCategorySkip(.settings, count: found, issues: &issues)
            return categoryResult(.settings, selected: false, found: found, skipped: found)
        }

        var skipped = 0
        for (item, exists) in unsupported where exists {
            skipped += 1
            issues.append(RaycastImportIssue(
                category: .settings,
                item: item,
                reason: "The current Omnicast settings model has no matching field."
            ))
        }
        let imported = try importStore.mergeDisabledCommandKeys(disabledKeys)
        let duplicateCount = disabledKeys.count - imported
        if duplicateCount > 0 {
            skipped += duplicateCount
            issues.append(RaycastImportIssue(
                category: .settings,
                item: "Disabled commands",
                reason: "\(duplicateCount) entries were already imported."
            ))
        }
        return categoryResult(
            .settings,
            selected: true,
            found: found,
            imported: imported,
            skipped: skipped
        )
    }

    private func importHotkeys(
        _ backup: RaycastBackup,
        selections: RaycastImportSelections,
        issues: inout [RaycastImportIssue]
    ) throws -> RaycastCategoryImportResult {
        let globalRaw = trimmed(
            backup.preferencesPackage?.preferencesGeneral?.raycastGlobalHotkey
        )
        let commandRecords = backup.rootSearchPackage?.rootSearch?.filter {
            !trimmed($0.hotkey).isEmpty
        } ?? []
        let found = (globalRaw.isEmpty ? 0 : 1) + commandRecords.count
        guard selections.contains(.hotkeys) else {
            appendCategorySkip(.hotkeys, count: found, issues: &issues)
            return categoryResult(.hotkeys, selected: false, found: found, skipped: found)
        }

        var imported = 0
        var skipped = 0
        var failed = 0
        if !globalRaw.isEmpty {
            if let decoded = Self.decodeHotkey(globalRaw) {
                try settingsStore.update { settings in
                    settings.hotkey = HotkeySettings(
                        keyCode: decoded.keyCode,
                        modifiers: decoded.modifiers,
                        displayName: decoded.displayName
                    )
                }
                imported += 1
            } else {
                failed += 1
                issues.append(RaycastImportIssue(
                    category: .hotkeys,
                    item: "Global hotkey",
                    reason: "The Raycast key code is not recognized."
                ))
            }
        }

        for record in commandRecords {
            let item = trimmed(record.key).isEmpty ? trimmed(record.path) : trimmed(record.key)
            guard !item.isEmpty else {
                failed += 1
                issues.append(RaycastImportIssue(
                    category: .hotkeys,
                    item: "Unnamed command",
                    reason: "The command has no identifier or path."
                ))
                continue
            }
            guard let decoded = Self.decodeHotkey(trimmed(record.hotkey)) else {
                failed += 1
                issues.append(RaycastImportIssue(
                    category: .hotkeys,
                    item: item,
                    reason: "The Raycast key code is not recognized."
                ))
                continue
            }
            let key = normalizedCommandKey(record)
            if try importStore.setCommandHotkey(decoded, commandKey: key) {
                imported += 1
            } else {
                skipped += 1
                issues.append(RaycastImportIssue(
                    category: .hotkeys,
                    item: item,
                    reason: "A command hotkey was already imported."
                ))
            }
        }
        return categoryResult(
            .hotkeys,
            selected: true,
            found: found,
            imported: imported,
            skipped: skipped,
            failed: failed
        )
    }

    private func importExtensions(
        _ backup: RaycastBackup,
        selections: RaycastImportSelections,
        issues: inout [RaycastImportIssue]
    ) -> (result: RaycastCategoryImportResult, slugs: [String]) {
        let records = backup.extensionsPackage?.extensions ?? []
        guard selections.contains(.extensions) else {
            appendCategorySkip(.extensions, count: records.count, issues: &issues)
            return (categoryResult(.extensions, selected: false, found: records.count, skipped: records.count), [])
        }
        var slugs: [String] = []
        var seen = Set<String>()
        var skipped = 0
        var failed = 0
        for record in records {
            let slug = trimmed(record.name)
            if slug.isEmpty {
                failed += 1
                issues.append(RaycastImportIssue(
                    category: .extensions,
                    item: trimmed(record.title).isEmpty ? "Unnamed extension" : trimmed(record.title),
                    reason: "The extension has no store slug."
                ))
            } else if !seen.insert(slug).inserted {
                skipped += 1
                issues.append(RaycastImportIssue(
                    category: .extensions,
                    item: slug,
                    reason: "The extension appears more than once."
                ))
            } else {
                slugs.append(slug)
            }
        }
        return (
            categoryResult(
                .extensions,
                selected: true,
                found: records.count,
                imported: slugs.count,
                skipped: skipped,
                failed: failed
            ),
            slugs
        )
    }

    private func importScriptDirectories(
        _ backup: RaycastBackup,
        selections: RaycastImportSelections,
        issues: inout [RaycastImportIssue]
    ) throws -> RaycastCategoryImportResult {
        let source = backup.scriptCommandsPackage?.scriptCommandsDirectories ?? []
        guard selections.contains(.scriptDirectories) else {
            appendCategorySkip(.scriptDirectories, count: source.count, issues: &issues)
            return categoryResult(.scriptDirectories, selected: false, found: source.count, skipped: source.count)
        }
        var valid: [String] = []
        var failed = 0
        for rawPath in source {
            let path = normalizedPath(rawPath)
            if path.isEmpty {
                failed += 1
                issues.append(RaycastImportIssue(
                    category: .scriptDirectories,
                    item: "Empty path",
                    reason: "The directory path is empty."
                ))
            } else {
                valid.append(path)
            }
        }
        let imported = try importStore.mergeScriptDirectories(valid)
        let skipped = valid.count - imported
        if skipped > 0 {
            issues.append(RaycastImportIssue(
                category: .scriptDirectories,
                item: "Script directories",
                reason: "\(skipped) entries were already imported."
            ))
        }
        return categoryResult(
            .scriptDirectories,
            selected: true,
            found: source.count,
            imported: imported,
            skipped: skipped,
            failed: failed
        )
    }

    private func importQuicklinks(
        _ backup: RaycastBackup,
        selections: RaycastImportSelections,
        issues: inout [RaycastImportIssue]
    ) throws -> RaycastCategoryImportResult {
        let source = backup.quicklinksPackage?.quicklinks ?? []
        guard selections.contains(.quicklinks) else {
            appendCategorySkip(.quicklinks, count: source.count, issues: &issues)
            return categoryResult(.quicklinks, selected: false, found: source.count, skipped: source.count)
        }
        var imported = 0
        var skipped = 0
        var failed = 0
        var existing = Set(quicklinkStore.quicklinks.map {
            deduplicationKey($0.name, $0.urlTemplate)
        })
        for record in source {
            let name = trimmed(record.name)
            let template = trimmed(record.url).replacingOccurrences(
                of: "{argument}",
                with: "{query}",
                options: .caseInsensitive
            )
            if name.isEmpty || template.isEmpty {
                failed += 1
                issues.append(RaycastImportIssue(
                    category: .quicklinks,
                    item: name.isEmpty ? "Unnamed quick link" : name,
                    reason: "A name and URL are required."
                ))
                continue
            }
            let key = deduplicationKey(name, template)
            guard existing.insert(key).inserted else {
                skipped += 1
                issues.append(RaycastImportIssue(
                    category: .quicklinks,
                    item: name,
                    reason: "A matching quick link already exists."
                ))
                continue
            }
            do {
                _ = try quicklinkStore.create(
                    name: name,
                    urlTemplate: template,
                    icon: template.localizedCaseInsensitiveContains("{query}") ? "Search" : "Globe"
                )
                imported += 1
            } catch {
                failed += 1
                existing.remove(key)
                issues.append(RaycastImportIssue(
                    category: .quicklinks,
                    item: name,
                    reason: error.localizedDescription
                ))
            }
        }
        return categoryResult(.quicklinks, selected: true, found: source.count, imported: imported, skipped: skipped, failed: failed)
    }

    private func importSnippets(
        _ backup: RaycastBackup,
        selections: RaycastImportSelections,
        issues: inout [RaycastImportIssue]
    ) throws -> RaycastCategoryImportResult {
        let source = backup.snippetsPackage?.snippets ?? []
        guard selections.contains(.snippets) else {
            appendCategorySkip(.snippets, count: source.count, issues: &issues)
            return categoryResult(.snippets, selected: false, found: source.count, skipped: source.count)
        }
        var imported = 0
        var skipped = 0
        var failed = 0
        for record in source {
            let name = trimmed(record.name)
            let content = record.text ?? ""
            let keyword = trimmed(record.keyword)
            if name.isEmpty || content.isEmpty {
                failed += 1
                issues.append(RaycastImportIssue(category: .snippets, item: name.isEmpty ? "Unnamed snippet" : name, reason: "A name and content are required."))
                continue
            }
            let duplicate = snippetStore.snippets.contains { snippet in
                snippet.name.caseInsensitiveCompare(name) == .orderedSame
                    || !keyword.isEmpty && snippet.keyword?.caseInsensitiveCompare(keyword) == .orderedSame
            }
            if duplicate {
                skipped += 1
                issues.append(RaycastImportIssue(category: .snippets, item: name, reason: "A matching name or keyword already exists."))
                continue
            }
            do {
                _ = try snippetStore.create(name: name, keyword: keyword.isEmpty ? nil : keyword, content: content)
                imported += 1
            } catch {
                failed += 1
                issues.append(RaycastImportIssue(category: .snippets, item: name, reason: error.localizedDescription))
            }
        }
        return categoryResult(.snippets, selected: true, found: source.count, imported: imported, skipped: skipped, failed: failed)
    }

    private func importNotes(
        _ backup: RaycastBackup,
        selections: RaycastImportSelections,
        issues: inout [RaycastImportIssue]
    ) throws -> RaycastCategoryImportResult {
        let source = backup.notesPackage?.notes ?? []
        guard selections.contains(.notes) else {
            appendCategorySkip(.notes, count: source.count, issues: &issues)
            return categoryResult(.notes, selected: false, found: source.count, skipped: source.count)
        }
        var imported = 0
        var skipped = 0
        var failed = 0
        for record in source {
            let title = trimmed(record.title)
            let text = trimmed(record.text)
            if title.isEmpty && text.isEmpty {
                failed += 1
                issues.append(RaycastImportIssue(category: .notes, item: "Empty note", reason: "A title or content is required."))
                continue
            }
            let body = noteBody(title: title, text: text)
            if notesStore.notes.contains(where: { $0.body.trimmingCharacters(in: .whitespacesAndNewlines) == body.trimmingCharacters(in: .whitespacesAndNewlines) }) {
                skipped += 1
                issues.append(RaycastImportIssue(category: .notes, item: title.isEmpty ? Note.title(from: body) : title, reason: "A matching note already exists."))
                continue
            }
            do {
                _ = try notesStore.create(body: body, pinned: record.pinned == true)
                imported += 1
            } catch {
                failed += 1
                issues.append(RaycastImportIssue(category: .notes, item: title.isEmpty ? "Untitled Note" : title, reason: error.localizedDescription))
            }
        }
        return categoryResult(.notes, selected: true, found: source.count, imported: imported, skipped: skipped, failed: failed)
    }

    private func importExtensionPreferences(
        _ backup: RaycastBackup,
        selections: RaycastImportSelections,
        issues: inout [RaycastImportIssue]
    ) throws -> RaycastCategoryImportResult {
        let extensions = backup.extensionsPackage?.extensions ?? []
        let found = extensions.reduce(0) { count, item in
            count + (item.prefs?.filter(\.hasValue).count ?? 0)
        }
        guard selections.contains(.extensionPreferences) else {
            appendCategorySkip(.extensionPreferences, count: found, issues: &issues)
            return categoryResult(.extensionPreferences, selected: false, found: found, skipped: found)
        }
        var imported = 0
        var skipped = 0
        var failed = 0
        for item in extensions {
            let slug = trimmed(item.name)
            for preference in item.prefs ?? [] where preference.hasValue {
                let name = trimmed(preference.name)
                guard !slug.isEmpty, !name.isEmpty, let value = preference.value else {
                    failed += 1
                    issues.append(RaycastImportIssue(category: .extensionPreferences, item: name.isEmpty ? "Unnamed preference" : name, reason: "An extension slug and preference name are required."))
                    continue
                }
                let count = try importStore.mergeExtensionPreferences([name: value], extensionSlug: slug)
                if count == 1 {
                    imported += 1
                } else {
                    skipped += 1
                    issues.append(RaycastImportIssue(category: .extensionPreferences, item: "\(slug) \(name)", reason: "A stored preference already has this name."))
                }
            }
        }
        return categoryResult(.extensionPreferences, selected: true, found: found, imported: imported, skipped: skipped, failed: failed)
    }

    private func disabledCommandKeys(in backup: RaycastBackup) -> [String] {
        var keys = backup.scriptCommandsPackage?.disabledCommands ?? []
        for item in backup.extensionsPackage?.extensions ?? [] {
            let slug = trimmed(item.name)
            guard !slug.isEmpty else { continue }
            for command in item.commands ?? [] where command.enabled == false {
                let name = trimmed(command.name)
                if !name.isEmpty { keys.append("ext-\(slug)-\(name)") }
            }
        }
        return keys.map(trimmed).filter { !$0.isEmpty }
    }

    private func normalizedCommandKey(_ record: RaycastRootSearchRecord) -> String {
        let key = trimmed(record.key)
        let builtin: [String: String] = [
            "builtin_command_clipboardHistory": "system-clipboard-manager",
            "builtin_command_createScriptCommand": "system-create-script-command",
            "builtin_command_developer_manageExtensions": "system-open-extensions-settings",
            "builtin_command_extensionStore": "system-open-extension-store",
            "builtin_command_lockScreen": "system-lock-screen",
            "builtin_command_openCamera": "system-camera",
            "builtin_command_raycastNotes_ask": "system-search-notes",
            "builtin_command_searchEmoji": "system-emoji-picker"
        ]
        if let mapped = builtin[key] { return mapped }
        if key.hasPrefix("extension_") {
            let body = String(key.dropFirst("extension_".count))
            if let separator = body.firstIndex(of: ".") {
                let slug = String(body[..<separator])
                let remainder = String(body[body.index(after: separator)...])
                let command = remainder.components(separatedBy: "__").first ?? remainder
                if !slug.isEmpty && !command.isEmpty { return "ext-\(slug)-\(command)" }
            }
        }
        if key.hasPrefix("raycastScript_") {
            return "script:\(normalizedPath(String(key.dropFirst("raycastScript_".count))))"
        }
        if !key.isEmpty { return key }
        return "path:\(normalizedPath(trimmed(record.path)))"
    }

    private func normalizedPath(_ raw: String) -> String {
        let value = trimmed(raw)
        if value.hasPrefix("~/") {
            return NSString(string: "~/" + value.dropFirst(2)).expandingTildeInPath
        }
        return value.isEmpty ? "" : URL(fileURLWithPath: value).standardizedFileURL.path
    }

    private func noteBody(title: String, text: String) -> String {
        guard !title.isEmpty else { return text }
        let contentTitle = text.split(separator: "\n", omittingEmptySubsequences: false).first.map(String.init) ?? ""
        if Note.title(from: contentTitle).caseInsensitiveCompare(title) == .orderedSame {
            return text
        }
        return text.isEmpty ? "# \(title)" : "# \(title)\n\n\(text)"
    }

    private func deduplicationKey(_ name: String, _ template: String) -> String {
        "\(trimmed(name).lowercased())::\(trimmed(template).lowercased())"
    }

    private func trimmed(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func nonempty(_ value: String?) -> Bool {
        !trimmed(value).isEmpty
    }

    private func appendCategorySkip(
        _ category: RaycastImportCategory,
        count: Int,
        issues: inout [RaycastImportIssue]
    ) {
        guard count > 0 else { return }
        issues.append(RaycastImportIssue(
            category: category,
            item: category.title,
            reason: "This category was not selected."
        ))
    }

    private func categoryResult(
        _ category: RaycastImportCategory,
        selected: Bool,
        found: Int,
        imported: Int = 0,
        skipped: Int = 0,
        failed: Int = 0
    ) -> RaycastCategoryImportResult {
        RaycastCategoryImportResult(
            category: category,
            selected: selected,
            found: found,
            imported: imported,
            skipped: skipped,
            failed: failed
        )
    }

    private static let keyNames: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2", 20: "3",
        21: "4", 22: "6", 23: "5", 24: "Equals", 25: "9", 26: "7", 27: "Minus", 28: "8", 29: "0",
        30: "Right Bracket", 31: "O", 32: "U", 33: "Left Bracket", 34: "I", 35: "P", 36: "Return",
        37: "L", 38: "J", 39: "Quote", 40: "K", 41: "Semicolon", 42: "Backslash", 43: "Comma", 44: "Slash",
        45: "N", 46: "M", 47: "Period", 48: "Tab", 49: "Space", 50: "Grave", 51: "Backspace",
        53: "Escape", 71: "Clear", 76: "Enter", 96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
        101: "F9", 103: "F11", 105: "F13", 106: "F16", 107: "F14", 109: "F10", 111: "F12",
        113: "F15", 114: "Insert", 115: "Home", 116: "Page Up", 117: "Delete", 118: "F4", 119: "End",
        120: "F2", 121: "Page Down", 122: "F1", 123: "Left", 124: "Right", 125: "Down", 126: "Up"
    ]

    private static func decodeHotkey(_ value: String) -> RaycastImportedCommandHotkey? {
        let parts = value.split(separator: "-").map(String.init).filter { !$0.isEmpty }
        guard let rawCode = parts.last, let keyCode = UInt32(rawCode), let keyName = keyNames[keyCode] else {
            return nil
        }
        var modifiers: UInt32 = 0
        var names: [String] = []
        for rawModifier in parts.dropLast() {
            switch rawModifier.lowercased() {
            case "command", "cmd": modifiers |= 256; names.append("Command")
            case "shift": modifiers |= 512; names.append("Shift")
            case "option", "alt": modifiers |= 2_048; names.append("Option")
            case "control", "ctrl": modifiers |= 4_096; names.append("Control")
            case "fn", "function": names.append("Function")
            default: continue
            }
        }
        names.append(keyName)
        return RaycastImportedCommandHotkey(
            keyCode: keyCode,
            modifiers: modifiers,
            displayName: names.joined(separator: " ")
        )
    }
}
