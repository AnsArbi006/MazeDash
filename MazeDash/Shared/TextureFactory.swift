import SpriteKit

#if os(iOS) || os(tvOS)
import UIKit
#elseif os(OSX)
import AppKit
#endif

enum GlossyPalette {
    static var current = ThemePalette.defaultPalette

    static var wallTop: SKColor { current.wallTop }
    static var wallBottom: SKColor { current.wallBottom }
    static var floorTop: SKColor { current.floorTop }
    static var floorBottom: SKColor { current.floorBottom }
    static var cardTop: SKColor { current.cardTop }
    static var cardBottom: SKColor { current.cardBottom }
    static var cardBorder: SKColor { current.cardBorder }
    static var accentCyan: SKColor { current.accentCyan }
    static var accentPink: SKColor { current.accentPink }
    static var orb: SKColor { current.orb }
    static var playerTop: SKColor { current.playerTop }
    static var playerBottom: SKColor { current.playerBottom }
}

enum CardStyle: String {
    case hud
    case badge
    case button
    case overlay
    case shellPanel
    case shellFeature
    case shellAccent
}

enum TileStyle: String {
    case wall
    case floor
}

final class TextureFactory {
    static let shared = TextureFactory()
    var displayScale: CGFloat = 2.0

    private var cache: [String: SKTexture] = [:]
    private var themeKey: String = MazeTheme.defaultTheme.cacheKey

    func setTheme(_ theme: MazeTheme) {
        let newKey = theme.cacheKey
        guard newKey != themeKey else { return }
        themeKey = newKey
        GlossyPalette.current = theme.palette
        cache.removeAll()
    }

    func tileVariantCount(for style: TileStyle) -> Int {
        switch style {
        case .wall, .floor:
            return 3
        }
    }

    func tileTexture(size: CGSize, style: TileStyle, variant: Int = 0) -> SKTexture {
        texture(key: "tile_\(style.rawValue)_v\(variant)", size: size) { context, rect in
            switch style {
            case .wall:
                drawWallTile(in: context, rect: rect, variant: variant)
            case .floor:
                drawFloorTile(in: context, rect: rect, variant: variant)
            }
        }
    }

    func activeFloorPulseTexture(size: CGSize, variant: Int = 0) -> SKTexture {
        texture(key: "floorPulse_v\(variant)", size: size) { context, rect in
            drawActiveFloorPulse(in: context, rect: rect, variant: variant)
        }
    }

    func cardTexture(size: CGSize, style: CardStyle) -> SKTexture {
        texture(key: "card_\(style.rawValue)", size: size) { context, rect in
            let corner: CGFloat
            let topColor: SKColor
            let bottomColor: SKColor
            let borderColor: SKColor
            let highlightAlpha: CGFloat
            let shadowAlpha: CGFloat
            let innerStrokeAlpha: CGFloat
            switch style {
            case .hud:
                corner = rect.height * 0.26
                topColor = blend(GlossyPalette.cardTop, with: SKColor.white, ratio: 0.015)
                bottomColor = blend(GlossyPalette.cardBottom, with: SKColor.black, ratio: 0.16)
                borderColor = blend(GlossyPalette.cardBorder, with: SKColor.white, ratio: 0.08)
                highlightAlpha = 0.05
                shadowAlpha = 0.1
                innerStrokeAlpha = 0.045
            case .badge:
                corner = rect.height * 0.26
                topColor = blend(GlossyPalette.cardTop, with: GlossyPalette.accentPink, ratio: 0.08)
                bottomColor = blend(GlossyPalette.cardBottom, with: SKColor.black, ratio: 0.2)
                borderColor = GlossyPalette.accentPink
                highlightAlpha = 0.085
                shadowAlpha = 0.09
                innerStrokeAlpha = 0.06
            case .button:
                corner = rect.height * 0.26
                topColor = blend(GlossyPalette.cardTop, with: GlossyPalette.accentCyan, ratio: 0.1)
                bottomColor = blend(GlossyPalette.cardBottom, with: GlossyPalette.accentPink, ratio: 0.04)
                borderColor = GlossyPalette.accentCyan
                highlightAlpha = 0.09
                shadowAlpha = 0.09
                innerStrokeAlpha = 0.065
            case .overlay:
                corner = min(22, rect.height * 0.16)
                topColor = blend(GlossyPalette.cardTop, with: SKColor.white, ratio: 0.014)
                bottomColor = blend(GlossyPalette.cardBottom, with: SKColor.black, ratio: 0.24)
                borderColor = blend(GlossyPalette.cardBorder, with: SKColor.white, ratio: 0.08)
                highlightAlpha = 0.032
                shadowAlpha = 0.115
                innerStrokeAlpha = 0.04
            case .shellPanel:
                corner = rect.height * 0.26
                topColor = blend(GlossyPalette.cardTop, with: SKColor.white, ratio: 0.012)
                bottomColor = blend(GlossyPalette.cardBottom, with: SKColor.black, ratio: 0.22)
                borderColor = blend(GlossyPalette.cardBorder, with: SKColor.white, ratio: 0.1)
                highlightAlpha = 0.05
                shadowAlpha = 0.1
                innerStrokeAlpha = 0.05
            case .shellFeature:
                corner = rect.height * 0.26
                topColor = blend(GlossyPalette.cardTop, with: GlossyPalette.accentCyan, ratio: 0.05)
                bottomColor = blend(GlossyPalette.cardBottom, with: SKColor.black, ratio: 0.18)
                borderColor = blend(GlossyPalette.cardBorder, with: GlossyPalette.accentCyan, ratio: 0.16)
                highlightAlpha = 0.062
                shadowAlpha = 0.098
                innerStrokeAlpha = 0.05
            case .shellAccent:
                corner = rect.height * 0.26
                topColor = blend(GlossyPalette.cardTop, with: ArcadeStyle.Color.accentYellow, ratio: 0.05)
                bottomColor = blend(GlossyPalette.cardBottom, with: SKColor.black, ratio: 0.18)
                borderColor = blend(ArcadeStyle.Color.accentYellow, with: GlossyPalette.cardBorder, ratio: 0.18)
                highlightAlpha = 0.068
                shadowAlpha = 0.102
                innerStrokeAlpha = 0.052
            }
            drawGlossyRoundedRect(
                in: context,
                rect: rect,
                cornerRadius: corner,
                topColor: topColor,
                bottomColor: bottomColor,
                borderColor: borderColor,
                highlightAlpha: highlightAlpha,
                shadowAlpha: shadowAlpha,
                innerStrokeAlpha: innerStrokeAlpha
            )
        }
    }

