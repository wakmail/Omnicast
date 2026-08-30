// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation
import OmnicastCore

@MainActor
public final class ToastCenter: ObservableObject, ToastService {
    @Published public private(set) var message: String?
    private var dismissal: Task<Void, Never>?

    public init() {}

    public func show(_ message: String) {
        dismissal?.cancel()
        self.message = message
        dismissal = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.message = nil
        }
    }
}
