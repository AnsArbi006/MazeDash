import SpriteKit

final class ArcadeButtonNode: SKSpriteNode {
    enum State {
        case normal
        case pressed
        case disabled
    }

    enum EmphasisStyle {
        case none
        case quiet
        case primary
    }

    let label: SKLabelNode
    var onTap: (() -> Void)?
    private(set) var isEnabled: Bool = true
    private var accentColor: SKColor = ArcadeStyle.Color.accentCyan
    private var cardStyle: CardStyle = .button
    private var emphasisStyle: EmphasisStyle = .none

    private let shadowNode = SKSpriteNode(color: SKColor(white: 0.0, alpha: 0.24), size: .zero)
    private let contentCropNode = SKCropNode()
    private let contentMaskNode = SKShapeNode()
    private let overlayNode = SKSpriteNode(color: SKColor(white: 0.0, alpha: 0.35), size: .zero)
    private let shineNode = SKSpriteNode(color: SKColor(white: 1.0, alpha: 0.12), size: .zero)
    private let borderNode = SKShapeNode()
    private var state: State = .normal

    override var size: CGSize {
        didSet {
            updateLayoutForSize()
        }
    }

    init(text: String, size: CGSize) {
        let texture = TextureFactory.shared.cardTexture(size: size, style: .button)
        label = SKLabelNode(fontNamed: ArcadeFont.button)
        super.init(texture: texture, color: .clear, size: size)

        shadowNode.zPosition = -1
        addChild(shadowNode)

        contentCropNode.zPosition = 1
        addChild(contentCropNode)

        contentMaskNode.fillColor = .white
        contentMaskNode.strokeColor = .clear
        contentCropNode.maskNode = contentMaskNode

        overlayNode.size = size
        overlayNode.alpha = 0
        overlayNode.zPosition = 1
        contentCropNode.addChild(overlayNode)

        shineNode.zPosition = 1.5
        contentCropNode.addChild(shineNode)

        let cornerRadius = min(ArcadeStyle.Metric.buttonCornerRadius, size.height * 0.5)
        borderNode.path = CGPath(roundedRect: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        borderNode.strokeColor = ArcadeStyle.Color.panelBorder
        borderNode.lineWidth = 1.9
        borderNode.fillColor = .clear
        borderNode.zPosition = 2.8
        borderNode.glowWidth = 1.2
        addChild(borderNode)

        label.text = text
        label.fontSize = ArcadeStyle.FontSize.button
        label.fontColor = ArcadeStyle.Color.textPrimary
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = .zero
        label.zPosition = 3
        addChild(label)

        updateState(.normal)
        updateLayoutForSize()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        updateState(enabled ? .normal : .disabled)
    }

    func setPressed(_ pressed: Bool) {
        guard isEnabled else { return }
        updateState(pressed ? .pressed : .normal)
    }

    func setAccentColor(_ color: SKColor) {
        accentColor = color
        updateVisualPalette()
    }

    func setCardStyle(_ style: CardStyle) {
        guard cardStyle != style else { return }
        cardStyle = style
        updateLayoutForSize()
        updateVisualPalette()
    }

    func setEmphasisStyle(_ style: EmphasisStyle) {
        emphasisStyle = style
        updateVisualPalette()
    }

    func playConfirmMotion() {
        guard isEnabled else { return }
        removeAction(forKey: "confirmBounce")
        let down = SKAction.scale(to: 0.978, duration: 0.05)
        down.timingMode = .easeOut
        let up = SKAction.scale(to: 1.012, duration: 0.08)
        up.timingMode = .easeInEaseOut
        let settle = SKAction.scale(to: 1.0, duration: 0.12)
        settle.timingMode = .easeInEaseOut
        run(.sequence([down, up, settle]), withKey: "confirmBounce")

        shineNode.removeAction(forKey: "confirmFlash")
        shineNode.run(.sequence([
            .fadeAlpha(to: 0.72, duration: 0.06),
            .fadeAlpha(to: baseShineAlpha(), duration: 0.18)
        ]), withKey: "confirmFlash")

        borderNode.removeAction(forKey: "confirmBorder")
        borderNode.run(.sequence([
            .fadeAlpha(to: 1.0, duration: 0.06),
            .fadeAlpha(to: baseBorderAlpha(), duration: 0.18)
        ]), withKey: "confirmBorder")
    }

    func hitTest(_ point: CGPoint, in scene: SKScene) -> Bool {
        guard isEnabled else { return false }
        let localPoint: CGPoint
        if let camera = scene.camera, inParentHierarchy(camera) {
            let cameraPoint = camera.convert(point, from: scene)
            localPoint = convert(cameraPoint, from: camera)
        } else {
            localPoint = convert(point, from: scene)
        }
        return expandedBounds(slop: hitSlop()).contains(localPoint)
    }

    override func contains(_ p: CGPoint) -> Bool {
        guard isEnabled else { return false }
        return expandedBounds(slop: hitSlop()).contains(p)
    }

    private func hitSlop() -> CGFloat {
        max(18, min(28, min(size.width, size.height) * 0.28))
    }

    private func expandedBounds(slop: CGFloat) -> CGRect {
        CGRect(
            x: -size.width / 2 - slop,
            y: -size.height / 2 - slop,
            width: size.width + slop * 2,
            height: size.height + slop * 2
        )
    }

    private func updateLayoutForSize() {
        guard size.width > 0, size.height > 0 else { return }
        texture = TextureFactory.shared.cardTexture(size: size, style: cardStyle)
        shadowNode.size = CGSize(width: size.width * 0.98, height: size.height * 0.92)
        shadowNode.position = CGPoint(x: 0, y: -max(2, size.height * 0.08))
        shadowNode.alpha = 0.2
        overlayNode.size = size
        let cornerRadius = min(ArcadeStyle.Metric.buttonCornerRadius, size.height * 0.5)
        contentMaskNode.path = CGPath(
            roundedRect: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height),
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        shineNode.size = CGSize(width: size.width * 0.68, height: max(5, size.height * 0.12))
        shineNode.position = CGPoint(x: 0, y: size.height * 0.17)
        borderNode.path = CGPath(roundedRect: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        let baseFont = ArcadeStyle.FontSize.button
        label.fontSize = min(baseFont, max(12, size.height * 0.42))
    }

    private func updateState(_ newState: State) {
        state = newState
        switch newState {
        case .normal:
            overlayNode.alpha = 0
            alpha = 1.0
            setScale(1.0)
            label.fontColor = ArcadeStyle.Color.textPrimary
            shineNode.alpha = baseShineAlpha()
            shadowNode.alpha = 0.2
        case .pressed:
            overlayNode.alpha = 0.18
            alpha = 1.0
            setScale(0.985)
            label.fontColor = ArcadeStyle.Color.textPrimary
            shineNode.alpha = 0.22
            shadowNode.alpha = 0.12
        case .disabled:
            overlayNode.alpha = 0
            alpha = 0.4
            setScale(1.0)
            label.fontColor = ArcadeStyle.Color.textDisabled
            shineNode.alpha = 0.2
            shadowNode.alpha = 0.08
        }
        updateVisualPalette()
    }

    private func updateVisualPalette() {
        switch state {
        case .normal:
            color = accentColor.withAlphaComponent(0.05)
            colorBlendFactor = colorBlendAmount()
            borderNode.alpha = baseBorderAlpha()
            borderNode.strokeColor = mixedColor(accentColor, ArcadeStyle.Color.panelBorder, ratio: 0.45)
            borderNode.glowWidth = 0.6
        case .pressed:
            color = accentColor.withAlphaComponent(0.1)
            colorBlendFactor = max(colorBlendAmount(), 0.14)
            borderNode.alpha = 1.0
            borderNode.strokeColor = mixedColor(accentColor, SKColor.white, ratio: 0.25)
            borderNode.glowWidth = 0.9
        case .disabled:
            color = .clear
            colorBlendFactor = 0.0
            borderNode.alpha = 0.4
            borderNode.strokeColor = ArcadeStyle.Color.textDisabled
            borderNode.glowWidth = 0.0
        }
        updateIdleEmphasis()
    }

    private func baseShineAlpha() -> CGFloat {
        switch emphasisStyle {
        case .none:
            return 0.22
        case .quiet:
            return 0.28
        case .primary:
            return 0.34
        }
    }

    private func baseBorderAlpha() -> CGFloat {
        switch emphasisStyle {
        case .none:
            return 1.0
        case .quiet:
            return 0.94
        case .primary:
            return 1.0
        }
    }

    private func colorBlendAmount() -> CGFloat {
        switch cardStyle {
        case .shellPanel:
            return 0.08
        case .shellFeature:
            return 0.16
        case .shellAccent:
            return 0.2
        default:
            return 0.14
        }
    }

    private func updateIdleEmphasis() {
        shineNode.removeAction(forKey: "idleEmphasis")
        borderNode.removeAction(forKey: "idleEmphasis")
        guard state == .normal, isEnabled else {
            shineNode.position = CGPoint(x: 0, y: size.height * 0.18)
            return
        }

        let baseY = size.height * 0.18
        switch emphasisStyle {
        case .none:
            shineNode.position = CGPoint(x: 0, y: baseY)
        case .quiet:
            let rise = SKAction.moveTo(y: baseY + 2, duration: 1.8)
            rise.timingMode = .easeInEaseOut
            let settle = SKAction.moveTo(y: baseY, duration: 1.8)
            settle.timingMode = .easeInEaseOut
            let brighten = SKAction.fadeAlpha(to: 0.34, duration: 1.8)
            brighten.timingMode = .easeInEaseOut
            let dim = SKAction.fadeAlpha(to: 0.24, duration: 1.8)
            dim.timingMode = .easeInEaseOut
            shineNode.run(.repeatForever(.sequence([.group([rise, brighten]), .group([settle, dim])])), withKey: "idleEmphasis")
        case .primary:
            let rise = SKAction.moveTo(y: baseY + 3, duration: 1.4)
            rise.timingMode = .easeInEaseOut
            let settle = SKAction.moveTo(y: baseY, duration: 1.4)
            settle.timingMode = .easeInEaseOut
            let brighten = SKAction.fadeAlpha(to: 0.42, duration: 1.4)
            brighten.timingMode = .easeInEaseOut
            let dim = SKAction.fadeAlpha(to: 0.28, duration: 1.4)
            dim.timingMode = .easeInEaseOut
            shineNode.run(.repeatForever(.sequence([.group([rise, brighten]), .group([settle, dim])])), withKey: "idleEmphasis")

            let borderBright = SKAction.fadeAlpha(to: 1.0, duration: 1.4)
            borderBright.timingMode = .easeInEaseOut
            let borderDim = SKAction.fadeAlpha(to: 0.9, duration: 1.4)
            borderDim.timingMode = .easeInEaseOut
            borderNode.run(.repeatForever(.sequence([borderBright, borderDim])), withKey: "idleEmphasis")
        }
    }

    private func mixedColor(_ a: SKColor, _ b: SKColor, ratio: CGFloat) -> SKColor {
        let clamped = max(0, min(1, ratio))
        #if os(iOS) || os(tvOS)
        var ar: CGFloat = 0
        var ag: CGFloat = 0
        var ab: CGFloat = 0
        var aa: CGFloat = 0
        var br: CGFloat = 0
        var bg: CGFloat = 0
        var bb: CGFloat = 0
        var ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        #else
        let c1 = a.usingColorSpace(.deviceRGB) ?? a
        let c2 = b.usingColorSpace(.deviceRGB) ?? b
        var ar: CGFloat = 0
        var ag: CGFloat = 0
        var ab: CGFloat = 0
        var aa: CGFloat = 0
        var br: CGFloat = 0
        var bg: CGFloat = 0
        var bb: CGFloat = 0
        var ba: CGFloat = 0
        c1.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        c2.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        #endif
        return SKColor(
            red: ar + (br - ar) * clamped,
            green: ag + (bg - ag) * clamped,
            blue: ab + (bb - ab) * clamped,
            alpha: aa + (ba - aa) * clamped
        )
    }
}

extension SKScene {
    func arcadeButton(at point: CGPoint) -> ArcadeButtonNode? {
        if let button = arcadeButton(in: nodes(at: point)) {
            return button
        }
        if let camera = camera {
            let cameraPoint = camera.convert(point, from: self)
            if let button = arcadeButton(in: camera.nodes(at: cameraPoint)) {
                return button
            }
        }
        return nil
    }

    private func arcadeButton(in nodes: [SKNode]) -> ArcadeButtonNode? {
        for node in nodes {
            var current: SKNode? = node
            while let candidate = current {
                if let button = candidate as? ArcadeButtonNode, button.isEnabled {
                    return button
                }
                current = candidate.parent
            }
        }
        return nil
    }
}