    func playerTexture(size: CGSize) -> SKTexture {
        texture(key: "player", size: size) { context, rect in
            let corner = rect.height * 0.3
            drawGlossyRoundedRect(in: context, rect: rect, cornerRadius: corner, topColor: GlossyPalette.playerTop, bottomColor: GlossyPalette.playerBottom, borderColor: GlossyPalette.accentPink)
        }
    }

    func playerPatternTexture(size: CGSize, skin: PlayerSkin) -> SKTexture? {
        guard skin.kind == .pattern || skin == .goldenPulse else { return nil }
        return texture(key: "playerPattern_\(skin.rawValue)", size: size) { context, rect in
            let insetRect = rect.insetBy(dx: rect.width * 0.08, dy: rect.height * 0.08)
            let path = CGPath(
                roundedRect: insetRect,
                cornerWidth: insetRect.height * 0.22,
                cornerHeight: insetRect.height * 0.22,
                transform: nil
            )
            context.saveGState()
            context.addPath(path)
            context.clip()

            switch skin {
            case .goldenPulse:
                if let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [
                        skin.highlightColor.withAlphaComponent(0.55).cgColor,
                        skin.baseColor.withAlphaComponent(0.22).cgColor,
                        skin.deepColor.withAlphaComponent(0.12).cgColor
                    ] as CFArray,
                    locations: [0.0, 0.45, 1.0]
                ) {
                    context.drawLinearGradient(
                        gradient,
                        start: CGPoint(x: insetRect.minX, y: insetRect.minY),
                        end: CGPoint(x: insetRect.maxX, y: insetRect.maxY),
                        options: []
                    )
                }
            case .gridCore:
                context.setStrokeColor(skin.highlightColor.withAlphaComponent(0.38).cgColor)
                context.setLineWidth(max(0.8, rect.width * 0.024))
                let spacing = max(4, rect.width * 0.16)
                var x = insetRect.minX + spacing * 0.5
                while x < insetRect.maxX {
                    context.move(to: CGPoint(x: x, y: insetRect.minY))
                    context.addLine(to: CGPoint(x: x, y: insetRect.maxY))
                    x += spacing
                }
                var y = insetRect.minY + spacing * 0.5
                while y < insetRect.maxY {
                    context.move(to: CGPoint(x: insetRect.minX, y: y))
                    context.addLine(to: CGPoint(x: insetRect.maxX, y: y))
                    y += spacing
                }
                context.strokePath()
            case .pulseCore:
                let coreRect = insetRect.insetBy(dx: insetRect.width * 0.28, dy: insetRect.height * 0.28)
                if let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [
                        skin.highlightColor.withAlphaComponent(0.85).cgColor,
                        skin.baseColor.withAlphaComponent(0.42).cgColor,
                        SKColor.clear.cgColor
                    ] as CFArray,
                    locations: [0.0, 0.5, 1.0]
                ) {
                    context.drawRadialGradient(
                        gradient,
                        startCenter: CGPoint(x: coreRect.midX, y: coreRect.midY),
                        startRadius: 0,
                        endCenter: CGPoint(x: coreRect.midX, y: coreRect.midY),
                        endRadius: coreRect.width * 0.95,
                        options: []
                    )
                }
            case .glitchSkin:
                for index in 0..<4 {
                    let barHeight = insetRect.height * 0.1
                    let y = insetRect.minY + insetRect.height * (0.16 + CGFloat(index) * 0.18)
                    let offset = index.isMultiple(of: 2) ? insetRect.width * 0.08 : -insetRect.width * 0.06
                    let bar = CGRect(x: insetRect.minX + offset, y: y, width: insetRect.width * 0.82, height: barHeight)
                    context.setFillColor((index == 1 ? skin.highlightColor : skin.baseColor).withAlphaComponent(0.26).cgColor)
                    context.fill(bar)
                }
            case .energyStripes:
                context.setStrokeColor(skin.highlightColor.withAlphaComponent(0.4).cgColor)
                context.setLineWidth(max(1, rect.width * 0.06))
                let spacing = max(6, rect.width * 0.22)
                var x = insetRect.minX - insetRect.height
                while x < insetRect.maxX + insetRect.height {
                    context.move(to: CGPoint(x: x, y: insetRect.maxY))
                    context.addLine(to: CGPoint(x: x + insetRect.height, y: insetRect.minY))
                    x += spacing
                }
                context.strokePath()
            case .dualCore:
                context.setStrokeColor(skin.highlightColor.withAlphaComponent(0.38).cgColor)
                context.setLineWidth(max(1, rect.width * 0.024))
                let nodes: [CGPoint] = [
                    CGPoint(x: insetRect.minX + insetRect.width * 0.22, y: insetRect.minY + insetRect.height * 0.26),
                    CGPoint(x: insetRect.midX, y: insetRect.minY + insetRect.height * 0.18),
                    CGPoint(x: insetRect.maxX - insetRect.width * 0.2, y: insetRect.minY + insetRect.height * 0.34),
                    CGPoint(x: insetRect.minX + insetRect.width * 0.28, y: insetRect.maxY - insetRect.height * 0.24),
                    CGPoint(x: insetRect.maxX - insetRect.width * 0.24, y: insetRect.maxY - insetRect.height * 0.2)
                ]
                for point in nodes {
                    for other in nodes where other != point {
                        if abs(point.x - other.x) + abs(point.y - other.y) < insetRect.width * 0.82 {
                            context.move(to: point)
                            context.addLine(to: other)
                        }
                    }
                }
                context.strokePath()
                context.setFillColor(skin.highlightColor.withAlphaComponent(0.55).cgColor)
                for node in nodes {
                    context.fillEllipse(in: CGRect(x: node.x - rect.width * 0.035, y: node.y - rect.width * 0.035, width: rect.width * 0.07, height: rect.width * 0.07))
                }
            case .quantumFracture:
                if let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [
                        skin.highlightColor.withAlphaComponent(0.48).cgColor,
                        skin.baseColor.withAlphaComponent(0.26).cgColor,
                        skin.deepColor.withAlphaComponent(0.08).cgColor
                    ] as CFArray,
                    locations: [0.0, 0.55, 1.0]
                ) {
                    context.drawLinearGradient(
                        gradient,
                        start: CGPoint(x: insetRect.minX, y: insetRect.minY),
                        end: CGPoint(x: insetRect.maxX, y: insetRect.maxY),
                        options: []
                    )
                }
                context.setStrokeColor(skin.highlightColor.withAlphaComponent(0.42).cgColor)
                context.setLineWidth(max(1, rect.width * 0.03))
                let fractures = [
                    (CGPoint(x: insetRect.minX + insetRect.width * 0.16, y: insetRect.minY + insetRect.height * 0.2), CGPoint(x: insetRect.midX, y: insetRect.maxY - insetRect.height * 0.14)),
                    (CGPoint(x: insetRect.midX - insetRect.width * 0.06, y: insetRect.minY + insetRect.height * 0.16), CGPoint(x: insetRect.maxX - insetRect.width * 0.18, y: insetRect.midY)),
                    (CGPoint(x: insetRect.minX + insetRect.width * 0.28, y: insetRect.maxY - insetRect.height * 0.18), CGPoint(x: insetRect.maxX - insetRect.width * 0.14, y: insetRect.maxY - insetRect.height * 0.3))
                ]
                for fracture in fractures {
                    context.move(to: fracture.0)
                    context.addLine(to: fracture.1)
                }
                context.strokePath()
            default:
                break
            }

            context.restoreGState()
        }
    }

    func orbTexture(size: CGSize) -> SKTexture {
        texture(key: "orb", size: size) { context, rect in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = min(rect.width, rect.height) / 2
            context.setFillColor(GlossyPalette.orb.cgColor)
            context.addEllipse(in: rect)
            context.fillPath()

            let highlightRadius = radius * 0.4
            let highlightRect = CGRect(x: center.x - highlightRadius, y: rect.minY + radius * 0.2, width: highlightRadius * 2, height: highlightRadius * 2)
            context.setFillColor(SKColor(white: 1.0, alpha: 0.3).cgColor)
            context.fillEllipse(in: highlightRect)
        }
    }

    func trailParticleTexture(size: CGSize, style: TrailStyle) -> SKTexture {
        texture(key: "trail_\(style.rawValue)", size: size) { context, rect in
            let fillColor = style.accentColor
            switch style {
            case .pixelTrail:
                let square = rect.insetBy(dx: rect.width * 0.18, dy: rect.height * 0.18)
                context.setFillColor(fillColor.cgColor)
                context.fill(square)
                context.setStrokeColor(fillColor.withAlphaComponent(0.95).cgColor)
                context.setLineWidth(max(1, rect.width * 0.06))
                context.stroke(square)
            case .electricSparks:
                context.setStrokeColor(fillColor.cgColor)
                context.setLineWidth(max(1, rect.width * 0.12))
                context.move(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.midY))
                context.addLine(to: CGPoint(x: rect.midX - rect.width * 0.06, y: rect.minY + rect.height * 0.2))
                context.addLine(to: CGPoint(x: rect.midX + rect.width * 0.02, y: rect.maxY - rect.height * 0.22))
                context.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.16, y: rect.midY + rect.height * 0.04))
                context.strokePath()
            case .phaseStream, .energyBurst:
                let ellipse = rect.insetBy(dx: rect.width * 0.18, dy: rect.height * 0.18)
                context.setFillColor(fillColor.withAlphaComponent(0.7).cgColor)
                context.fillEllipse(in: ellipse)
                context.setFillColor(fillColor.withAlphaComponent(0.32).cgColor)
                context.fillEllipse(in: ellipse.offsetBy(dx: -rect.width * 0.18, dy: 0))
                context.setFillColor(SKColor.white.withAlphaComponent(0.18).cgColor)
                context.fillEllipse(in: ellipse.insetBy(dx: rect.width * 0.18, dy: rect.height * 0.18))
            default:
                let ellipse = rect.insetBy(dx: rect.width * 0.16, dy: rect.height * 0.16)
                context.setFillColor(fillColor.cgColor)
                context.fillEllipse(in: ellipse)
                let highlightRect = CGRect(
                    x: ellipse.minX + ellipse.width * 0.08,
                    y: ellipse.minY + ellipse.height * 0.08,
                    width: ellipse.width * 0.36,
                    height: ellipse.height * 0.28
                )
                context.setFillColor(SKColor.white.withAlphaComponent(0.18).cgColor)
                context.fillEllipse(in: highlightRect)
            }
        }
    }

    func teleporterTexture(size: CGSize, style: TeleporterSkinStyle = .classicPortal, accentColor: SKColor? = nil) -> SKTexture {
        let accent = accentColor ?? style.accentColor
        return texture(key: "teleporter_\(style.rawValue)_\(Int(accent.hashValue))", size: size) { context, rect in
            let outerRect = rect.insetBy(dx: rect.width * 0.08, dy: rect.height * 0.08)
            let outerPath = CGPath(ellipseIn: outerRect, transform: nil)
            let innerRect = rect.insetBy(dx: rect.width * 0.28, dy: rect.height * 0.28)
            let innerPath = CGPath(ellipseIn: innerRect, transform: nil)

            context.saveGState()
            context.addPath(outerPath)
            context.clip()

            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    blend(accent, with: SKColor.white, ratio: 0.28).cgColor,
                    blend(accent, with: GlossyPalette.accentPink, ratio: 0.22).cgColor
                ] as CFArray,
                locations: [0.0, 1.0]
            ) {
                context.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: rect.midX, y: rect.minY),
                    end: CGPoint(x: rect.midX, y: rect.maxY),
                    options: []
                )
            }

            context.setBlendMode(.clear)
            context.addPath(innerPath)
            context.fillPath()
            context.restoreGState()

            context.addPath(outerPath)
            context.setStrokeColor(blend(accent, with: SKColor.white, ratio: 0.22).cgColor)
            context.setLineWidth(max(1.4, rect.width * 0.08))
            context.strokePath()

            let innerRingRect = rect.insetBy(dx: rect.width * 0.18, dy: rect.height * 0.18)
            context.addEllipse(in: innerRingRect)
            context.setStrokeColor(blend(accent, with: GlossyPalette.accentPink, ratio: 0.5).withAlphaComponent(0.85).cgColor)
            context.setLineWidth(max(1, rect.width * 0.045))
            context.strokePath()

            context.setStrokeColor(SKColor.white.withAlphaComponent(0.22).cgColor)
            context.setLineWidth(max(1, rect.width * 0.028))
            switch style {
            case .classicPortal:
                context.move(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.18))
                context.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.18))
                context.strokePath()
                context.move(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.midY))
                context.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.18, y: rect.midY))
                context.strokePath()
            case .digitalGlitchPortal:
                let segments = [
                    CGRect(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.26, width: rect.width * 0.18, height: rect.height * 0.05),
                    CGRect(x: rect.midX - rect.width * 0.04, y: rect.minY + rect.height * 0.18, width: rect.width * 0.22, height: rect.height * 0.05),
                    CGRect(x: rect.minX + rect.width * 0.24, y: rect.maxY - rect.height * 0.3, width: rect.width * 0.28, height: rect.height * 0.05)
                ]
                context.setFillColor(SKColor.white.withAlphaComponent(0.18).cgColor)
                for segment in segments {
                    context.fill(segment)
                }
            case .energyVortex:
                context.move(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.18))
                context.addCurve(
                    to: CGPoint(x: rect.maxX - rect.width * 0.2, y: rect.midY),
                    control1: CGPoint(x: rect.maxX - rect.width * 0.06, y: rect.minY + rect.height * 0.12),
                    control2: CGPoint(x: rect.maxX - rect.width * 0.02, y: rect.midY - rect.height * 0.08)
                )
                context.strokePath()
            case .splitPortal:
                let arcRect = rect.insetBy(dx: rect.width * 0.14, dy: rect.height * 0.14)
                context.addArc(center: CGPoint(x: arcRect.midX, y: arcRect.midY), radius: arcRect.width * 0.48, startAngle: -.pi * 0.9, endAngle: -.pi * 0.1, clockwise: false)
                context.strokePath()
                context.addArc(center: CGPoint(x: arcRect.midX, y: arcRect.midY), radius: arcRect.width * 0.48, startAngle: .pi * 0.1, endAngle: .pi * 0.9, clockwise: false)
                context.strokePath()
            case .quantumPortal:
                for index in 0..<8 {
                    let angle = CGFloat(index) / 8 * .pi * 2
                    let x = rect.midX + cos(angle) * rect.width * 0.18
                    let y = rect.midY + sin(angle) * rect.height * 0.18
                    let particle = CGRect(x: x - rect.width * 0.035, y: y - rect.width * 0.035, width: rect.width * 0.07, height: rect.width * 0.07)
                    context.setFillColor(accent.withAlphaComponent(0.42 + CGFloat(index % 2) * 0.16).cgColor)
                    context.fillEllipse(in: particle)
                }
            }

            let highlightRect = CGRect(
                x: rect.minX + rect.width * 0.18,
                y: rect.minY + rect.height * 0.12,
                width: rect.width * 0.3,
                height: rect.height * 0.18
            )
            context.setFillColor(SKColor.white.withAlphaComponent(0.16).cgColor)
            context.fillEllipse(in: highlightRect)
        }
    }

    func startTexture(size: CGSize) -> SKTexture {
        texture(key: "start", size: size) { context, rect in
            let corner = rect.height * 0.2
            drawOutline(in: context, rect: rect, cornerRadius: corner, strokeColor: GlossyPalette.accentCyan)
        }
    }

    func exitTexture(size: CGSize) -> SKTexture {
        texture(key: "exit", size: size) { context, rect in
            let corner = rect.height * 0.2
            drawOutline(in: context, rect: rect, cornerRadius: corner, strokeColor: GlossyPalette.accentPink)
        }
    }

    func starOutlineTexture(size: CGSize) -> SKTexture {
        texture(key: "starOutline", size: size) { context, rect in
            let path = starPath(in: rect.insetBy(dx: rect.width * 0.1, dy: rect.height * 0.1))
            context.addPath(path)
            context.setFillColor(SKColor(red: 1.0, green: 0.88, blue: 0.42, alpha: 0.08).cgColor)
            context.fillPath()
            context.addPath(path)
            context.setStrokeColor(SKColor(red: 1.0, green: 0.8, blue: 0.46, alpha: 0.95).cgColor)
            context.setLineWidth(max(1, rect.width * 0.08))
            context.strokePath()
        }
    }

    func starFilledTexture(size: CGSize) -> SKTexture {
        texture(key: "starFilled", size: size) { context, rect in
            let path = starPath(in: rect.insetBy(dx: rect.width * 0.1, dy: rect.height * 0.1))
            context.addPath(path)
            context.saveGState()
            context.clip()
            let top = SKColor(red: 1.0, green: 0.96, blue: 0.72, alpha: 1.0)
            let bottom = SKColor(red: 1.0, green: 0.76, blue: 0.24, alpha: 1.0)
            let colors = [top.cgColor, bottom.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0]) {
                context.drawLinearGradient(gradient, start: CGPoint(x: rect.midX, y: rect.minY), end: CGPoint(x: rect.midX, y: rect.maxY), options: [])
            }
            let highlightRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * 0.34)
            context.setFillColor(SKColor(white: 1.0, alpha: 0.22).cgColor)
            context.fill(highlightRect)
            context.restoreGState()
            context.addPath(path)
            context.setStrokeColor(SKColor(white: 1.0, alpha: 0.9).cgColor)
            context.setLineWidth(max(1, rect.width * 0.06))
            context.strokePath()
        }
    }

    func starGlowTexture(size: CGSize) -> SKTexture {
        texture(key: "starGlow", size: size) { context, rect in
            let inset = rect.width * 0.14
            let path = starPath(in: rect.insetBy(dx: inset, dy: inset))
            context.saveGState()
            context.addPath(path)
            context.clip()

            let top = SKColor(red: 1.0, green: 0.95, blue: 0.68, alpha: 0.55)
            let bottom = SKColor(red: 1.0, green: 0.78, blue: 0.22, alpha: 0.42)
            let colors = [top.cgColor, bottom.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0]) {
                context.drawLinearGradient(gradient, start: CGPoint(x: rect.midX, y: rect.minY), end: CGPoint(x: rect.midX, y: rect.maxY), options: [])
            }

            let highlightRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * 0.4)
            context.setFillColor(SKColor(white: 1.0, alpha: 0.16).cgColor)
            context.fill(highlightRect)
            context.restoreGState()
        }
    }

    private func texture(key: String, size: CGSize, draw: (CGContext, CGRect) -> Void) -> SKTexture {
        let snappedSize = CGSize(width: round(size.width), height: round(size.height))
        let cacheKey = "\(themeKey)_\(key)_\(Int(snappedSize.width))x\(Int(snappedSize.height))"
        if let cached = cache[cacheKey] {
            return cached
        }
        let scale = deviceScale()
        let texture = renderTexture(size: snappedSize, scale: scale, draw: draw)
        cache[cacheKey] = texture
        return texture
    }

    private func renderTexture(size: CGSize, scale: CGFloat, draw: (CGContext, CGRect) -> Void) -> SKTexture {
        #if os(iOS) || os(tvOS)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { ctx in
            draw(ctx.cgContext, CGRect(origin: .zero, size: size))
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
        #else
        let width = max(1, Int(size.width * scale))
        let height = max(1, Int(size.height * scale))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: bitmapInfo) else {
            return SKTexture()
        }
        context.scaleBy(x: scale, y: scale)
        #if os(OSX)
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        #endif
        draw(context, CGRect(origin: .zero, size: size))
        guard let image = context.makeImage() else { return SKTexture() }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        return texture
        #endif
    }

    private func deviceScale() -> CGFloat {
        #if os(iOS) || os(tvOS)
        return max(1, displayScale)
        #elseif os(OSX)
        return NSScreen.main?.backingScaleFactor ?? 2.0
        #else
        return 2.0
        #endif
    }
}

