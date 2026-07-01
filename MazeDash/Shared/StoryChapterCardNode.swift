import SpriteKit

struct StoryChapterProgressModel {
    let completedCount: Int
    let levelCount: Int
    let starCount: Int
    let isLocked: Bool
    let isFocusTarget: Bool
    let isNewlyUnlocked: Bool
}

final class StoryChapterCardNode: SKNode {
    let chapter: StoryChapterDefinition

    private(set) var isLocked = false
    private var isFocusTarget = false
    private var isNewlyUnlocked = false
    private var sizeValue: CGSize
    private var currentStyle: CardStyle = .shellPanel

    private let backgroundNode: SKSpriteNode
    private let shadowNode = SKSpriteNode(color: SKColor(white: 0.0, alpha: 0.2), size: .zero)
    private let glowNode = SKShapeNode()
    private let innerFrameNode = SKShapeNode()
    private let outlineNode = SKShapeNode()
    private let overlayNode = SKSpriteNode(color: SKColor(white: 0.0, alpha: 0.12), size: .zero)
    private let accentBarNode = SKSpriteNode(color: ArcadeStyle.Color.accentCyan, size: .zero)
    private let titleLabel = SKLabelNode(fontNamed: ArcadeFont.header)
    private let tagLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let summaryLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let progressLabel = SKLabelNode(fontNamed: ArcadeFont.digits)
    private let starsLabel = SKLabelNode(fontNamed: ArcadeFont.digits)
    private let lockLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let badgeNode = SKSpriteNode(color: ArcadeStyle.Color.accentMagenta.withAlphaComponent(0.18), size: .zero)
    private let badgeLabel = SKLabelNode(fontNamed: ArcadeFont.body)

