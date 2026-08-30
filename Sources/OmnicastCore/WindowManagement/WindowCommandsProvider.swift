// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct WindowCommandsProvider: CommandProvider {
    private let adjuster: WindowAdjuster
    private let requestAccessibility: (@MainActor @Sendable () -> Void)?

    public init(
        adjuster: WindowAdjuster = WindowAdjuster(),
        requestAccessibility: (@MainActor @Sendable () -> Void)? = nil
    ) {
        self.adjuster = adjuster
        self.requestAccessibility = requestAccessibility
    }

    public func commands() async -> [any Command] {
        WindowPlacement.allCases.map {
            WindowPlacementCommand(
                placement: $0,
                adjuster: adjuster,
                requestAccessibility: requestAccessibility
            )
        }
    }
}

public struct WindowPlacementCommand: Command {
    public let placement: WindowPlacement
    private let adjuster: WindowAdjuster
    private let requestAccessibility: (@MainActor @Sendable () -> Void)?

    public var id: String { "system-window-management-\(placement.rawValue)" }
    public var title: String { "Window: \(placement.displayName)" }
    public let subtitle = "Adjust the focused window"
    public var icon: CommandIcon { .sfSymbol(placement.iconName) }
    public var keywords: [String] { placement.keywords }
    public let kind: CommandKind = .window

    public init(
        placement: WindowPlacement,
        adjuster: WindowAdjuster = WindowAdjuster(),
        requestAccessibility: (@MainActor @Sendable () -> Void)? = nil
    ) {
        self.placement = placement
        self.adjuster = adjuster
        self.requestAccessibility = requestAccessibility
    }

    @MainActor
    public func execute(context: CommandContext) async throws {
        guard adjuster.accessibilityGranted else {
            if let requestAccessibility {
                requestAccessibility()
                return
            }
            throw WindowAdjustmentError.accessibilityPermissionRequired
        }
        try adjuster.apply(placement)
        context.toasts.show("\(placement.displayName) applied")
    }
}

private extension WindowPlacement {
    var keywords: [String] {
        let words = displayName.lowercased()
        var result = ["window", "management", "tile", "snap", words]
        result.append(contentsOf: words.split(separator: " ").map(String.init))
        switch self {
        case .left: result.append("left half")
        case .right: result.append("right half")
        case .top: result.append("top half")
        case .bottom: result.append("bottom half")
        case .center: result.append(contentsOf: ["middle", "resize"])
        case .center80: result.append(contentsOf: ["almost maximize", "center"])
        case .fill: result.append(contentsOf: ["maximize", "fullscreen"])
        default: break
        }
        return Array(Set(result)).sorted()
    }

    var iconName: String {
        switch self {
        case .left, .firstThird, .firstTwoThirds, .firstFourth, .firstThreeFourths:
            "rectangle.lefthalf.inset.filled"
        case .right, .lastThird, .lastTwoThirds, .lastFourth, .lastThreeFourths:
            "rectangle.righthalf.inset.filled"
        case .top, .increaseTop10, .decreaseTop10, .moveUp10:
            "rectangle.tophalf.inset.filled"
        case .bottom, .increaseBottom10, .decreaseBottom10, .moveDown10:
            "rectangle.bottomhalf.inset.filled"
        case .topLeft, .topLeftSixth:
            "rectangle.inset.topleft.filled"
        case .topRight, .topRightSixth:
            "rectangle.inset.topright.filled"
        case .bottomLeft, .bottomLeftSixth:
            "rectangle.inset.bottomleft.filled"
        case .bottomRight, .bottomRightSixth:
            "rectangle.inset.bottomright.filled"
        case .fill, .center80:
            "arrow.up.left.and.arrow.down.right"
        case .maximizeWidth:
            "arrow.left.and.right"
        case .maximizeHeight:
            "arrow.up.and.down"
        case .center, .centerThird, .centerTwoThirds, .secondFourth, .thirdFourth,
             .centerThreeFourths, .topCenterSixth, .bottomCenterSixth:
            "rectangle.center.inset.filled"
        case .increaseSize10, .increaseLeft10, .increaseRight10:
            "plus.magnifyingglass"
        case .decreaseSize10, .decreaseLeft10, .decreaseRight10:
            "minus.magnifyingglass"
        case .moveLeft10:
            "arrow.left"
        case .moveRight10:
            "arrow.right"
        }
    }
}