private func drawGlossyRoundedRect(
    in context: CGContext,
    rect: CGRect,
    cornerRadius: CGFloat,
    topColor: SKColor,
    bottomColor: SKColor,
    borderColor: SKColor,
    highlightAlpha: CGFloat = 0.12,
    shadowAlpha: CGFloat = 0.09,
    innerStrokeAlpha: CGFloat = 0.05
) {
    let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    context.saveGState()
    context.addPath(path)
    context.clip()

    let colors = [topColor.cgColor, bottomColor.cgColor] as CFArray
    guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0]) else {
        context.restoreGState()
        return
    }

    context.drawLinearGradient(gradient, start: CGPoint(x: rect.midX, y: rect.minY), end: CGPoint(x: rect.midX, y: rect.maxY), options: [])

    let highlightInsetX = max(3, rect.width * 0.08)
    let highlightInsetY = max(2, rect.height * 0.065)
    let highlightRect = CGRect(
        x: rect.minX + highlightInsetX,
        y: rect.minY + highlightInsetY,
        width: rect.width - highlightInsetX * 2,
        height: rect.height * 0.115
    )
    let highlightPath = CGPath(
        roundedRect: highlightRect,
        cornerWidth: max(2, cornerRadius * 0.65),
        cornerHeight: max(2, cornerRadius * 0.65),
        transform: nil
    )
    context.addPath(highlightPath)
    context.setFillColor(SKColor(white: 1.0, alpha: highlightAlpha).cgColor)
    context.fillPath()

    let lowerShadowRect = CGRect(
        x: rect.minX,
        y: rect.maxY - rect.height * 0.21,
        width: rect.width,
        height: rect.height * 0.21
    )
    context.setFillColor(SKColor(white: 0.0, alpha: shadowAlpha).cgColor)
    context.fill(lowerShadowRect)

    let innerGlowRect = rect.insetBy(dx: rect.width * 0.02, dy: rect.height * 0.02)
    let innerGlowPath = CGPath(roundedRect: innerGlowRect, cornerWidth: max(1, cornerRadius - 2), cornerHeight: max(1, cornerRadius - 2), transform: nil)
    context.addPath(innerGlowPath)
    context.setStrokeColor(SKColor(white: 1.0, alpha: innerStrokeAlpha).cgColor)
    context.setLineWidth(0.8)
    context.strokePath()

    context.restoreGState()

    let strokeRect = rect.insetBy(dx: 0.5, dy: 0.5)
    let strokePath = CGPath(roundedRect: strokeRect, cornerWidth: max(1, cornerRadius - 0.5), cornerHeight: max(1, cornerRadius - 0.5), transform: nil)
    context.addPath(strokePath)
    context.setStrokeColor(borderColor.cgColor)
    context.setLineWidth(1)
    context.strokePath()

    let innerRect = rect.insetBy(dx: 1, dy: 1)
    let innerPath = CGPath(roundedRect: innerRect, cornerWidth: max(1, cornerRadius - 1), cornerHeight: max(1, cornerRadius - 1), transform: nil)
    context.addPath(innerPath)
    context.setStrokeColor(SKColor(white: 0.0, alpha: 0.12).cgColor)
    context.setLineWidth(0.8)
    context.strokePath()
}

