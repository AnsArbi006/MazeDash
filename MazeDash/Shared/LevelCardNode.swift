import SpriteKit

final class LevelCardNode: SKNode {
    enum VisualState {
        case current
        case completed
        case ready
        case locked
    }

    let level: LevelDefinition
    var onTap: (() -> Void)?
    private(set) var isLocked: Bool = false

    private var progress: LevelProgress
    private var sizeValue: CGSize
    private var starSize: CGFloat = LevelSelectStyle.Metric.cardStarSizeMin
    private var theme: MazeTheme = .defaultTheme
    private var visualState: VisualState = .ready

    private let backgroundNode: SKSpriteNode
    private let shadowNode = SKSpriteNode(color: SKColor(white: 0.0, alpha: 0.24), size: .zero)
    private let overlayNode = SKSpriteNode(color: SKColor(white: 0.0, alpha: 0.22), size: .zero)
    private let timePlateNode = SKSpriteNode(color: SKColor(white: 0.0, alpha: 0.38), size: .zero)
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

        timePlateNode.zPosition = 1.5
        addChild(timePlateNode)

        outlineNode.zPosition = 4
        outlineNode.fillColor = .clear
        outlineNode.strokeColor = LevelSelectStyle.Color.cardOutline
        outlineNode.lineWidth = 1.4
        outlineNode.glowWidth = 2
        addChild(outlineNode)

