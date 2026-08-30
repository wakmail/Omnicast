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
        let windowModeRaw = trimmed(
            preferences?.preferencesAppearance?.raycastPreferredWindowMode
        )
        let navigationStyleRaw = trimmed(
            preferences?.preferencesAdvanced?.navigationCommandStyleIdentifierKey
        )
        let timeoutRaw = preferences?.preferencesAdvanced?.popToRootTimeout
        let disabledKeys = disabledCommandKeys(in: backup)
        let found = (windowModeRaw.isEmpty ? 0 : 1)
            + (navigationStyleRaw.isEmpty ? 0 : 1)
            + (timeoutRaw == nil ? 0 : 1)
            + disabledKeys.count
        guard selections.contains(.settings) else {
            appendCategorySkip(.settings, count: found, issues: &issues)
            return categoryResult(.settings, selected: false, found: found, skipped: found)
        }

        var skipped = 0
        var failed = 0
        let windowMode = normalizeRaycastWindowMode(windowModeRaw)
        let navigationStyle = normalizeRaycastNavigationStyle(navigationStyleRaw)
        let timeout = timeoutRaw.flatMap { value in
            value.isFinite && value >= 0 ? value : nil
        }
        if !windowModeRaw.isEmpty, windowMode == nil {
            failed += 1
            issues.append(RaycastImportIssue(
                category: .settings,
                item: "Window mode",
                reason: "The Raycast window mode is not recognized."
            ))
        }
        if !navigationStyleRaw.isEmpty, navigationStyle == nil {
            failed += 1
            issues.append(RaycastImportIssue(
                category: .settings,
                item: "Navigation style",
                reason: "The Raycast navigation style is not recognized."
            ))
        }
        if timeoutRaw != nil, timeout == nil {
            failed += 1
            issues.append(RaycastImportIssue(
                category: .settings,
                item: "Return timeout",
                reason: "The Raycast return timeout is invalid."
            ))
        }

        var importedSettings = 0
        if windowMode != nil || navigationStyle != nil || timeout != nil {
            try settingsStore.update { settings in
                if let windowMode {
                    settings.windowMode = windowMode
                    importedSettings += 1
                }
                if let navigationStyle {
                    settings.navigationStyle = navigationStyle
                    importedSettings += 1
                }
                if let timeout {
                    settings.popToRootTimeout = timeout
                    importedSettings += 1
                }
            }
        }

        let importedDisabledKeys = try importStore.mergeDisabledCommandKeys(disabledKeys)
        let duplicateCount = disabledKeys.count - importedDisabledKeys
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
            imported: importedSettings + importedDisabledKeys,
            skipped: skipped,
            failed: failed
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
}
