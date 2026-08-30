// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

struct HyperKeyApplicationPicker: View {
    @Binding var bundleIdentifier: String
    @State private var applications = InstalledApplication.load()

    var body: some View {
        Picker("Application", selection: $bundleIdentifier) {
            if applications.isEmpty {
                Text("No applications found").tag("")
            } else {
                ForEach(applications) { application in
                    Label {
                        Text(application.name)
                    } icon: {
                        Image(nsImage: application.icon)
                    }
                    .tag(application.bundleIdentifier)
                }
            }
        }
        .onAppear {
            if !applications.contains(where: { $0.bundleIdentifier == bundleIdentifier }),
               let first = applications.first {
                bundleIdentifier = first.bundleIdentifier
            }
        }
    }
}

private struct InstalledApplication: Identifiable {
    let bundleIdentifier: String
    let name: String
    let url: URL

    var id: String { bundleIdentifier }
    var icon: NSImage { NSWorkspace.shared.icon(forFile: url.path) }

    static func load() -> [InstalledApplication] {
        let directory = URL(fileURLWithPath: "/Applications", isDirectory: true)
        let keys: Set<URLResourceKey> = [.isApplicationKey, .nameKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return urls.compactMap { url in
            guard
                url.pathExtension.caseInsensitiveCompare("app") == .orderedSame,
                let bundle = Bundle(url: url),
                let bundleIdentifier = bundle.bundleIdentifier
            else { return nil }
            let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? url.deletingPathExtension().lastPathComponent
            return InstalledApplication(
                bundleIdentifier: bundleIdentifier,
                name: name,
                url: url
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
