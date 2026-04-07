import SpriteKit

struct ThemePalette {
    let wallTop: SKColor
    let wallBottom: SKColor
    let floorTop: SKColor
    let floorBottom: SKColor
    let cardTop: SKColor
    let cardBottom: SKColor
    let cardBorder: SKColor
    let accentCyan: SKColor
    let accentPink: SKColor
    let orb: SKColor
    let playerTop: SKColor
    let playerBottom: SKColor

    static let defaultPalette = ThemePalette(
        wallTop: SKColor(red: 0.40, green: 0.95, blue: 1.0, alpha: 1.0),      // #66F2FF
        wallBottom: SKColor(red: 0.0, green: 0.6, blue: 0.8, alpha: 1.0),      // #0099CC
        floorTop: SKColor(red: 0.04, green: 0.06, blue: 0.12, alpha: 1.0),
        floorBottom: SKColor(red: 0.02, green: 0.03, blue: 0.07, alpha: 1.0),
        cardTop: SKColor(red: 0.1, green: 0.14, blue: 0.26, alpha: 0.97),
        cardBottom: SKColor(red: 0.03, green: 0.05, blue: 0.12, alpha: 0.94),
        cardBorder: SKColor(red: 0.4, green: 0.95, blue: 1.0, alpha: 0.82),
        accentCyan: SKColor(red: 0.0, green: 0.83, blue: 1.0, alpha: 1.0),     // #00D4FF
        accentPink: SKColor(red: 1.0, green: 0.18, blue: 0.6, alpha: 1.0),     // #FF2D9A
        orb: SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0),             // #FFD84D
        playerTop: SKColor(red: 1.0, green: 0.42, blue: 0.76, alpha: 1.0),      // #FF6BC1
        playerBottom: SKColor(red: 0.66, green: 0.33, blue: 0.97, alpha: 1.0)   // #A855F7
    )
}

enum MazeTheme: Int, CaseIterable {
    case defaultTheme = 0
    case vaporwave
    case neonMint
    case sunsetPulse
    case arctic
    case ember

    var displayName: String {
        switch self {
        case .defaultTheme:
            return "NEON CORE"
        case .vaporwave:
            return "VAPORWAVE"
        case .neonMint:
            return "MINT CIRCUIT"
        case .sunsetPulse:
            return "SUNSET PULSE"
        case .arctic:
            return "ARCTIC DRIVE"
        case .ember:
            return "EMBER SHIFT"
        }
    }

