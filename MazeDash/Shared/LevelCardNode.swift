import SpriteKit

final class LevelCardNode: SKNode {
    let level: LevelDefinition
    var onTap: (() -> Void)?
    private(set) var isLocked: Bool = false

    private var progress: LevelProgress
    private var sizeValue: CGSize
    private var starSize: CGFloat = LevelSelectStyle.Metric.cardStarSizeMin

    private let backgroundNode: SKSpriteNode
    private let shadowNode = SKSpriteNode(color: SKColor(white: 0.0, alpha: 0.24), size: .zero)
    private let overlayNode = SKSpriteNode(color: SKColor(white: 0.0, alpha: 0.22), size: .zero)
    private let titlePlateNode = SKSpriteNode(color: SKColor(white: 1.0, alpha: 0.08), size: .zero)
    private let starBandNode = SKSpriteNode(color: .clear, size: .zero)
    private let timePlateNode = SKSpriteNode(color: SKColor(white: 0.0, alpha: 0.56), size: .zero)
    private let accentBarNode = SKSpriteNode(color: ArcadeStyle.Color.accentCyan.withAlphaComponent(0.85), size: .zero)
    private let outlineNode = SKShapeNode()
    private let titleLabel = SKLabelNode(fontNamed: LevelSelectStyle.FontName.cardTitle)
    private let timeLabel = SKLabelNode(fontNamed: LevelSelectStyle.FontName.cardTime)
    private let lockLabel = SKLabelNode(fontNamed: LevelSelectStyle.FontName.lock)
    private var starGlowNodes: [SKSpriteNode] = []
    private var starNodes: [SKSpriteNode] = []

