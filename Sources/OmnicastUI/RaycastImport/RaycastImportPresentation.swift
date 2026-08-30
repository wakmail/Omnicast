// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import SwiftUI

public enum RaycastImportPresentation {
    @MainActor
    public static func presenters(importer: RaycastImporter) -> [String: LauncherCommandPresenter] {
        [
            ImportFromRaycastCommand().id: { _, _ in
                presentedView(importer: importer)
            }
        ]
    }

    @MainActor
    public static func presentedView(
        importer: RaycastImporter,
        fileURL: URL? = nil
    ) -> LauncherPresentedView {
        let model = RaycastImportViewModel(importer: importer, fileURL: fileURL)
        return LauncherPresentedView(
            title: "Import from Raycast",
            content: AnyView(ImportView(viewModel: model)),
            showsSearchField: false,
            initialQuery: "",
            onKey: { [weak model] key in
                guard key == .enter, model?.canRunImport == true else { return false }
                model?.runImport()
                return true
            }
        )
    }
}