    init(chapter: StoryChapterDefinition, size: CGSize) {
        self.chapter = chapter
        self.sizeValue = size
        self.backgroundNode = SKSpriteNode(texture: TextureFactory.shared.cardTexture(size: size, style: .shellPanel))
        super.init()

        shadowNode.zPosition = -1
        addChild(shadowNode)

        glowNode.zPosition = -0.5
        glowNode.fillColor = .clear
        glowNode.lineWidth = 1.8
        glowNode.glowWidth = 8
        glowNode.alpha = 0.0
        addChild(glowNode)

        backgroundNode.zPosition = 0
        addChild(backgroundNode)

        overlayNode.zPosition = 0.8
        addChild(overlayNode)

        innerFrameNode.zPosition = 1.1
        innerFrameNode.fillColor = .clear
        innerFrameNode.lineWidth = 1
        addChild(innerFrameNode)

        accentBarNode.zPosition = 1.3
        addChild(accentBarNode)

        outlineNode.zPosition = 2
        outlineNode.fillColor = .clear
        outlineNode.lineWidth = 1.2
        addChild(outlineNode)

        tagLabel.fontSize = 10
        tagLabel.fontColor = LevelSelectStyle.Color.textMuted
        tagLabel.horizontalAlignmentMode = .left
        tagLabel.verticalAlignmentMode = .center
        tagLabel.zPosition = 3
        tagLabel.text = chapter.tag
        addChild(tagLabel)

        titleLabel.fontSize = 18
        titleLabel.fontColor = LevelSelectStyle.Color.textPrimary
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.verticalAlignmentMode = .center
        titleLabel.zPosition = 3
        titleLabel.text = chapter.title
        addChild(titleLabel)

        summaryLabel.fontSize = 10
        summaryLabel.fontColor = LevelSelectStyle.Color.textSecondary.withAlphaComponent(0.9)
        summaryLabel.horizontalAlignmentMode = .left
        summaryLabel.verticalAlignmentMode = .center
        summaryLabel.zPosition = 3
        summaryLabel.text = chapter.shortCode
        addChild(summaryLabel)

        progressLabel.fontSize = 12
        progressLabel.fontColor = LevelSelectStyle.Color.textPrimary
        progressLabel.horizontalAlignmentMode = .left
        progressLabel.verticalAlignmentMode = .center
        progressLabel.zPosition = 3
        addChild(progressLabel)

        starsLabel.fontSize = 12
        starsLabel.fontColor = LevelSelectStyle.Color.textSecondary
        starsLabel.horizontalAlignmentMode = .right
        starsLabel.verticalAlignmentMode = .center
        starsLabel.zPosition = 3
        addChild(starsLabel)

        lockLabel.fontSize = 11
        lockLabel.fontColor = LevelSelectStyle.Color.textDisabled
        lockLabel.horizontalAlignmentMode = .center
        lockLabel.verticalAlignmentMode = .center
        lockLabel.zPosition = 3
        lockLabel.text = "LOCKED"
        lockLabel.isHidden = true
        addChild(lockLabel)

        badgeNode.anchorPoint = CGPoint(x: 1, y: 0.5)
        badgeNode.zPosition = 3
        badgeNode.isHidden = true
        addChild(badgeNode)

        badgeLabel.text = "NEW CHAPTER"
        badgeLabel.fontColor = ArcadeStyle.Color.accentMagenta
        badgeLabel.fontSize = 9
        badgeLabel.horizontalAlignmentMode = .center
        badgeLabel.verticalAlignmentMode = .center
        badgeLabel.zPosition = 4
        badgeLabel.isHidden = true
        addChild(badgeLabel)

        applySize(size)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func applySize(_ size: CGSize) {
        sizeValue = size
        backgroundNode.texture = TextureFactory.shared.cardTexture(size: size, style: currentStyle)
        backgroundNode.size = size
        shadowNode.size = CGSize(width: size.width * 0.92, height: size.height * 0.78)
        shadowNode.position = CGPoint(x: 0, y: -max(4, size.height * 0.06))
        overlayNode.size = CGSize(width: size.width * 0.9, height: size.height * 0.8)

        let cornerRadius = LevelSelectStyle.Metric.cardCornerRadius
        glowNode.path = CGPath(
            roundedRect: CGRect(x: -size.width * 0.51, y: -size.height * 0.51, width: size.width * 1.02, height: size.height * 1.02),
            cornerWidth: cornerRadius + 2,
            cornerHeight: cornerRadius + 2,
            transform: nil
        )
        innerFrameNode.path = CGPath(
            roundedRect: CGRect(x: -size.width * 0.445, y: -size.height * 0.39, width: size.width * 0.89, height: size.height * 0.78),
            cornerWidth: cornerRadius - 2,
            cornerHeight: cornerRadius - 2,
            transform: nil
        )
        outlineNode.path = CGPath(
            roundedRect: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height),
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )

        accentBarNode.size = CGSize(width: size.width * 0.32, height: 4)
        accentBarNode.position = snap(CGPoint(x: 0, y: size.height * 0.34))

        tagLabel.position = snap(CGPoint(x: -size.width * 0.37, y: size.height * 0.18))
        titleLabel.position = snap(CGPoint(x: -size.width * 0.37, y: size.height * 0.05))
        summaryLabel.position = snap(CGPoint(x: -size.width * 0.37, y: -size.height * 0.07))
        progressLabel.position = snap(CGPoint(x: -size.width * 0.37, y: -size.height * 0.28))
        starsLabel.position = snap(CGPoint(x: size.width * 0.37, y: -size.height * 0.28))
        lockLabel.position = snap(.zero)

        badgeNode.size = CGSize(width: 86, height: 18)
        badgeNode.position = snap(CGPoint(x: size.width * 0.37, y: size.height * 0.18))
        badgeLabel.position = snap(CGPoint(x: badgeNode.position.x - badgeNode.size.width / 2, y: badgeNode.position.y + 1))

        let titleSize = min(18, max(14, size.height * 0.15))
        titleLabel.fontSize = titleSize
        if titleLabel.frame.width > size.width * 0.72 {
            let scale = (size.width * 0.72) / max(1, titleLabel.frame.width)
            titleLabel.fontSize = floor(titleSize * scale)
        }
    }