        titleLabel.text = level.name.uppercased()
        titleLabel.fontColor = LevelSelectStyle.Color.textPrimary
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .left
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
        lockLabel.horizontalAlignmentMode = .right
        lockLabel.zPosition = 6
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
        self.theme = theme
        backgroundNode.color = theme.palette.cardTop
        backgroundNode.colorBlendFactor = 0.08
        applyVisualState()
    }

    func update(progress: LevelProgress) {
        self.progress = progress
        let hasBestTime = progress.bestTime != nil
        timeLabel.text = progress.bestTime.map { "BEST  \(formattedClockTime($0))" } ?? "BEST  --:--.--"
        timeLabel.alpha = hasBestTime ? 1.0 : 0.66

        let renderedStarSize = CGSize(width: starSize, height: starSize)
        let outlineTexture = TextureFactory.shared.starOutlineTexture(size: renderedStarSize)
        let filledTexture = TextureFactory.shared.starFilledTexture(size: renderedStarSize)

        for (index, star) in starNodes.enumerated() {
            let earned = index < progress.stars
            star.texture = earned ? filledTexture : outlineTexture
        }

        for (index, glow) in starGlowNodes.enumerated() {
            let earned = index < progress.stars
            glow.setScale(earned ? 1.0 : 0.72)
        }

        applyVisualState()
    }

    func setLocked(_ locked: Bool) {
        let isCompleted = progress.bestTime != nil || progress.stars > 0
        setVisualState(isLocked: locked, isCurrent: false, isCompleted: isCompleted)
    }

    func setVisualState(isLocked: Bool, isCurrent: Bool, isCompleted: Bool) {
        self.isLocked = isLocked
        if isLocked {
            visualState = .locked
        } else if isCurrent {
            visualState = .current
        } else if isCompleted {
            visualState = .completed
        } else {
            visualState = .ready
        }
        applyVisualState()
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
    }

    func applySize(_ size: CGSize) {
        sizeValue = size
        backgroundNode.texture = TextureFactory.shared.cardTexture(size: size, style: .hud)
        backgroundNode.size = size
        shadowNode.size = CGSize(width: size.width * 0.95, height: size.height * 0.93)
        shadowNode.position = CGPoint(x: 0, y: -max(4, size.height * 0.065))

        let titleSize = clamp(LevelSelectStyle.FontSize.cardTitleMin, LevelSelectStyle.FontSize.cardTitleMax, size.height * 0.2)
        let timeSize = clamp(LevelSelectStyle.FontSize.cardTimeMin, LevelSelectStyle.FontSize.cardTimeMax, size.height * 0.18)
        titleLabel.fontSize = titleSize
        timeLabel.fontSize = timeSize
        lockLabel.fontSize = 9

        starSize = clamp(LevelSelectStyle.Metric.cardStarSizeMin, LevelSelectStyle.Metric.cardStarSizeMax, size.height * 0.29)
        let starSpacing = starSize + 12

        overlayNode.size = CGSize(width: size.width * 0.92, height: size.height * 0.86)
        overlayNode.position = CGPoint(x: 0, y: -size.height * 0.01)

        timePlateNode.size = CGSize(width: size.width * 0.82, height: max(24, size.height * 0.2))
        timePlateNode.position = snap(CGPoint(x: 0, y: -size.height * 0.3))

        outlineNode.path = CGPath(
            roundedRect: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height),
            cornerWidth: LevelSelectStyle.Metric.cardCornerRadius,
            cornerHeight: LevelSelectStyle.Metric.cardCornerRadius,
            transform: nil
        )
        outlineNode.alpha = isLocked ? 0.42 : 0.92

        let headerY = round(size.height * 0.3)
        let innerPadding = LevelSelectStyle.Metric.cardInnerPadding
        let statusReservedWidth: CGFloat = 44
        titleLabel.position = snap(CGPoint(x: -size.width / 2 + innerPadding, y: headerY))
        lockLabel.position = snap(CGPoint(x: size.width / 2 - innerPadding, y: headerY))
        let maxTitleWidth = size.width - innerPadding * 2 - statusReservedWidth - 8
        if titleLabel.frame.width > maxTitleWidth {
            let scale = maxTitleWidth / max(1, titleLabel.frame.width)
            titleLabel.fontSize = floor(titleSize * scale)
        }

        timeLabel.position = snap(CGPoint(x: 0, y: -size.height * 0.3))

        let starRowY = round(size.height * 0.02)

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

    private func applyVisualState() {
        let hasBestTime = progress.bestTime != nil
        let isLockedState = visualState == .locked

        // locked cards show only title + LOCKED
        starNodes.forEach { $0.isHidden = isLockedState }
        starGlowNodes.forEach { $0.isHidden = isLockedState }
        timePlateNode.isHidden = isLockedState
        timeLabel.isHidden = isLockedState

        let titleColor: SKColor
        let timeColor: SKColor
        let statusColor: SKColor
        let outlineColor: SKColor
        let alphaValue: CGFloat

        switch visualState {
        case .current:
            lockLabel.text = "NEXT"
            titleColor = LevelSelectStyle.Color.textPrimary
            timeColor = hasBestTime ? LevelSelectStyle.Color.textPrimary : LevelSelectStyle.Color.textSecondary
            statusColor = ArcadeStyle.Color.accentYellow
            outlineColor = ArcadeStyle.Color.accentYellow.withAlphaComponent(0.94)
            alphaValue = 1.0
            outlineNode.lineWidth = 2.0
            timePlateNode.alpha = hasBestTime ? 0.9 : 0.55
            shadowNode.alpha = 0.3
        case .completed:
            lockLabel.text = "CLEARED"
            titleColor = LevelSelectStyle.Color.textPrimary.withAlphaComponent(0.96)
            timeColor = hasBestTime ? LevelSelectStyle.Color.textPrimary : LevelSelectStyle.Color.textSecondary
            statusColor = ArcadeStyle.Color.accentCyan.withAlphaComponent(0.78)
            outlineColor = theme.palette.cardBorder.withAlphaComponent(0.82)
            alphaValue = 0.96
            outlineNode.lineWidth = 1.4
            timePlateNode.alpha = hasBestTime ? 0.9 : 0.5
            shadowNode.alpha = 0.24
        case .ready:
            lockLabel.text = "READY"
            titleColor = LevelSelectStyle.Color.textPrimary.withAlphaComponent(0.92)
            timeColor = hasBestTime ? LevelSelectStyle.Color.textPrimary : LevelSelectStyle.Color.textDisabled
            statusColor = ArcadeStyle.Color.textMuted
            outlineColor = theme.palette.cardBorder.withAlphaComponent(0.62)
            alphaValue = 0.92
            outlineNode.lineWidth = 1.3
            timePlateNode.alpha = hasBestTime ? 0.8 : 0.34
            shadowNode.alpha = 0.18
        case .locked:
            lockLabel.text = "LOCKED"
            titleColor = LevelSelectStyle.Color.textDisabled
            timeColor = LevelSelectStyle.Color.textDisabled
            statusColor = LevelSelectStyle.Color.textDisabled.withAlphaComponent(0.82)
            outlineColor = theme.palette.cardBorder.withAlphaComponent(0.34)
            alphaValue = 0.58
            outlineNode.lineWidth = 1.2
            shadowNode.alpha = 0.14
        }

        alpha = alphaValue
        outlineNode.alpha = isLockedState ? 0.42 : 0.94
        outlineNode.strokeColor = outlineColor
        titleLabel.fontColor = titleColor
        timeLabel.fontColor = timeColor
        lockLabel.fontColor = statusColor
        lockLabel.alpha = 1.0

        outlineNode.removeAction(forKey: "statePulse")
        if visualState == .current {
            let brighten = SKAction.fadeAlpha(to: 1.0, duration: 1.2)
            brighten.timingMode = .easeInEaseOut
            let dim = SKAction.fadeAlpha(to: 0.84, duration: 1.2)
            dim.timingMode = .easeInEaseOut
            outlineNode.run(.repeatForever(.sequence([brighten, dim])), withKey: "statePulse")
        }

        guard !isLockedState else { return }

        for (index, star) in starNodes.enumerated() {
            let earned = index < progress.stars
            switch visualState {
            case .ready:
                star.alpha = earned ? 0.92 : 0.42
            case .completed:
                star.alpha = earned ? 1.0 : 0.5
            case .current, .locked:
                star.alpha = earned ? 1.0 : 0.56
            }
        }

        for (index, glow) in starGlowNodes.enumerated() {
            let earned = index < progress.stars
            glow.alpha = (visualState == .current && earned) ? 0.14 : 0.0
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