private func drawWallTile(in context: CGContext, rect: CGRect, variant: Int) {
    let normalizedVariant = ((variant % 3) + 3) % 3
    let cornerRadius = rect.height * 0.1
    let brightnessShift: [CGFloat] = [0.0, 0.06, -0.05]
    let glowStrength: [CGFloat] = [0.28, 0.22, 0.34]
    let seamAlpha: [CGFloat] = [0.22, 0.16, 0.26]

    let topColor = blend(GlossyPalette.wallTop, with: SKColor.white, ratio: brightnessShift[normalizedVariant])
    let bottomColor = blend(GlossyPalette.wallBottom, with: SKColor.black, ratio: 0.16 - brightnessShift[normalizedVariant] * 0.5)
    let outerPath = CGPath(
        roundedRect: rect.insetBy(dx: rect.width * 0.015, dy: rect.height * 0.015),
        cornerWidth: cornerRadius,
        cornerHeight: cornerRadius,
        transform: nil
    )

    context.saveGState()
    context.addPath(outerPath)
    context.clip()

    if let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [topColor.cgColor, bottomColor.cgColor] as CFArray,
        locations: [0.0, 1.0]
    ) {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.midX, y: rect.minY),
            end: CGPoint(x: rect.midX, y: rect.maxY),
            options: []
        )
    }

    let lowerShadowRect = CGRect(x: rect.minX, y: rect.maxY - rect.height * 0.24, width: rect.width, height: rect.height * 0.24)
    context.setFillColor(SKColor(white: 0.0, alpha: 0.15 + glowStrength[normalizedVariant] * 0.16).cgColor)
    context.fill(lowerShadowRect)

    let topStrip = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * 0.2)
    context.setFillColor(SKColor(white: 1.0, alpha: 0.18 + glowStrength[normalizedVariant] * 0.22).cgColor)
    context.fill(topStrip)

    let innerGlow = rect.insetBy(dx: rect.width * 0.1, dy: rect.height * 0.14)
    if let glowGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            GlossyPalette.accentCyan.withAlphaComponent(glowStrength[normalizedVariant] * 0.24).cgColor,
            SKColor.clear.cgColor
        ] as CFArray,
        locations: [0.0, 1.0]
    ) {
        context.drawRadialGradient(
            glowGradient,
            startCenter: CGPoint(x: innerGlow.midX, y: innerGlow.midY),
            startRadius: 0,
            endCenter: CGPoint(x: innerGlow.midX, y: innerGlow.midY),
            endRadius: max(innerGlow.width, innerGlow.height) * 0.7,
            options: []
        )
    }

    let seamColor = GlossyPalette.accentCyan.withAlphaComponent(seamAlpha[normalizedVariant])
    let leftSeam = CGRect(x: rect.minX + rect.width * 0.035, y: rect.minY + rect.height * 0.1, width: rect.width * 0.035, height: rect.height * 0.78)
    let rightSeam = CGRect(x: rect.maxX - rect.width * 0.07, y: rect.minY + rect.height * 0.12, width: rect.width * 0.026, height: rect.height * 0.72)
    context.setFillColor(seamColor.cgColor)
    context.fill(leftSeam)
    context.fill(rightSeam)

    let bandY: [CGFloat] = [0.35, 0.48, 0.62]
    let bandRect = CGRect(
        x: rect.minX + rect.width * 0.14,
        y: rect.minY + rect.height * bandY[normalizedVariant],
        width: rect.width * 0.7,
        height: max(1, rect.height * 0.055)
    )
    context.setFillColor(SKColor(white: 1.0, alpha: 0.06 + glowStrength[normalizedVariant] * 0.1).cgColor)
    context.fill(bandRect)

    let notchRect = CGRect(
        x: rect.minX + rect.width * (0.22 + CGFloat(normalizedVariant) * 0.12),
        y: rect.minY + rect.height * 0.18,
        width: rect.width * 0.16,
        height: max(1, rect.height * 0.05)
    )
    context.setFillColor(GlossyPalette.accentCyan.withAlphaComponent(0.14 + glowStrength[normalizedVariant] * 0.14).cgColor)
    context.fill(notchRect)

    context.restoreGState()

    context.addPath(outerPath)
    context.setStrokeColor(blend(GlossyPalette.accentCyan, with: SKColor.white, ratio: 0.22).cgColor)
    context.setLineWidth(1.2)
    context.strokePath()

    let insetPath = CGPath(
        roundedRect: rect.insetBy(dx: rect.width * 0.08, dy: rect.height * 0.08),
        cornerWidth: max(2, cornerRadius - 2),
        cornerHeight: max(2, cornerRadius - 2),
        transform: nil
    )
    context.addPath(insetPath)
    context.setStrokeColor(SKColor(white: 1.0, alpha: 0.08 + glowStrength[normalizedVariant] * 0.08).cgColor)
    context.setLineWidth(0.8)
    context.strokePath()
}