    func update(progress: StoryChapterProgressModel) {
        isLocked = progress.isLocked
        isFocusTarget = progress.isFocusTarget && !progress.isLocked
        isNewlyUnlocked = progress.isNewlyUnlocked && !progress.isLocked

        let theme = ThemeUnlocker.theme(forChapterId: chapter.id)
        let palette = theme.palette
        let isCompleted = progress.completedCount >= progress.levelCount

        currentStyle = isFocusTarget || isNewlyUnlocked ? .shellFeature : .shellPanel
        backgroundNode.texture = TextureFactory.shared.cardTexture(size: sizeValue, style: currentStyle)
        backgroundNode.color = palette.cardTop
        backgroundNode.colorBlendFactor = isFocusTarget ? 0.1 : (isCompleted ? 0.07 : 0.04)

        overlayNode.alpha = isLocked ? 0.22 : (isCompleted ? 0.08 : 0.12)

        let borderColor = isFocusTarget
            ? palette.accentCyan
            : (isCompleted ? palette.cardBorder : LevelSelectStyle.Color.cardOutline.withAlphaComponent(0.72))
        outlineNode.strokeColor = borderColor
        outlineNode.alpha = isLocked ? 0.32 : (isFocusTarget ? 1.0 : (isCompleted ? 0.88 : 0.64))
        outlineNode.glowWidth = isFocusTarget ? 3.5 : (isCompleted ? 2.2 : 1.0)

        glowNode.strokeColor = palette.accentCyan.withAlphaComponent(isFocusTarget ? 0.54 : 0.22)
        glowNode.alpha = isLocked ? 0.0 : (isFocusTarget ? 0.56 : (isCompleted ? 0.18 : 0.08))

        innerFrameNode.strokeColor = palette.cardBorder.withAlphaComponent(isCompleted ? 0.24 : 0.12)
        innerFrameNode.alpha = isLocked ? 0.1 : (isCompleted ? 0.7 : 0.45)

        accentBarNode.color = isFocusTarget ? palette.accentPink : palette.accentCyan
        accentBarNode.alpha = isLocked ? 0.0 : (isFocusTarget ? 0.92 : (isCompleted ? 0.64 : 0.4))

        tagLabel.fontColor = isLocked ? LevelSelectStyle.Color.textDisabled : LevelSelectStyle.Color.textMuted
        titleLabel.fontColor = isLocked ? LevelSelectStyle.Color.textDisabled : LevelSelectStyle.Color.textPrimary
        summaryLabel.fontColor = isLocked
            ? LevelSelectStyle.Color.textDisabled
            : palette.accentCyan.withAlphaComponent(0.92)
        progressLabel.fontColor = isLocked ? LevelSelectStyle.Color.textDisabled : LevelSelectStyle.Color.textPrimary
        starsLabel.fontColor = isLocked ? LevelSelectStyle.Color.textDisabled : LevelSelectStyle.Color.textSecondary

        progressLabel.text = "\(progress.completedCount)/\(progress.levelCount) CLEAR"
        starsLabel.text = "\(progress.starCount) STARS"

        lockLabel.isHidden = !isLocked
        alpha = isLocked ? 0.56 : 1.0

        let showBadge = isNewlyUnlocked
        badgeNode.isHidden = !showBadge
        badgeLabel.isHidden = !showBadge
        badgeNode.alpha = showBadge ? 1.0 : 0.0
        badgeLabel.alpha = showBadge ? 1.0 : 0.0
    }

    func setPressed(_ pressed: Bool) {
        guard !isLocked else { return }
        removeAction(forKey: "press")
        let action = SKAction.scale(to: pressed ? 0.975 : 1.0, duration: 0.08)
        action.timingMode = .easeOut
        run(action, withKey: "press")
    }

    func playSelectionPulse() {
        guard !isLocked else { return }
        removeAction(forKey: "selectionPulse")
        let down = SKAction.scale(to: 0.968, duration: 0.05)
        down.timingMode = .easeOut
        let up = SKAction.scale(to: 1.018, duration: 0.08)
        up.timingMode = .easeInEaseOut
        let settle = SKAction.scale(to: 1.0, duration: 0.12)
        settle.timingMode = .easeInEaseOut
        run(.sequence([down, up, settle]), withKey: "selectionPulse")

        glowNode.removeAction(forKey: "glowPulse")
        glowNode.run(.sequence([
            .fadeAlpha(to: max(glowNode.alpha, 0.72), duration: 0.06),
            .fadeAlpha(to: isFocusTarget ? 0.56 : 0.18, duration: 0.16)
        ]), withKey: "glowPulse")
    }

    override func contains(_ p: CGPoint) -> Bool {
        guard !isLocked else { return false }
        let slop: CGFloat = 16
        let halfWidth = sizeValue.width / 2 + slop
        let halfHeight = sizeValue.height / 2 + slop
        return p.x >= -halfWidth && p.x <= halfWidth && p.y >= -halfHeight && p.y <= halfHeight
    }

    private func snap(_ point: CGPoint) -> CGPoint {
        CGPoint(x: round(point.x), y: round(point.y))
    }
}
