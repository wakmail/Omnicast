// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

struct LauncherSearchField: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.delegate = context.coordinator
        field.placeholderString = "Search commands"
        field.font = .systemFont(ofSize: 22, weight: .regular)
        field.focusRingType = .none
        field.bezelStyle = .roundedBezel
        field.sendsSearchStringImmediately = true
        DispatchQueue.main.async {
            field.window?.makeFirstResponder(field)
        }
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        if field.stringValue != text {
            field.stringValue = text
        }
        if field.window?.firstResponder == nil {
            DispatchQueue.main.async {
                field.window?.makeFirstResponder(field)
            }
        }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        private var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            text.wrappedValue = field.stringValue
        }
    }
}
