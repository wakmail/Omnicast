// SPDX-License-Identifier: GPL-3.0-or-later

import CoreGraphics

private let windowAdjustmentRatio: CGFloat = 0.1
private let minimumWindowWidth: CGFloat = 120
private let minimumWindowHeight: CGFloat = 60

public func frame(
    for placement: WindowPlacement,
    in visibleFrame: CGRect,
    current: CGRect
) -> CGRect {
    let area = visibleFrame
    let stepX = max(1, round(current.width * windowAdjustmentRatio))
    let stepY = max(1, round(current.height * windowAdjustmentRatio))
    var next = current

    switch placement {
    case .left:
        next = CGRect(
            x: area.minX,
            y: area.minY,
            width: max(minimumWindowWidth, round(area.width / 2)),
            height: max(minimumWindowHeight, round(area.height))
        )
    case .right:
        let width = max(minimumWindowWidth, round(area.width / 2))
        next = CGRect(
            x: area.maxX - width,
            y: area.minY,
            width: width,
            height: max(minimumWindowHeight, round(area.height))
        )
    case .top:
        next = CGRect(
            x: area.minX,
            y: area.minY,
            width: max(minimumWindowWidth, round(area.width)),
            height: max(minimumWindowHeight, round(area.height / 2))
        )
    case .bottom:
        let height = max(minimumWindowHeight, round(area.height / 2))
        next = CGRect(
            x: area.minX,
            y: area.maxY - height,
            width: max(minimumWindowWidth, round(area.width)),
            height: height
        )
    case .fill:
        next = CGRect(
            x: area.minX,
            y: area.minY,
            width: max(minimumWindowWidth, round(area.width)),
            height: max(minimumWindowHeight, round(area.height))
        )
    case .maximizeWidth:
        next = CGRect(
            x: area.minX,
            y: current.minY,
            width: max(minimumWindowWidth, round(area.width)),
            height: current.height
        )
    case .maximizeHeight:
        next = CGRect(
            x: current.minX,
            y: area.minY,
            width: current.width,
            height: max(minimumWindowHeight, round(area.height))
        )
    case .center:
        next = centeredFrame(widthRatio: 0.6, heightRatio: 0.6, in: area)
    case .center80:
        next = centeredFrame(widthRatio: 0.9, heightRatio: 0.9, in: area)
    case .topLeft:
        next = CGRect(
            x: area.minX,
            y: area.minY,
            width: max(minimumWindowWidth, round(area.width / 2)),
            height: max(minimumWindowHeight, round(area.height / 2))
        )
    case .topRight:
        let width = max(minimumWindowWidth, round(area.width / 2))
        next = CGRect(
            x: area.maxX - width,
            y: area.minY,
            width: width,
            height: max(minimumWindowHeight, round(area.height / 2))
        )
    case .bottomLeft:
        let height = max(minimumWindowHeight, round(area.height / 2))
        next = CGRect(
            x: area.minX,
            y: area.maxY - height,
            width: max(minimumWindowWidth, round(area.width / 2)),
            height: height
        )
    case .bottomRight:
        let width = max(minimumWindowWidth, round(area.width / 2))
        let height = max(minimumWindowHeight, round(area.height / 2))
        next = CGRect(
            x: area.maxX - width,
            y: area.maxY - height,
            width: width,
            height: height
        )
    case .firstThird:
        next = horizontalSlice(start: 0, end: 1, denominator: 3, in: area)
    case .centerThird:
        next = horizontalSlice(start: 1, end: 2, denominator: 3, in: area)
    case .lastThird:
        next = horizontalSlice(start: 2, end: 3, denominator: 3, in: area)
    case .firstTwoThirds:
        next = horizontalSlice(start: 0, end: 2, denominator: 3, in: area)
    case .centerTwoThirds:
        next = horizontalSlice(start: 1, end: 5, denominator: 6, in: area)
    case .lastTwoThirds:
        next = horizontalSlice(start: 1, end: 3, denominator: 3, in: area)
    case .firstFourth:
        next = horizontalSlice(start: 0, end: 1, denominator: 4, in: area)
    case .secondFourth:
        next = horizontalSlice(start: 1, end: 2, denominator: 4, in: area)
    case .thirdFourth:
        next = horizontalSlice(start: 2, end: 3, denominator: 4, in: area)
    case .lastFourth:
        next = horizontalSlice(start: 3, end: 4, denominator: 4, in: area)
    case .firstThreeFourths:
        next = horizontalSlice(start: 0, end: 3, denominator: 4, in: area)
    case .centerThreeFourths:
        next = horizontalSlice(start: 1, end: 7, denominator: 8, in: area)
    case .lastThreeFourths:
        next = horizontalSlice(start: 1, end: 4, denominator: 4, in: area)
    case .topLeftSixth:
        next = gridFrame(column: 0, row: 0, columns: 3, rows: 2, in: area)
    case .topCenterSixth:
        next = gridFrame(column: 1, row: 0, columns: 3, rows: 2, in: area)
    case .topRightSixth:
        next = gridFrame(column: 2, row: 0, columns: 3, rows: 2, in: area)
    case .bottomLeftSixth:
        next = gridFrame(column: 0, row: 1, columns: 3, rows: 2, in: area)
    case .bottomCenterSixth:
        next = gridFrame(column: 1, row: 1, columns: 3, rows: 2, in: area)
    case .bottomRightSixth:
        next = gridFrame(column: 2, row: 1, columns: 3, rows: 2, in: area)
    case .increaseSize10:
        next = CGRect(
            x: current.minX - round(stepX / 2),
            y: current.minY - round(stepY / 2),
            width: current.width + stepX,
            height: current.height + stepY
        )
    case .decreaseSize10:
        next = CGRect(
            x: current.minX + round(stepX / 2),
            y: current.minY + round(stepY / 2),
            width: max(minimumWindowWidth, current.width - stepX),
            height: max(minimumWindowHeight, current.height - stepY)
        )
    case .increaseLeft10:
        next = CGRect(
            x: current.minX - stepX,
            y: current.minY,
            width: current.width + stepX,
            height: current.height
        )
    case .increaseRight10:
        next.size.width += stepX
    case .increaseTop10:
        next.origin.y -= stepY
        next.size.height += stepY
    case .increaseBottom10:
        next.size.height += stepY
    case .decreaseLeft10:
        let width = max(minimumWindowWidth, current.width - stepX)
        next = CGRect(x: current.maxX - width, y: current.minY, width: width, height: current.height)
    case .decreaseRight10:
        next.size.width = max(minimumWindowWidth, current.width - stepX)
    case .decreaseTop10:
        let height = max(minimumWindowHeight, current.height - stepY)
        next = CGRect(x: current.minX, y: current.maxY - height, width: current.width, height: height)
    case .decreaseBottom10:
        next.size.height = max(minimumWindowHeight, current.height - stepY)
    case .moveUp10:
        next.origin.y -= stepY
    case .moveDown10:
        next.origin.y += stepY
    case .moveLeft10:
        next.origin.x -= stepX
    case .moveRight10:
        next.origin.x += stepX
    }

    next.size.width = clamp(
        round(next.width),
        minimumWindowWidth,
        max(minimumWindowWidth, area.width)
    )
    next.size.height = clamp(
        round(next.height),
        minimumWindowHeight,
        max(minimumWindowHeight, area.height)
    )
    next.origin.x = clamp(round(next.minX), area.minX, area.maxX - next.width)
    next.origin.y = clamp(round(next.minY), area.minY, area.maxY - next.height)
    return next
}

