// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import OmnicastExtensions
import OmnicastUI
import SwiftUI

@MainActor
func makeLauncherPresentingCommands(
    context: CommandContext,
    clipboardStore: ClipboardHistoryStore,
    pasteService: PasteService,
    fileSearchIndex: FileSearchIndex,
    notesStore: NotesStore,
    calendarService: CalendarService,
    emojiStore: EmojiStore,
    emojiPasteService: EmojiPasteService,
    colorHistoryStore: ColorHistoryStore,
    menuItemIndex: MenuItemIndex,
    onHide: @escaping (Bool) -> Void,
    raycastImporter: RaycastImporter
) -> [String: LauncherCommandPresenter] {
    var presenters: [String: LauncherCommandPresenter] = [
        "clipboard:history": { _, query in
            let model = ClipboardHistoryViewModel(
                store: clipboardStore,
                pasteService: pasteService,
                onDismiss: { onHide(false) }
            )
            model.query = query
            return LauncherPresentedView(
                title: "Clipboard History",
                content: AnyView(ClipboardHistoryView(
                    viewModel: model,
                    showsChrome: false
                )),
                initialQuery: query,
                onQueryChange: { [weak model] in model?.query = $0 },
                onKey: { [weak model] key in
                    guard let model else { return false }
                    switch key {
                    case .moveUp: model.handle(.moveSelectionUp)
                    case .moveDown: model.handle(.moveSelectionDown)
                    case .enter: model.handle(.pasteSelected)
                    case .commandEnter: model.handle(.copySelected)
                    default: return false
                    }
                    return true
                }
            )
        },
        "file-search": { _, query in
            let model = FileSearchViewModel(
                index: fileSearchIndex,
                context: context,
                onOpen: { onHide(true) }
            )
            model.updateQuery(query)
            return LauncherPresentedView(
                title: "Files",
                content: AnyView(FileSearchView(model: model)),
                initialQuery: query,
                onQueryChange: { [weak model] in model?.updateQuery($0) },
                onKey: { [weak model] key in model?.handle(key) ?? false }
            )
        },
        "emoji:search": { _, query in
            let model = EmojiGridViewModel(
                store: emojiStore,
                pasteService: emojiPasteService,
                onDismiss: { onHide(false) }
            )
            model.updateQuery(query)
            return LauncherPresentedView(
                title: "Emoji",
                content: AnyView(EmojiGridView(model: model)),
                initialQuery: query,
                onQueryChange: { [weak model] in model?.updateQuery($0) },
                onKey: { [weak model] key in model?.handle(key) ?? false }
            )
        },
        "color:history": { _, _ in
            let model = ColorHistoryViewModel(
                store: colorHistoryStore,
                clipboard: context.clipboard,
                onDismiss: { onHide(true) }
            )
            return LauncherPresentedView(
                title: "Color History",
                content: AnyView(ColorHistoryView(model: model)),
                showsSearchField: false,
                initialQuery: "",
                onKey: { [weak model] key in model?.handle(key) ?? false }
            )
        },
        "menu:search": { _, query in
            let model = MenuSearchViewModel(
                index: menuItemIndex,
                onDismiss: { onHide(false) }
            )
            model.updateQuery(query)
            return LauncherPresentedView(
                title: "Menu Items",
                content: AnyView(MenuSearchView(model: model)),
                initialQuery: query,
                onQueryChange: { [weak model] in model?.updateQuery($0) },
                onKey: { [weak model] key in model?.handle(key) ?? false }
            )
        }
    ]
    presenters.merge(NotesLauncherPresentation.presenters(store: notesStore)) {
        _, feature in feature
    }
    presenters.merge(CalendarLauncherPresentation.presenters(service: calendarService)) {
        _, feature in feature
    }
    presenters.merge(RaycastImportPresentation.presenters(importer: raycastImporter)) { _, feature in feature }
    return presenters
}
