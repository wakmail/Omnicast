// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

public struct VisualEffectBackground: NSViewRepresentable {
    public var material: NSVisualEffectView.Material

    public init(material: NSVisualEffectView.Material = .underWindowBackground) {
        self.material = material
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    public func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}