    init(level: LevelDefinition, progress: LevelProgress, size: CGSize) {
        self.level = level
        self.progress = progress
        self.sizeValue = size
        self.backgroundNode = SKSpriteNode(texture: TextureFactory.shared.cardTexture(size: size, style: .hud))
        super.init()

        shadowNode.zPosition = -1
        addChild(shadowNode)

        backgroundNode.zPosition = 0
        addChild(backgroundNode)

        overlayNode.zPosition = 1
        addChild(overlayNode)

        titlePlateNode.zPosition = 1.5
        addChild(titlePlateNode)

        starBandNode.zPosition = 1.55
        addChild(starBandNode)

        timePlateNode.zPosition = 1.5
        addChild(timePlateNode)

        accentBarNode.zPosition = 1.7
        addChild(accentBarNode)

        outlineNode.zPosition = 4
        outlineNode.fillColor = .clear
        outlineNode.strokeColor = LevelSelectStyle.Color.cardOutline
        outlineNode.lineWidth = 1.4
        outlineNode.glowWidth = 2
        addChild(outlineNode)

        titleLabel.text = level.name.uppercased()
        titleLabel.fontColor = LevelSelectStyle.Color.textPrimary
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.zPosition = 6
        addChild(titleLabel)

        timeLabel.fontColor = LevelSelectStyle.Color.textPrimary
        timeLabel.verticalAlignmentMode = .center
        timeLabel.horizontalAlignmentMode = .center
        timeLabel.zPosition = 6
        addChild(timeLabel)

        lockLabel.text = "LOCKED"
        lockLabel.fontColor = LevelSelectStyle.Color.textDisabled
        lockLabel.verticalAlignmentMode = .center
        lockLabel.horizontalAlignmentMode = .center
        lockLabel.zPosition = 6
        lockLabel.isHidden = true
        addChild(lockLabel)

        buildStars()
        applySize(size)
        update(progress: progress)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    var size: CGSize {
        sizeValue
    }

    func setTheme(_ theme: MazeTheme) {
        backgroundNode.color = theme.palette.cardTop
        backgroundNode.colorBlendFactor = 0.08
        outlineNode.strokeColor = theme.palette.cardBorder
        accentBarNode.color = theme.palette.accentCyan
    }

    func update(progress: LevelProgress) {
        self.progress = progress
        if let best = progress.bestTime {
            timeLabel.text = "BEST  \(formattedClockTime(best))"
        } else {
            timeLabel.text = "BEST  --:--.--"
        }

        let renderedStarSize = CGSize(width: starSize, height: starSize)
        let outlineTexture = TextureFactory.shared.starOutlineTexture(size: renderedStarSize)
        let filledTexture = TextureFactory.shared.starFilledTexture(size: renderedStarSize)

        for (index, star) in starNodes.enumerated() {
            let earned = index < progress.stars
            star.texture = earned ? filledTexture : outlineTexture
            star.alpha = earned ? 1.0 : 0.9
        }

        for (index, glow) in starGlowNodes.enumerated() {
            let earned = index < progress.stars
            glow.alpha = earned ? 0.38 : 0.0
            glow.setScale(earned ? 1.0 : 0.72)
        }
    }

    func setLocked(_ locked: Bool) {
        isLocked = locked
        lockLabel.isHidden = !locked
        alpha = locked ? 0.58 : 1.0
        outlineNode.alpha = locked ? 0.42 : 0.92
        titlePlateNode.alpha = locked ? 0.42 : 0.98
        timePlateNode.alpha = locked ? 0.34 : 1.0
        shadowNode.alpha = locked ? 0.14 : 0.28
        titleLabel.fontColor = locked ? LevelSelectStyle.Color.textDisabled : LevelSelectStyle.Color.textPrimary
        timeLabel.fontColor = locked ? LevelSelectStyle.Color.textDisabled : LevelSelectStyle.Color.textPrimary
        for star in starNodes {
            star.alpha = locked ? 0.5 : 1.0
        }
        for glow in starGlowNodes {
            glow.alpha = locked ? 0.0 : glow.alpha
        }
    }

    func setPressed(_ pressed: Bool) {
        guard !isLocked else { return }
        removeAction(forKey: "press")
        let targetScale: CGFloat = pressed ? 0.982 : 1.0
        let action = SKAction.scale(to: targetScale, duration: 0.08)
        action.timingMode = .easeOut
        run(action, withKey: "press")
    }

    func playSelectionPulse() {
        guard !isLocked else { return }
        removeAction(forKey: "selectionPulse")
        run(.sequence([
            .scale(to: 0.972, duration: 0.05),
            .scale(to: 1.0, duration: 0.12)
        ]), withKey: "selectionPulse")

        outlineNode.removeAction(forKey: "outlinePulse")
        outlineNode.run(.sequence([
            .fadeAlpha(to: 1.0, duration: 0.05),
            .fadeAlpha(to: 0.92, duration: 0.12)
        ]), withKey: "outlinePulse")

        accentBarNode.removeAction(forKey: "accentPulse")
        accentBarNode.run(.sequence([
            .scaleX(to: 1.1, duration: 0.06),
            .scaleX(to: 1.0, duration: 0.12)
        ]), withKey: "accentPulse")
    }

    func applySize(_ size: CGSize) {
        sizeValue = size
        backgroundNode.texture = TextureFactory.shared.cardTexture(size: size, style: .hud)
        backgroundNode.size = size
        shadowNode.size = CGSize(width: size.width * 0.95, height: size.height * 0.93)
        shadowNode.position = CGPoint(x: 0, y: -max(4, size.height * 0.065))

        let titleSize = clamp(LevelSelectStyle.FontSize.cardTitleMin, LevelSelectStyle.FontSize.cardTitleMax + 1, size.height * 0.25)
        let timeSize = clamp(LevelSelectStyle.FontSize.cardTimeMin, LevelSelectStyle.FontSize.cardTimeMax, size.height * 0.18)
        titleLabel.fontSize = titleSize
        timeLabel.fontSize = timeSize
        lockLabel.fontSize = LevelSelectStyle.FontSize.lock

        starSize = clamp(LevelSelectStyle.Metric.cardStarSizeMin, LevelSelectStyle.Metric.cardStarSizeMax, size.height * 0.29)
        let starSpacing = starSize + max(10, size.width * 0.034)

        overlayNode.size = CGSize(width: size.width * 0.92, height: size.height * 0.86)
        overlayNode.position = CGPoint(x: 0, y: -size.height * 0.01)

        titlePlateNode.size = CGSize(width: size.width * 0.8, height: max(22, size.height * 0.18))
        titlePlateNode.position = snap(CGPoint(x: 0, y: size.height * 0.31))

        starBandNode.size = .zero
        starBandNode.position = snap(CGPoint(x: 0, y: size.height * 0.005))
        starBandNode.alpha = 0.0

        timePlateNode.size = CGSize(width: size.width * 0.82, height: max(24, size.height * 0.2))
        timePlateNode.position = snap(CGPoint(x: 0, y: -size.height * 0.31))

        accentBarNode.size = CGSize(width: size.width * 0.44, height: 3)
        accentBarNode.position = snap(CGPoint(x: 0, y: size.height * 0.13))
        accentBarNode.alpha = 0.92

        outlineNode.path = CGPath(
            roundedRect: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height),
            cornerWidth: LevelSelectStyle.Metric.cardCornerRadius,
            cornerHeight: LevelSelectStyle.Metric.cardCornerRadius,
            transform: nil
        )
        outlineNode.alpha = isLocked ? 0.42 : 0.92

        titleLabel.position = snap(CGPoint(x: 0, y: size.height * 0.31))
        timeLabel.position = snap(CGPoint(x: 0, y: -size.height * 0.31))
        lockLabel.position = snap(CGPoint(x: 0, y: -size.height * 0.02))

        let starRowY = snap(CGPoint(x: 0, y: size.height * 0.01)).y

        for (index, glow) in starGlowNodes.enumerated() {
            let glowSize = starSize + 10
            glow.texture = TextureFactory.shared.starGlowTexture(size: CGSize(width: glowSize, height: glowSize))
            glow.size = CGSize(width: glowSize, height: glowSize)
            glow.position = snap(CGPoint(x: -starSpacing + CGFloat(index) * starSpacing, y: starRowY))
        }

        for (index, star) in starNodes.enumerated() {
            star.size = CGSize(width: starSize, height: starSize)
            star.position = snap(CGPoint(x: -starSpacing + CGFloat(index) * starSpacing, y: starRowY))
        }

        update(progress: progress)
    }