private func centeredFrame(widthRatio: CGFloat, heightRatio: CGFloat, in area: CGRect) -> CGRect {
    let width = max(minimumWindowWidth, round(area.width * widthRatio))
    let height = max(minimumWindowHeight, round(area.height * heightRatio))
    return CGRect(
        x: area.minX + round((area.width - width) / 2),
        y: area.minY + round((area.height - height) / 2),
        width: width,
        height: height
    )
}

private func horizontalSlice(
    start: CGFloat,
    end: CGFloat,
    denominator: CGFloat,
    in area: CGRect
) -> CGRect {
    let left = start == 0
        ? area.minX
        : area.minX + floor(area.width * start / denominator)
    let right = end == denominator
        ? area.maxX
        : area.minX + floor(area.width * end / denominator)
    return CGRect(
        x: left,
        y: area.minY,
        width: max(minimumWindowWidth, right - left),
        height: max(minimumWindowHeight, round(area.height))
    )
}

private func gridFrame(
    column: CGFloat,
    row: CGFloat,
    columns: CGFloat,
    rows: CGFloat,
    in area: CGRect
) -> CGRect {
    let left = area.minX + floor(area.width * column / columns)
    let right = area.minX + floor(area.width * (column + 1) / columns)
    let top = area.minY + floor(area.height * row / rows)
    let bottom = area.minY + floor(area.height * (row + 1) / rows)
    return CGRect(
        x: left,
        y: top,
        width: max(minimumWindowWidth, right - left),
        height: max(minimumWindowHeight, bottom - top)
    )
}

private func clamp(_ value: CGFloat, _ minimum: CGFloat, _ maximum: CGFloat) -> CGFloat {
    guard value.isFinite, maximum > minimum else { return minimum }
    return max(minimum, min(maximum, value))
}
