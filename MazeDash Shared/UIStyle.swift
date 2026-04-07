import SpriteKit

#if os(iOS) || os(tvOS)
import UIKit
#elseif os(OSX)
import AppKit
#endif

enum ArcadeFont {
    #if os(iOS) || os(tvOS)
    private static func fontName(weight: UIFont.Weight, monospaced: Bool = true) -> String {
        let font: UIFont
        if monospaced {
            font = UIFont.monospacedSystemFont(ofSize: 18, weight: weight)
        } else {
            font = UIFont.systemFont(ofSize: 18, weight: weight)
        }
        return font.fontName
    }
    #elseif os(OSX)
    private static func fontName(weight: NSFont.Weight, monospaced: Bool = true) -> String {
        let font: NSFont
        if monospaced {
            font = NSFont.monospacedSystemFont(ofSize: 18, weight: weight)
        } else {
            font = NSFont.systemFont(ofSize: 18, weight: weight)
        }
        return font.fontName
    }
    #else
    private static func fontName(weight: CGFloat, monospaced: Bool = true) -> String {
        "HelveticaNeue-Bold"
    }
    #endif

    #if os(iOS) || os(tvOS)
    static let title = fontName(weight: .black)
    static let header = fontName(weight: .heavy)
    static let body = fontName(weight: .semibold)
    static let digits = fontName(weight: .bold)
    static let button = fontName(weight: .heavy)
    #elseif os(OSX)
    static let title = fontName(weight: .black)
    static let header = fontName(weight: .heavy)
    static let body = fontName(weight: .semibold)
    static let digits = fontName(weight: .bold)
    static let button = fontName(weight: .heavy)
    #else
    static let title = fontName(weight: 0.8)
    static let header = fontName(weight: 0.6)
    static let body = fontName(weight: 0.5)
    static let digits = fontName(weight: 0.6)
    static let button = fontName(weight: 0.6)
    #endif
}

enum ArcadeStyle {
    enum Color {
        static let textPrimary = SKColor(white: 0.985, alpha: 1.0)
        static let textSecondary = SKColor(red: 0.82, green: 0.9, blue: 1.0, alpha: 0.96)
        static let textMuted = SKColor(red: 0.62, green: 0.72, blue: 0.86, alpha: 0.92)
        static let textDisabled = SKColor(white: 0.7, alpha: 0.45)
        static let accentCyan = SKColor(red: 0.25, green: 0.96, blue: 1.0, alpha: 1.0)
        static let accentMagenta = SKColor(red: 1.0, green: 0.42, blue: 0.9, alpha: 1.0)
        static let accentYellow = SKColor(red: 1.0, green: 0.92, blue: 0.4, alpha: 1.0)
        static let panelTop = SKColor(red: 0.17, green: 0.21, blue: 0.34, alpha: 0.98)
        static let panelBottom = SKColor(red: 0.05, green: 0.07, blue: 0.16, alpha: 0.96)
        static let panelBorder = SKColor(red: 0.55, green: 0.94, blue: 1.0, alpha: 0.88)
        static let overlayDim = SKColor(white: 0.01, alpha: 0.82)
    }

    enum FontSize {
        static let menuTitle: CGFloat = 40
        static let menuSubtitle: CGFloat = 13
        static let hudTimer: CGFloat = 22
        static let hudLabel: CGFloat = 18
        static let comboMain: CGFloat = 24
        static let comboSmall: CGFloat = 13
        static let overlayTitle: CGFloat = 32
        static let overlayTime: CGFloat = 19
        static let overlayBest: CGFloat = 16
        static let overlayRating: CGFloat = 19
        static let button: CGFloat = 18
        static let levelTitle: CGFloat = 15
        static let levelTime: CGFloat = 12
        static let pauseTitle: CGFloat = 22
    }

