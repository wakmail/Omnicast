// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import SwiftUI

public enum CalendarLauncherPresentation {
    @MainActor
    public static func presenters(service: CalendarService) -> [String: LauncherCommandPresenter] {
        [
            MyScheduleCommand().id: { _, _ in
                let model = ScheduleViewModel(service: service)
                return LauncherPresentedView(
                    title: "My Schedule",
                    content: AnyView(ScheduleView(viewModel: model)),
                    showsSearchField: false,
                    initialQuery: ""
                )
            }
        ]
    }
}
