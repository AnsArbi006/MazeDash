import SpriteKit

enum NeonPalette {
    static let backgroundTop = SKColor(red: 0.04, green: 0.06, blue: 0.12, alpha: 1.0)   // #0A0F1F
    static let backgroundBottom = SKColor(red: 0.02, green: 0.03, blue: 0.05, alpha: 1.0) // #05070D
    static let neonCyan = SKColor(red: 0.0, green: 0.83, blue: 1.0, alpha: 1.0)           // #00D4FF
    static let neonBlue = SKColor(red: 0.0, green: 0.6, blue: 0.8, alpha: 1.0)             // #0099CC
    static let neonPink = SKColor(red: 1.0, green: 0.18, blue: 0.6, alpha: 1.0)            // #FF2D9A
    static let neonGreen = SKColor(red: 0.32, green: 1.0, blue: 0.55, alpha: 1.0)
    static let neonYellow = SKColor(red: 1.0, green: 0.72, blue: 0.0, alpha: 1.0)          // #FFB800
    static let panelFill = SKColor(red: 0.08, green: 0.1, blue: 0.16, alpha: 0.88)
}

enum ShellScreenTransitionDirection {
    case forward
    case backward
    case neutral
}

enum ShellMotion {
    static func screenTransition(_ direction: ShellScreenTransitionDirection) -> SKTransition {
        let transition: SKTransition
        switch direction {
        case .forward:
            transition = .push(with: .left, duration: 0.34)
        case .backward:
            transition = .push(with: .right, duration: 0.30)
        case .neutral:
            transition = .crossFade(withDuration: 0.2)
        }
        transition.pausesIncomingScene = false
        transition.pausesOutgoingScene = false
        return transition
    }

    static func prepareOverlay(dimNode: SKSpriteNode, cardNode: SKSpriteNode, restPosition: CGPoint) {
        dimNode.removeAllActions()
        cardNode.removeAllActions()
        dimNode.alpha = 0
        cardNode.alpha = 0
        cardNode.setScale(0.975)
        cardNode.position = CGPoint(x: restPosition.x, y: restPosition.y - 10)
    }

    static func animateOverlayIn(dimNode: SKSpriteNode, cardNode: SKSpriteNode, restPosition: CGPoint, completion: (() -> Void)? = nil) {
        prepareOverlay(dimNode: dimNode, cardNode: cardNode, restPosition: restPosition)

        dimNode.run(timed(.fadeAlpha(to: 1.0, duration: 0.16), mode: .easeOut))

        let move = timed(.move(to: restPosition, duration: 0.2), mode: .easeOut)
        let fade = timed(.fadeIn(withDuration: 0.18), mode: .easeOut)
        let scale = timed(.scale(to: 1.0, duration: 0.2), mode: .easeOut)
        let group = SKAction.group([move, fade, scale])
        if let completion {
            cardNode.run(.sequence([group, .run(completion)]), withKey: "overlayIn")
        } else {
            cardNode.run(group, withKey: "overlayIn")
        }
    }

    static func animateOverlayOut(dimNode: SKSpriteNode, cardNode: SKSpriteNode, restPosition: CGPoint, completion: (() -> Void)? = nil) {
        dimNode.removeAllActions()
        cardNode.removeAllActions()

        dimNode.run(timed(.fadeOut(withDuration: 0.14), mode: .easeIn))

        let exitPosition = CGPoint(x: restPosition.x, y: restPosition.y - 8)
        let move = timed(.move(to: exitPosition, duration: 0.14), mode: .easeIn)
        let fade = timed(.fadeOut(withDuration: 0.14), mode: .easeIn)
        let scale = timed(.scale(to: 0.988, duration: 0.14), mode: .easeIn)
        let group = SKAction.group([move, fade, scale])
        if let completion {
            cardNode.run(.sequence([group, .run(completion)]), withKey: "overlayOut")
        } else {
            cardNode.run(group, withKey: "overlayOut")
        }
    }

    private static func timed(_ action: SKAction, mode: SKActionTimingMode) -> SKAction {
        action.timingMode = mode
        return action
    }
}

struct NeonFactory {
    static func backgroundNode(size: CGSize, theme: MazeTheme? = nil) -> SKSpriteNode {
        let colors = backgroundColors(for: theme)
        let texture = gradientTexture(size: size, colors: colors)
        let node = SKSpriteNode(texture: texture)
        node.size = size
        node.position = CGPoint(x: 0, y: 0)
        node.zPosition = -100
        return node
    }