private func drawFloorTile(in context: CGContext, rect: CGRect, variant: Int) {
    let normalizedVariant = ((variant % 3) + 3) % 3
    let cornerRadius = rect.height * 0.08
    let topShift: [CGFloat] = [0.0, 0.04, -0.03]
    let lineAlpha: [CGFloat] = [0.11, 0.08, 0.14]

    let topColor = blend(GlossyPalette.floorTop, with: GlossyPalette.accentCyan, ratio: 0.04 + max(0, topShift[normalizedVariant]))
    let bottomColor = blend(GlossyPalette.floorBottom, with: SKColor.black, ratio: 0.22)
    let path = CGPath(
        roundedRect: rect.insetBy(dx: rect.width * 0.01, dy: rect.height * 0.01),
        cornerWidth: cornerRadius,
        cornerHeight: cornerRadius,
        transform: nil
    )

    context.saveGState()
    context.addPath(path)
    context.clip()

    if let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [topColor.cgColor, bottomColor.cgColor] as CFArray,
        locations: [0.0, 1.0]
    ) {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.midX, y: rect.minY),
            end: CGPoint(x: rect.midX, y: rect.maxY),
            options: []
        )
    }

    let reflectiveStrip = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * 0.16)
    context.setFillColor(SKColor(white: 1.0, alpha: 0.06).cgColor)
    context.fill(reflectiveStrip)

    let lowerShadowRect = CGRect(x: rect.minX, y: rect.maxY - rect.height * 0.18, width: rect.width, height: rect.height * 0.18)
    context.setFillColor(SKColor(white: 0.0, alpha: 0.12).cgColor)
    context.fill(lowerShadowRect)

    context.setStrokeColor(GlossyPalette.accentCyan.withAlphaComponent(lineAlpha[normalizedVariant]).cgColor)
    context.setLineWidth(max(0.6, rect.width * 0.025))
    let midY = rect.midY + rect.height * (normalizedVariant == 1 ? -0.08 : 0.02)
    context.move(to: CGPoint(x: rect.minX + rect.width * 0.14, y: midY))
    context.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.14, y: midY))
    context.strokePath()

    context.setStrokeColor(SKColor(white: 1.0, alpha: 0.05 + lineAlpha[normalizedVariant] * 0.35).cgColor)
    context.setLineWidth(max(0.5, rect.width * 0.018))
    switch normalizedVariant {
    case 0:
        context.move(to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.maxY - rect.height * 0.18))
        context.addLine(to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.minY + rect.height * 0.2))
    case 1:
        context.move(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.maxY - rect.height * 0.22))
        context.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.18, y: rect.minY + rect.height * 0.22))
    default:
        context.move(to: CGPoint(x: rect.maxX - rect.width * 0.22, y: rect.maxY - rect.height * 0.18))
        context.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.22, y: rect.minY + rect.height * 0.2))
    }
    context.strokePath()

    let dotRect = CGRect(
        x: rect.minX + rect.width * (0.2 + CGFloat(normalizedVariant) * 0.18),
        y: rect.minY + rect.height * 0.22,
        width: rect.width * 0.08,
        height: rect.width * 0.08
    )
    context.setFillColor(GlossyPalette.accentCyan.withAlphaComponent(0.08 + lineAlpha[normalizedVariant] * 0.3).cgColor)
    context.fillEllipse(in: dotRect)

    context.restoreGState()

    context.addPath(path)
    context.setStrokeColor(SKColor(white: 1.0, alpha: 0.045).cgColor)
    context.setLineWidth(0.7)
    context.strokePath()
}