    enum Metric {
        static let hudMargin: CGFloat = 16
        static let hudHeight: CGFloat = 60
        static let timerWidth: CGFloat = 196
        static let starsWidth: CGFloat = 170
        static let pauseSize: CGFloat = 56
        static let comboSize = CGSize(width: 260, height: 70)
        static let comboSpacing: CGFloat = 12
        static let hudStarSize: CGFloat = 26
        static let hudStarSpacing: CGFloat = 30
        static let resultStarSize: CGFloat = 44
        static let resultStarSpacing: CGFloat = 56
        static let levelStarSize: CGFloat = 18
        static let panelCornerRadius: CGFloat = 16
        static let buttonCornerRadius: CGFloat = 18
        static let overlayCardSize = CGSize(width: 336, height: 308)
        static let pauseCardSize = CGSize(width: 316, height: 248)
        static let buttonSize = CGSize(width: 228, height: 56)
        static let overlayTitleOffset: CGFloat = 64
        static let overlayTitleSpacing: CGFloat = 16
        static let overlayButtonSpacing: CGFloat = 12
        static let buttonBottomPadding: CGFloat = 20
        static let worldBottomPadding: CGFloat = 16
        static let worldTopPadding: CGFloat = 12
        static let mazeWidthFactor: CGFloat = 0.92
        static var hudStackHeight: CGFloat {
            hudHeight + comboSize.height + comboSpacing + hudMargin
        }
    }
}

struct LevelSelectStyle {
    struct Color {
        static let textPrimary = SKColor(white: 0.98, alpha: 1.0)
        static let textSecondary = SKColor(white: 0.9, alpha: 0.95)
        static let textMuted = SKColor(white: 0.75, alpha: 0.85)
        static let textDisabled = SKColor(white: 0.72, alpha: 0.45)
        static let cardOverlay = SKColor(white: 0.0, alpha: 0.45)
        static let cardOutline = SKColor(red: 0.5, green: 0.95, blue: 1.0, alpha: 0.88)
        static let cardGlow = SKColor(red: 0.3, green: 0.92, blue: 1.0, alpha: 0.35)
        static let topBarFill = SKColor(red: 0.07, green: 0.1, blue: 0.18, alpha: 0.96)
        static let topBarOutline = SKColor(red: 0.45, green: 0.93, blue: 1.0, alpha: 0.84)
        static let lockedOverlay = SKColor(white: 0.0, alpha: 0.35)
        static let debugBounds = SKColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 0.35)
    }

    struct FontName {
        static let title = ArcadeFont.title
        static let cardTitle = ArcadeFont.header
        static let cardTime = ArcadeFont.digits
        static let button = ArcadeFont.button
        static let lock = ArcadeFont.body
    }

    struct FontSize {
        static let titleMin: CGFloat = 20
        static let titleMax: CGFloat = 30
        static let cardTitleMin: CGFloat = 13
        static let cardTitleMax: CGFloat = 18
        static let cardTimeMin: CGFloat = 12
        static let cardTimeMax: CGFloat = 16
        static let lock: CGFloat = 12
        static let backButton: CGFloat = 14
    }

    struct Metric {
        static let sidePadding: CGFloat = 20
        static let columnSpacing: CGFloat = 16
        static let rowSpacing: CGFloat = 16
        static let topBarHeightMin: CGFloat = 54
        static let topBarHeightMax: CGFloat = 72
        static let topBarPadding: CGFloat = 10
        static let topBarCornerRadius: CGFloat = 18
        static let backButtonWidth: CGFloat = 92
        static let backButtonHeight: CGFloat = 44
        static let cardCornerRadius: CGFloat = 18
        static let cardHeightFactor: CGFloat = 0.68
        static let cardInnerPadding: CGFloat = 10
        static let cardStarSizeMin: CGFloat = 20
        static let cardStarSizeMax: CGFloat = 28
        static let gridTopSpacing: CGFloat = 12
        static let gridBottomSpacing: CGFloat = 14
    }

    struct ZPosition {
        static let background: CGFloat = 0
        static let grid: CGFloat = 100
        static let topBar: CGFloat = 1000
    }

    struct Debug {
        static let showLayoutBounds = false
    }
}
