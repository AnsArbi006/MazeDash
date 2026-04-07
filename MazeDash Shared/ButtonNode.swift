import SpriteKit

final class ArcadeButtonNode: SKSpriteNode {
    enum State {
        case normal
        case pressed
        case disabled
    }

    let label: SKLabelNode
    var onTap: (() -> Void)?
    private(set) var isEnabled: Bool = true
    private var accentColor: SKColor = ArcadeStyle.Color.accentCyan

    private let shadowNode = SKSpriteNode(color: SKColor(white: 0.0, alpha: 0.24), size: .zero)
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

        overlayNode.size = size
        overlayNode.alpha = 0
        overlayNode.zPosition = 1
        addChild(overlayNode)

        shineNode.zPosition = 1.5
        addChild(shineNode)

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

    func hitTest(_ point: CGPoint, in scene: SKScene) -> Bool {
        guard isEnabled else { return false }
        let localPoint: CGPoint
        if let camera = scene.camera, inParentHierarchy(camera) {
            let cameraPoint = camera.convert(point, from: scene)
            localPoint = convert(cameraPoint, from: camera)
        } else {
            localPoint = convert(point, from: scene)
        }
        let slop: CGFloat = 12
        let expandedBounds = CGRect(
            x: -size.width / 2 - slop,
            y: -size.height / 2 - slop,
            width: size.width + slop * 2,
            height: size.height + slop * 2
        )
        return expandedBounds.contains(localPoint)
    }

    override func contains(_ p: CGPoint) -> Bool {
        guard isEnabled else { return false }
        return super.contains(p)
    }

    private func updateLayoutForSize() {
        guard size.width > 0, size.height > 0 else { return }
        texture = TextureFactory.shared.cardTexture(size: size, style: .button)
        shadowNode.size = CGSize(width: size.width * 0.98, height: size.height * 0.92)
        shadowNode.position = CGPoint(x: 0, y: -max(2, size.height * 0.08))
        shadowNode.alpha = 0.28
        overlayNode.size = size
        shineNode.size = CGSize(width: size.width * 0.78, height: max(6, size.height * 0.16))
        shineNode.position = CGPoint(x: 0, y: size.height * 0.18)
        let cornerRadius = min(ArcadeStyle.Metric.buttonCornerRadius, size.height * 0.5)
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
            shineNode.alpha = 0.52
            shadowNode.alpha = 0.24
        case .pressed:
            overlayNode.alpha = 0.35
            alpha = 1.0
            setScale(0.985)
            label.fontColor = ArcadeStyle.Color.textPrimary
            shineNode.alpha = 0.3
            shadowNode.alpha = 0.16
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
            color = accentColor.withAlphaComponent(0.08)
            colorBlendFactor = 0.14
            borderNode.alpha = 1.0
            borderNode.strokeColor = mixedColor(accentColor, ArcadeStyle.Color.panelBorder, ratio: 0.45)
            borderNode.glowWidth = 1.4
        case .pressed:
            color = accentColor.withAlphaComponent(0.14)
            colorBlendFactor = 0.18
            borderNode.alpha = 1.0
            borderNode.strokeColor = mixedColor(accentColor, SKColor.white, ratio: 0.25)
            borderNode.glowWidth = 1.8
        case .disabled:
            color = .clear
            colorBlendFactor = 0.0
            borderNode.alpha = 0.4
            borderNode.strokeColor = ArcadeStyle.Color.textDisabled
            borderNode.glowWidth = 0.0
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