    private static func backgroundColors(for theme: MazeTheme?) -> [SKColor] {
        guard let theme = theme else {
            return [NeonPalette.backgroundBottom, NeonPalette.backgroundTop]
        }
        switch theme {
        case .defaultTheme:
            return [NeonPalette.backgroundBottom, NeonPalette.backgroundTop]
        case .vaporwave:
            return [SKColor(red: 0.08, green: 0.05, blue: 0.16, alpha: 1.0), SKColor(red: 0.2, green: 0.1, blue: 0.36, alpha: 1.0)]
        case .neonMint:
            return [SKColor(red: 0.04, green: 0.08, blue: 0.12, alpha: 1.0), SKColor(red: 0.08, green: 0.2, blue: 0.18, alpha: 1.0)]
        case .sunsetPulse:
            return [SKColor(red: 0.1, green: 0.05, blue: 0.08, alpha: 1.0), SKColor(red: 0.22, green: 0.08, blue: 0.1, alpha: 1.0)]
        case .arctic:
            return [SKColor(red: 0.05, green: 0.08, blue: 0.16, alpha: 1.0), SKColor(red: 0.12, green: 0.16, blue: 0.28, alpha: 1.0)]
        case .ember:
            return [SKColor(red: 0.12, green: 0.04, blue: 0.06, alpha: 1.0), SKColor(red: 0.22, green: 0.08, blue: 0.08, alpha: 1.0)]
        case .nightSignal:
            return [SKColor(red: 0.03, green: 0.04, blue: 0.10, alpha: 1.0), SKColor(red: 0.08, green: 0.11, blue: 0.22, alpha: 1.0)]
        case .prismShift:
            return [SKColor(red: 0.08, green: 0.06, blue: 0.12, alpha: 1.0), SKColor(red: 0.18, green: 0.12, blue: 0.24, alpha: 1.0)]
        }
    }

    static func gradientTexture(size: CGSize, colors: [SKColor]) -> SKTexture {
        let width = max(Int(size.width), 2)
        let height = max(Int(size.height), 2)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return SKTexture()
        }