private func drawActiveFloorPulse(in context: CGContext, rect: CGRect, variant: Int) {
    let normalizedVariant = ((variant % 3) + 3) % 3
    let color = blend(GlossyPalette.accentCyan, with: GlossyPalette.accentPink, ratio: normalizedVariant == 1 ? 0.18 : 0.08)
    let barHeight = rect.height * 0.08

    if let glowGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            color.withAlphaComponent(0.24).cgColor,
            SKColor.clear.cgColor
        ] as CFArray,
        locations: [0.0, 1.0]
    ) {
        context.drawRadialGradient(
            glowGradient,
            startCenter: CGPoint(x: rect.midX, y: rect.midY),
            startRadius: 0,
            endCenter: CGPoint(x: rect.midX, y: rect.midY),
            endRadius: max(rect.width, rect.height) * 0.52,
            options: []
        )
    }

    let mainBar = CGRect(
        x: rect.minX + rect.width * 0.18,
        y: rect.midY - barHeight / 2,
        width: rect.width * 0.64,
        height: barHeight
    )
    context.setFillColor(color.withAlphaComponent(0.38).cgColor)
    context.fill(mainBar)

    if normalizedVariant != 2 {
        let shortBar = CGRect(
            x: rect.minX + rect.width * 0.26,
            y: rect.minY + rect.height * 0.24,
            width: rect.width * (normalizedVariant == 0 ? 0.24 : 0.18),
            height: max(1, barHeight * 0.9)
        )
        context.setFillColor(color.withAlphaComponent(0.26).cgColor)
        context.fill(shortBar)
    }
}

