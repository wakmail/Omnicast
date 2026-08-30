// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public func shouldPopLauncherToRoot(
    hiddenAt: Date?,
    shownAt: Date,
    timeout: TimeInterval
) -> Bool {
    guard timeout > 0, let hiddenAt else { return false }
    return shownAt.timeIntervalSince(hiddenAt) > timeout
}