    override func contains(_ p: CGPoint) -> Bool {
        guard !isLocked else { return false }
        let halfWidth = sizeValue.width / 2
        let halfHeight = sizeValue.height / 2
        return p.x >= -halfWidth && p.x <= halfWidth && p.y >= -halfHeight && p.y <= halfHeight
    }

    private func buildStars() {
        starGlowNodes.removeAll()
        starNodes.removeAll()

        let outlineTexture = TextureFactory.shared.starOutlineTexture(size: CGSize(width: starSize, height: starSize))
        for _ in 0..<3 {
            let glowSize = CGSize(width: starSize + 10, height: starSize + 10)
            let glow = SKSpriteNode(texture: TextureFactory.shared.starGlowTexture(size: glowSize))
            glow.alpha = 0
            glow.blendMode = .add
            glow.zPosition = 2.75
            addChild(glow)
            starGlowNodes.append(glow)

            let star = SKSpriteNode(texture: outlineTexture)
            star.zPosition = 3.1
            addChild(star)
            starNodes.append(star)
        }
    }

    private func formattedClockTime(_ time: TimeInterval) -> String {
        let clamped = max(0, time)
        let minutes = Int(clamped / 60)
        let seconds = clamped - Double(minutes * 60)
        return String(format: "%02d:%05.2f", minutes, seconds)
    }

    private func clamp(_ minValue: CGFloat, _ maxValue: CGFloat, _ value: CGFloat) -> CGFloat {
        min(maxValue, max(minValue, value))
    }

    private func snap(_ point: CGPoint) -> CGPoint {
        CGPoint(x: round(point.x), y: round(point.y))
    }
}
