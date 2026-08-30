// SPDX-License-Identifier: GPL-3.0-or-later

import CoreGraphics

let launcherPanelSnapDistance: CGFloat = 48

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

private func squaredCenterDistance(from first: CGRect, to second: CGRect) -> CGFloat {
    let deltaX = first.midX - second.midX
    let deltaY = first.midY - second.midY
    return deltaX * deltaX + deltaY * deltaY
}