        let cgColors = colors.map { $0.cgColor } as CFArray
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: cgColors, locations: nil) else {
            return SKTexture()
        }

        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: 0, y: CGFloat(height)),
            options: []
        )

        guard let image = context.makeImage() else { return SKTexture() }
        return SKTexture(cgImage: image)
    }

    static func gridOverlayTexture(size: CGSize, theme: MazeTheme? = nil) -> SKTexture {
        let accent = accentColor(for: theme)
        return renderTexture(size: size) { context, rect in
            context.setStrokeColor(accent.withAlphaComponent(0.11).cgColor)
            context.setLineWidth(1)

            let majorSpacing = max(44, rect.width / 10)
            let minorSpacing = max(20, majorSpacing * 0.42)

            var x: CGFloat = 0
            while x <= rect.width {
                let isMajor = Int(round(x / minorSpacing)).isMultiple(of: 2)
                context.setStrokeColor(accent.withAlphaComponent(isMajor ? 0.12 : 0.05).cgColor)
                context.move(to: CGPoint(x: x, y: 0))
                context.addLine(to: CGPoint(x: x, y: rect.height))
                context.strokePath()
                x += minorSpacing
            }

            var y: CGFloat = 0
            while y <= rect.height {
                let isMajor = Int(round(y / majorSpacing)).isMultiple(of: 2)
                context.setStrokeColor(accent.withAlphaComponent(isMajor ? 0.1 : 0.04).cgColor)
                context.move(to: CGPoint(x: 0, y: y))
                context.addLine(to: CGPoint(x: rect.width, y: y))
                context.strokePath()
                y += minorSpacing
            }
        }
    }

    static func glowFieldTexture(size: CGSize, theme: MazeTheme? = nil) -> SKTexture {
        let accent = accentColor(for: theme)
        let secondary = secondaryAccentColor(for: theme)
        return renderTexture(size: size) { context, rect in
            drawGlowOrb(in: context, rect: rect, center: CGPoint(x: rect.width * 0.18, y: rect.height * 0.84), radius: rect.width * 0.36, color: accent.withAlphaComponent(0.22))
            drawGlowOrb(in: context, rect: rect, center: CGPoint(x: rect.width * 0.78, y: rect.height * 0.2), radius: rect.width * 0.28, color: secondary.withAlphaComponent(0.14))
            drawGlowOrb(in: context, rect: rect, center: CGPoint(x: rect.width * 0.58, y: rect.height * 0.62), radius: rect.width * 0.18, color: accent.withAlphaComponent(0.08))
        }
    }

    static func sparkTexture(size: CGSize, theme: MazeTheme? = nil) -> SKTexture {
        let accent = accentColor(for: theme)
        let secondary = secondaryAccentColor(for: theme)
        return renderTexture(size: size) { context, rect in
            let points: [(CGFloat, CGFloat, CGFloat, Bool)] = [
                (0.12, 0.22, 1.6, true),
                (0.27, 0.78, 1.1, false),
                (0.44, 0.38, 1.3, true),
                (0.68, 0.58, 1.8, false),
                (0.82, 0.3, 1.4, true),
                (0.9, 0.82, 1.2, false)
            ]
            for point in points {
                let color = point.3 ? accent : secondary
                let dotRect = CGRect(
                    x: rect.width * point.0,
                    y: rect.height * point.1,
                    width: point.2,
                    height: point.2
                )
                context.setFillColor(color.withAlphaComponent(0.48).cgColor)
                context.fillEllipse(in: dotRect)
            }
        }
    }

    static func scanBandTexture(size: CGSize, theme: MazeTheme? = nil) -> SKTexture {
        let accent = accentColor(for: theme)
        return renderTexture(size: size) { context, rect in
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    SKColor.clear.cgColor,
                    accent.withAlphaComponent(0.0).cgColor,
                    accent.withAlphaComponent(0.16).cgColor,
                    SKColor.clear.cgColor
                ] as CFArray,
                locations: [0.0, 0.25, 0.5, 1.0]
            ) {
                context.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: rect.minX, y: rect.midY),
                    end: CGPoint(x: rect.maxX, y: rect.midY),
                    options: []
                )
            }
        }
    }

    static func panelNode(size: CGSize) -> SKShapeNode {
        let node = SKShapeNode(rectOf: size, cornerRadius: 12)
        node.fillColor = NeonPalette.panelFill
        node.strokeColor = NeonPalette.neonBlue
        node.lineWidth = 2
        node.glowWidth = 4
        return node
    }

    static func wallNode(size: CGSize) -> SKShapeNode {
        let node = SKShapeNode(rectOf: size, cornerRadius: 4)
        node.fillColor = NeonPalette.neonCyan
        node.strokeColor = NeonPalette.neonBlue
        node.lineWidth = 2
        node.glowWidth = 6
        return node
    }

    static func floorNode(size: CGSize) -> SKShapeNode {
        let node = SKShapeNode(rectOf: size, cornerRadius: 2)
        node.fillColor = SKColor(red: 0.06, green: 0.08, blue: 0.12, alpha: 1.0)
        node.strokeColor = SKColor(red: 0.12, green: 0.14, blue: 0.2, alpha: 0.6)
        node.lineWidth = 1
        return node
    }

    static func orbNode(radius: CGFloat) -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: radius)
        node.fillColor = NeonPalette.neonYellow
        node.strokeColor = NeonPalette.neonPink
        node.lineWidth = 2
        node.glowWidth = 8
        return node
    }

    static func emitter(color: SKColor, size: CGFloat, birthRate: CGFloat, lifetime: CGFloat, numParticles: Int? = nil) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1
        emitter.particleBirthRate = birthRate
        emitter.particleLifetime = lifetime
        emitter.particleLifetimeRange = lifetime * 0.4
        emitter.particleSpeed = size * 0.6
        emitter.particleSpeedRange = size * 0.4
        emitter.particleScale = 0.15
        emitter.particleScaleRange = 0.1
        emitter.particleAlpha = 0.9
        emitter.particleAlphaRange = 0.2
        emitter.particleAlphaSpeed = -0.5
        emitter.emissionAngleRange = .pi * 2
        emitter.particlePositionRange = CGVector(dx: size * 0.3, dy: size * 0.3)
        emitter.particleBlendMode = .add
        if let count = numParticles {
            emitter.numParticlesToEmit = count
        }
        return emitter
    }

    private static func renderTexture(size: CGSize, draw: (CGContext, CGRect) -> Void) -> SKTexture {
        let width = max(Int(size.width), 2)
        let height = max(Int(size.height), 2)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return SKTexture()
        }

        draw(context, CGRect(origin: .zero, size: size))
        guard let image = context.makeImage() else { return SKTexture() }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        return texture
    }

    private static func accentColor(for theme: MazeTheme?) -> SKColor {
        theme?.palette.accentCyan ?? NeonPalette.neonCyan
    }

    private static func secondaryAccentColor(for theme: MazeTheme?) -> SKColor {
        theme?.palette.accentPink ?? NeonPalette.neonPink
    }

    private static func drawGlowOrb(in context: CGContext, rect: CGRect, center: CGPoint, radius: CGFloat, color: SKColor) {
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [color.cgColor, SKColor.clear.cgColor] as CFArray,
            locations: [0.0, 1.0]
        ) else {
            return
        }
        context.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: radius,
            options: []
        )
    }
}

final class NeonButtonNode: SKShapeNode {
    let label: SKLabelNode
    var onTap: (() -> Void)?
    private(set) var isEnabled: Bool = true

    init(text: String, size: CGSize) {
        label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        super.init()
        path = CGPath(roundedRect: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height), cornerWidth: 12, cornerHeight: 12, transform: nil)
        fillColor = NeonPalette.panelFill
        strokeColor = NeonPalette.neonPink
        lineWidth = 2
        glowWidth = 4

        label.text = text
        label.fontSize = 18
        label.fontColor = SKColor.white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 2
        addChild(label)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        alpha = enabled ? 1.0 : 0.4
    }
}

extension SKScene {
    func buttonNode(at point: CGPoint) -> NeonButtonNode? {
        for node in nodes(at: point) {
            if let button = node as? NeonButtonNode {
                return button
            }
            if let button = node.parent as? NeonButtonNode {
                return button
            }
        }
        return nil
    }
}
