// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum RayconfigDropValidationError: LocalizedError, Equatable {
    case invalidFileCount
    case unsupportedExtension

    public var errorDescription: String? {
        switch self {
        case .invalidFileCount:
            "Drop exactly one Raycast backup."
        case .unsupportedExtension:
            "Choose a .rayconfig or .json file."
        }
    }
}

public enum RayconfigDropValidator {
    public static func validate(_ urls: [URL]) throws -> URL {
        guard urls.count == 1, let url = urls.first else {
            throw RayconfigDropValidationError.invalidFileCount
        }
        let allowedExtensions: Set<String> = ["rayconfig", "json"]
        guard url.isFileURL, allowedExtensions.contains(url.pathExtension.lowercased()) else {
            throw RayconfigDropValidationError.unsupportedExtension
        }
        return url
    }
}
