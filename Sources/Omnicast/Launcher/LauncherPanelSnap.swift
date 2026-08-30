// SPDX-License-Identifier: GPL-3.0-or-later

import CoreGraphics

let launcherPanelSnapDistance: CGFloat = 48
let launcherPanelGuideActivationDistance: CGFloat = 8

struct LauncherPanelGuideAlignment: Equatable {
    let screenVisibleFrame: CGRect
    let magnetizedFrame: CGRect
    let verticalGuideX: CGFloat?
    let horizontalGuideY: CGFloat?

    var hasActiveGuide: Bool {
        verticalGuideX != nil || horizontalGuideY != nil
    }
}

func launcherPanelDefaultFrame(
    panelSize: CGSize,
    screenVisibleFrame: CGRect
) -> CGRect {
    let topInset = min(90, screenVisibleFrame.height * 0.12)
    let centeredX = screenVisibleFrame.midX - panelSize.width / 2
    let topY = screenVisibleFrame.maxY - panelSize.height - topInset

    return CGRect(
        origin: CGPoint(x: centeredX, y: topY),
        size: panelSize
    )
}

func launcherPanelNearestDefaultFrame(
    panelFrame: CGRect,
    screenVisibleFrames: [CGRect]
) -> CGRect? {
    screenVisibleFrames
        .map {
            launcherPanelDefaultFrame(
                panelSize: panelFrame.size,
                screenVisibleFrame: $0
            )
        }
        .min {
            squaredCenterDistance(from: panelFrame, to: $0)
                < squaredCenterDistance(from: panelFrame, to: $1)
        }
}

func launcherPanelSnapTarget(
    droppedFrame: CGRect,
    screenVisibleFrames: [CGRect],
    threshold: CGFloat = launcherPanelSnapDistance
) -> CGRect? {
    guard threshold >= 0,
          let target = launcherPanelNearestDefaultFrame(
              panelFrame: droppedFrame,
              screenVisibleFrames: screenVisibleFrames
          )
    else { return nil }

    let thresholdSquared = threshold * threshold
    return squaredCenterDistance(from: droppedFrame, to: target) <= thresholdSquared
        ? target
        : nil
}

func launcherPanelGuideAlignment(
    panelFrame: CGRect,
    screenVisibleFrames: [CGRect],
    activationDistance: CGFloat = launcherPanelGuideActivationDistance
) -> LauncherPanelGuideAlignment? {
    guard activationDistance >= 0,
          let screenVisibleFrame = nearestScreenVisibleFrame(
              to: panelFrame,
              screenVisibleFrames: screenVisibleFrames
          )
    else { return nil }

    let defaultFrame = launcherPanelDefaultFrame(
        panelSize: panelFrame.size,
        screenVisibleFrame: screenVisibleFrame
    )
    let alignsVertically = abs(panelFrame.midX - screenVisibleFrame.midX)
        <= activationDistance
    let alignsHorizontally = abs(panelFrame.maxY - defaultFrame.maxY)
        <= activationDistance

    var magnetizedFrame = panelFrame
    if alignsVertically {
        magnetizedFrame.origin.x = defaultFrame.origin.x
    }
    if alignsHorizontally {
        magnetizedFrame.origin.y = defaultFrame.origin.y
    }

    return LauncherPanelGuideAlignment(
        screenVisibleFrame: screenVisibleFrame,
        magnetizedFrame: magnetizedFrame,
        verticalGuideX: alignsVertically ? screenVisibleFrame.midX : nil,
        horizontalGuideY: alignsHorizontally ? defaultFrame.maxY : nil
    )
}

private func nearestScreenVisibleFrame(
    to panelFrame: CGRect,
    screenVisibleFrames: [CGRect]
) -> CGRect? {
    let panelCenter = CGPoint(x: panelFrame.midX, y: panelFrame.midY)
    return screenVisibleFrames.min {
        squaredDistance(from: panelCenter, to: $0)
            < squaredDistance(from: panelCenter, to: $1)
    }
}

private func squaredDistance(from point: CGPoint, to rect: CGRect) -> CGFloat {
    let deltaX = max(max(rect.minX - point.x, 0), point.x - rect.maxX)
    let deltaY = max(max(rect.minY - point.y, 0), point.y - rect.maxY)
    return deltaX * deltaX + deltaY * deltaY
}

private func squaredCenterDistance(from first: CGRect, to second: CGRect) -> CGFloat {
    let deltaX = first.midX - second.midX
    let deltaY = first.midY - second.midY
    return deltaX * deltaX + deltaY * deltaY
}
