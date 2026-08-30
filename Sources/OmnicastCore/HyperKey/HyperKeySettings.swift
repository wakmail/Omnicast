// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum HyperKeyMode: String, Codable, CaseIterable, Sendable {
    case escape
    case nothing
    case toggle
}

public struct HyperKeySettings: Codable, Equatable, Sendable {
    public var mode: HyperKeyMode
    public var enabled: Bool

    public init(mode: HyperKeyMode = .nothing, enabled: Bool = false) {
        self.mode = mode
        self.enabled = enabled
    }
}

public enum HyperKeyRemapTarget: String, Codable, CaseIterable, Sendable {
    case function18
    case rightControl
}
