import AppKit
import OmnicastCore
import SwiftUI

public enum LauncherTheme {
    public enum Metrics {
        public static let panelWidth: CGFloat = 750
        public static let panelHeight: CGFloat = 480
        public static let compactResultRowCount = 5
        public static let compactPanelHeight: CGFloat = 330
        public static let panelCornerRadius: CGFloat = 12
        public static let borderWidth: CGFloat = 1

        public static let searchHeight: CGFloat = 52
        public static let searchHorizontalPadding: CGFloat = 16
        public static let searchIconSize: CGFloat = 13
        public static let searchIconSpacing: CGFloat = 10
        public static let dividerHeight: CGFloat = 1

        public static let sectionLeadingPadding: CGFloat = 16
        public static let sectionTopPadding: CGFloat = 10
        public static let sectionBottomPadding: CGFloat = 4

        public static let rowHeight: CGFloat = 54
        public static let rowOuterInset: CGFloat = 8
        public static let rowContentPadding: CGFloat = 14
        public static let rowIconSize: CGFloat = 32
        public static let rowIconCornerRadius: CGFloat = 6
        public static let rowIconTitleSpacing: CGFloat = 12
        public static let rowSubtitleSpacing: CGFloat = 8
        public static let rowTrailingSpacing: CGFloat = 8
        public static let rowCornerRadius: CGFloat = 8

        public static let iconPrefetchLookahead = 8
        public static let footerHeight: CGFloat = 42
        public static let footerHorizontalPadding: CGFloat = 16
        public static let footerIconSize: CGFloat = 16
        public static let footerIconCornerRadius: CGFloat = 4
        public static let footerIconTitleSpacing: CGFloat = 8
        public static let footerGroupSpacing: CGFloat = 18
        public static let footerLabelSpacing: CGFloat = 7
        public static let keyCapSpacing: CGFloat = 4
        public static let keyCapHeight: CGFloat = 20
        public static let keyCapMinimumWidth: CGFloat = 20
        public static let keyCapHorizontalPadding: CGFloat = 6
        public static let keyCapCornerRadius: CGFloat = 4

        public static let toastHorizontalPadding: CGFloat = 14
        public static let toastVerticalPadding: CGFloat = 8
        public static let toastBottomPadding: CGFloat = 48
        public static let toastAnimationDuration: TimeInterval = 0.18

        public static let actionPanelSpacing: CGFloat = 4
        public static let actionPanelPadding: CGFloat = 12
        public static let actionPanelWidth: CGFloat = 210
        public static let symbolIconPadding: CGFloat = 4

        public static func panelHeight(for windowMode: LauncherWindowMode) -> CGFloat {
            switch windowMode {
            case .standard: panelHeight
            case .compact: compactPanelHeight
            }
        }
    }

    public enum Typography {
        public static let search = Font.system(size: 18, weight: .regular)
        public static let searchNSFont = NSFont.systemFont(ofSize: 18, weight: .regular)
        public static let section = Font.system(size: 11, weight: .semibold)
        public static let rowTitle = Font.system(size: 14, weight: .medium)
        public static let rowSubtitle = Font.system(size: 13, weight: .regular)
        public static let rowKind = Font.system(size: 12, weight: .regular)
        public static let footerTitle = Font.system(size: 13, weight: .regular)
        public static let footerAction = Font.system(size: 13, weight: .medium)
        public static let keyCap = Font.system(size: 11, weight: .medium, design: .monospaced)
        public static let emptyState = Font.system(size: 13, weight: .regular)
        public static let toast = Font.system(size: 12, weight: .medium)
        public static let emojiIcon = Font.system(size: 22, weight: .regular)
    }

    public enum Palette {
        public static let accent = Color(red: 78 / 255, green: 162 / 255, blue: 1)

        public static func surface(for scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color(red: 7 / 255, green: 9 / 255, blue: 13 / 255).opacity(0.92)
                : Color.white.opacity(0.94)
        }

        public static func primaryText(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.92) : Color.black.opacity(0.88)
        }

        public static func secondaryText(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.74) : Color.black.opacity(0.62)
        }

        public static func borderPrimary(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.10)
        }

        public static func selectedRow(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
        }

        public static func selectedRowBorder(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06)
        }

        public static func keyCap(for scheme: ColorScheme) -> Color {
            selectedRow(for: scheme)
        }

        public static func toastSurface(for scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color(red: 24 / 255, green: 24 / 255, blue: 28 / 255).opacity(0.96)
                : Color.white.opacity(0.96)
        }

        public static func primaryNSColor(for scheme: ColorScheme) -> NSColor {
            scheme == .dark
                ? NSColor.white.withAlphaComponent(0.92)
                : NSColor.black.withAlphaComponent(0.88)
        }

        public static func secondaryNSColor(for scheme: ColorScheme) -> NSColor {
            scheme == .dark
                ? NSColor.white.withAlphaComponent(0.74)
                : NSColor.black.withAlphaComponent(0.62)
        }
    }
}