    var palette: ThemePalette {
        switch self {
        case .defaultTheme:
            return ThemePalette.defaultPalette
        case .vaporwave:
            return ThemePalette(
                wallTop: SKColor(red: 0.9, green: 0.64, blue: 1.0, alpha: 1.0),
                wallBottom: SKColor(red: 0.44, green: 0.2, blue: 0.86, alpha: 1.0),
                floorTop: SKColor(red: 0.12, green: 0.08, blue: 0.18, alpha: 1.0),
                floorBottom: SKColor(red: 0.05, green: 0.03, blue: 0.08, alpha: 1.0),
                cardTop: SKColor(red: 0.22, green: 0.16, blue: 0.32, alpha: 0.97),
                cardBottom: SKColor(red: 0.08, green: 0.05, blue: 0.14, alpha: 0.94),
                cardBorder: SKColor(red: 0.96, green: 0.68, blue: 1.0, alpha: 0.82),
                accentCyan: SKColor(red: 0.55, green: 0.9, blue: 1.0, alpha: 1.0),
                accentPink: SKColor(red: 1.0, green: 0.5, blue: 0.9, alpha: 1.0),
                orb: SKColor(red: 1.0, green: 0.88, blue: 0.4, alpha: 1.0),
                playerTop: SKColor(red: 1.0, green: 0.74, blue: 0.98, alpha: 1.0),
                playerBottom: SKColor(red: 0.9, green: 0.32, blue: 0.78, alpha: 1.0)
            )
        case .neonMint:
            return ThemePalette(
                wallTop: SKColor(red: 0.45, green: 1.0, blue: 0.85, alpha: 1.0),
                wallBottom: SKColor(red: 0.08, green: 0.72, blue: 0.6, alpha: 1.0),
                floorTop: SKColor(red: 0.08, green: 0.12, blue: 0.16, alpha: 1.0),
                floorBottom: SKColor(red: 0.04, green: 0.06, blue: 0.1, alpha: 1.0),
                cardTop: SKColor(red: 0.12, green: 0.2, blue: 0.26, alpha: 0.97),
                cardBottom: SKColor(red: 0.05, green: 0.09, blue: 0.14, alpha: 0.94),
                cardBorder: SKColor(red: 0.5, green: 1.0, blue: 0.85, alpha: 0.82),
                accentCyan: SKColor(red: 0.35, green: 1.0, blue: 0.85, alpha: 1.0),
                accentPink: SKColor(red: 1.0, green: 0.5, blue: 0.75, alpha: 1.0),
                orb: SKColor(red: 1.0, green: 0.9, blue: 0.5, alpha: 1.0),
                playerTop: SKColor(red: 0.85, green: 1.0, blue: 0.95, alpha: 1.0),
                playerBottom: SKColor(red: 0.3, green: 0.9, blue: 0.7, alpha: 1.0)
            )
        case .sunsetPulse:
            return ThemePalette(
                wallTop: SKColor(red: 1.0, green: 0.7, blue: 0.4, alpha: 1.0),
                wallBottom: SKColor(red: 0.85, green: 0.3, blue: 0.35, alpha: 1.0),
                floorTop: SKColor(red: 0.14, green: 0.08, blue: 0.12, alpha: 1.0),
                floorBottom: SKColor(red: 0.06, green: 0.03, blue: 0.07, alpha: 1.0),
                cardTop: SKColor(red: 0.2, green: 0.12, blue: 0.16, alpha: 0.97),
                cardBottom: SKColor(red: 0.08, green: 0.04, blue: 0.08, alpha: 0.94),
                cardBorder: SKColor(red: 1.0, green: 0.6, blue: 0.5, alpha: 0.82),
                accentCyan: SKColor(red: 0.5, green: 0.9, blue: 0.95, alpha: 1.0),
                accentPink: SKColor(red: 1.0, green: 0.45, blue: 0.6, alpha: 1.0),
                orb: SKColor(red: 1.0, green: 0.88, blue: 0.45, alpha: 1.0),
                playerTop: SKColor(red: 1.0, green: 0.75, blue: 0.65, alpha: 1.0),
                playerBottom: SKColor(red: 0.88, green: 0.35, blue: 0.4, alpha: 1.0)
            )
        case .arctic:
            return ThemePalette(
                wallTop: SKColor(red: 0.75, green: 0.92, blue: 1.0, alpha: 1.0),
                wallBottom: SKColor(red: 0.25, green: 0.55, blue: 0.9, alpha: 1.0),
                floorTop: SKColor(red: 0.1, green: 0.12, blue: 0.18, alpha: 1.0),
                floorBottom: SKColor(red: 0.04, green: 0.05, blue: 0.09, alpha: 1.0),
                cardTop: SKColor(red: 0.16, green: 0.2, blue: 0.3, alpha: 0.97),
                cardBottom: SKColor(red: 0.05, green: 0.08, blue: 0.14, alpha: 0.94),
                cardBorder: SKColor(red: 0.7, green: 0.95, blue: 1.0, alpha: 0.82),
                accentCyan: SKColor(red: 0.5, green: 0.95, blue: 1.0, alpha: 1.0),
                accentPink: SKColor(red: 0.9, green: 0.6, blue: 1.0, alpha: 1.0),
                orb: SKColor(red: 1.0, green: 0.95, blue: 0.55, alpha: 1.0),
                playerTop: SKColor(red: 0.85, green: 0.95, blue: 1.0, alpha: 1.0),
                playerBottom: SKColor(red: 0.35, green: 0.6, blue: 0.95, alpha: 1.0)
            )
        case .ember:
            return ThemePalette(
                wallTop: SKColor(red: 1.0, green: 0.55, blue: 0.3, alpha: 1.0),
                wallBottom: SKColor(red: 0.85, green: 0.2, blue: 0.2, alpha: 1.0),
                floorTop: SKColor(red: 0.16, green: 0.08, blue: 0.1, alpha: 1.0),
                floorBottom: SKColor(red: 0.06, green: 0.03, blue: 0.06, alpha: 1.0),
                cardTop: SKColor(red: 0.2, green: 0.12, blue: 0.12, alpha: 0.97),
                cardBottom: SKColor(red: 0.08, green: 0.04, blue: 0.06, alpha: 0.94),
                cardBorder: SKColor(red: 1.0, green: 0.55, blue: 0.35, alpha: 0.82),
                accentCyan: SKColor(red: 0.6, green: 0.9, blue: 0.95, alpha: 1.0),
                accentPink: SKColor(red: 1.0, green: 0.45, blue: 0.5, alpha: 1.0),
                orb: SKColor(red: 1.0, green: 0.88, blue: 0.45, alpha: 1.0),
                playerTop: SKColor(red: 1.0, green: 0.7, blue: 0.55, alpha: 1.0),
                playerBottom: SKColor(red: 0.9, green: 0.3, blue: 0.25, alpha: 1.0)
            )
        }
    }

    var cacheKey: String {
        "theme_\(rawValue)"
    }
}

struct ThemeUnlocker {
    static func theme(for levelId: Int) -> MazeTheme {
        let tier = max(0, (levelId - 1) / 5)
        let themes: [MazeTheme] = [.defaultTheme, .vaporwave, .neonMint, .sunsetPulse, .arctic, .ember]
        return themes[min(tier, themes.count - 1)]
    }

    static func isNewUnlock(levelId: Int, starsEarned: Int) -> Bool {
        guard starsEarned > 0 else { return false }
        let theme = theme(for: levelId)
        if levelId % 5 != 0 { return false }
        return !ThemeProgress.shared.isUnlocked(theme)
    }
}