private func blend(_ color: SKColor, with other: SKColor, ratio: CGFloat) -> SKColor {
    let clamped = max(0, min(1, ratio))
    #if os(iOS) || os(tvOS)
    var r1: CGFloat = 0
    var g1: CGFloat = 0
    var b1: CGFloat = 0
    var a1: CGFloat = 0
    var r2: CGFloat = 0
    var g2: CGFloat = 0
    var b2: CGFloat = 0
    var a2: CGFloat = 0
    color.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
    other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
    #else
    let c1 = color.usingColorSpace(.deviceRGB) ?? color
    let c2 = other.usingColorSpace(.deviceRGB) ?? other
    var r1: CGFloat = 0
    var g1: CGFloat = 0
    var b1: CGFloat = 0
    var a1: CGFloat = 0
    var r2: CGFloat = 0
    var g2: CGFloat = 0
    var b2: CGFloat = 0
    var a2: CGFloat = 0
    c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
    c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
    #endif
    return SKColor(
        red: r1 + (r2 - r1) * clamped,
        green: g1 + (g2 - g1) * clamped,
        blue: b1 + (b2 - b1) * clamped,
        alpha: a1 + (a2 - a1) * clamped
    )
}

private func drawOutline(in context: CGContext, rect: CGRect, cornerRadius: CGFloat, strokeColor: SKColor) {
    let path = CGPath(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    context.addPath(path)
    context.setStrokeColor(strokeColor.cgColor)
    context.setLineWidth(2)
    context.strokePath()
}

private func starPath(in rect: CGRect) -> CGPath {
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let outerRadius = min(rect.width, rect.height) * 0.5
    let innerRadius = outerRadius * 0.5
    let points = 5
    let path = CGMutablePath()

    for i in 0..<(points * 2) {
        let angle = (CGFloat(i) * .pi / CGFloat(points)) - (.pi / 2)
        let radius = (i % 2 == 0) ? outerRadius : innerRadius
        let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        if i == 0 {
            path.move(to: point)
        } else {
            path.addLine(to: point)
        }
    }
    path.closeSubpath()
    return path
}
