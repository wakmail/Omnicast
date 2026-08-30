// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.run()
}
