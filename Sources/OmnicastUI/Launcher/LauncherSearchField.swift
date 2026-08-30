// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

struct LauncherSearchField: NSViewRepresentable {
    @Binding var text: String
    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.delegate = context.coordinator
        field.font = LauncherTheme.Typography.searchNSFont
        field.focusRingType = .none
        field.isBezeled = false
        field.isBordered = false
        field.drawsBackground = false
        field.cell?.usesSingleLineMode = true
        DispatchQueue.main.async {
            field.window?.makeFirstResponder(field)
        }
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        if field.stringValue != text {
            field.stringValue = text
        }
        field.textColor = LauncherTheme.Palette.primaryNSColor(for: colorScheme)
        field.placeholderAttributedString = NSAttributedString(
            string: "Search for apps and commands",
            attributes: [
                .font: LauncherTheme.Typography.searchNSFont,
                .foregroundColor: LauncherTheme.Palette.secondaryNSColor(for: colorScheme)
            ]
        )
        if field.window?.firstResponder == nil {
            DispatchQueue.main.async {
                field.window?.makeFirstResponder(field)
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        private var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }
    }
}
