// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation
import OmnicastCore

@MainActor
public final class QuicklinkManagerViewModel: ObservableObject {
    @Published public private(set) var quicklinks: [Quicklink]
    @Published public var selectedID: UUID?
    @Published public var name = ""
    @Published public var urlTemplate = ""
    @Published public var bundleIdentifier = ""
    @Published public var icon = "Globe"
    @Published public private(set) var isEditing = false
    @Published public private(set) var errorMessage: String?

    private let store: QuicklinkStore
    private var editingID: UUID?

    public init(store: QuicklinkStore) {
        self.store = store
        quicklinks = store.quicklinks
    }

    public func beginCreate() {
        editingID = nil
        selectedID = nil
        name = ""
        urlTemplate = ""
        bundleIdentifier = ""
        icon = "Globe"
        errorMessage = nil
        isEditing = true
    }

    public func beginEditing(_ quicklink: Quicklink) {
        editingID = quicklink.id
        selectedID = quicklink.id
        name = quicklink.name
        urlTemplate = quicklink.urlTemplate
        bundleIdentifier = quicklink.openWithAppBundleIdentifier ?? ""
        icon = quicklink.icon
        errorMessage = nil
        isEditing = true
    }

    public func cancelEditing() {
        editingID = nil
        errorMessage = nil
        isEditing = false
    }

    public func save() {
        do {
            if let editingID {
                try store.update(
                    id: editingID,
                    name: name,
                    urlTemplate: urlTemplate,
                    openWithAppBundleIdentifier: bundleIdentifier,
                    icon: icon
                )
                selectedID = editingID
            } else {
                let created = try store.create(
                    name: name,
                    urlTemplate: urlTemplate,
                    openWithAppBundleIdentifier: bundleIdentifier,
                    icon: icon
                )
                selectedID = created.id
            }
            quicklinks = store.quicklinks
            errorMessage = nil
            isEditing = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func deleteSelected() {
        guard let selectedID else { return }
        do {
            try store.delete(id: selectedID)
            quicklinks = store.quicklinks
            self.selectedID = nil
            if editingID == selectedID {
                isEditing = false
                editingID = nil
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
