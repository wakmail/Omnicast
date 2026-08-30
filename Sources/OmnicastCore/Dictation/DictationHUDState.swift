// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum DictationHUDState: Equatable, Sendable {
    case idle
    case listening(level: Double)
    case transcribing

    public static func listening(normalizing level: Double) -> Self {
        .listening(level: min(1, max(0, level)))
    }
}
