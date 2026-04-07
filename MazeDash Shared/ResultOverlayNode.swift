 import SpriteKit

private final class ResultRequirementRowNode: SKNode {
    private let backgroundNode = SKSpriteNode(color: ArcadeStyle.Color.accentCyan.withAlphaComponent(0.12), size: .zero)
    private let timeLabel = SKLabelNode(fontNamed: ArcadeFont.digits)
    private var starNodes: [SKSpriteNode] = []
    private let highlighted: Bool

    init(starCount: Int, timeText: String, highlighted: Bool) {
        self.highlighted = highlighted
        super.init()

        backgroundNode.alpha = highlighted ? 1.0 : 0.0
        backgroundNode.zPosition = 0
        addChild(backgroundNode)

        let starSize: CGFloat = 16
        let filledTexture = TextureFactory.shared.starFilledTexture(size: CGSize(width: starSize, height: starSize))
        for index in 0..<max(1, min(3, starCount)) {
            let star = SKSpriteNode(texture: filledTexture)
            star.size = CGSize(width: starSize, height: starSize)
            star.color = highlighted ? ArcadeStyle.Color.textPrimary : ArcadeStyle.Color.textSecondary
            star.colorBlendFactor = highlighted ? 0.06 : 0.18
            star.alpha = highlighted ? 1.0 : 0.88
            star.zPosition = 1
            addChild(star)
            starNodes.append(star)
            star.name = "requirement_star_\(index)"
        }

        timeLabel.text = timeText
        timeLabel.fontSize = 15
        timeLabel.fontColor = highlighted ? ArcadeStyle.Color.textPrimary : ArcadeStyle.Color.textSecondary
        timeLabel.horizontalAlignmentMode = .right
        timeLabel.verticalAlignmentMode = .center
        timeLabel.zPosition = 1
        addChild(timeLabel)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func layout(width: CGFloat) {
        let rowWidth = width
        let rowHeight: CGFloat = 24
        backgroundNode.size = CGSize(width: rowWidth, height: rowHeight)
        backgroundNode.position = .zero

        let leftInset: CGFloat = 12
        let starSpacing: CGFloat = 14
        let firstStarCenterX = -rowWidth / 2 + leftInset + 8
        for (index, star) in starNodes.enumerated() {
            star.position = CGPoint(x: firstStarCenterX + CGFloat(index) * starSpacing, y: 0)
        }

        timeLabel.position = CGPoint(x: rowWidth / 2 - 10, y: 0)

        if highlighted {
            backgroundNode.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.14, duration: 0.8),
                .fadeAlpha(to: 0.08, duration: 0.8)
            ])), withKey: "requirement_glow")
        } else {
            backgroundNode.removeAction(forKey: "requirement_glow")
        }
    }
}

final class ResultOverlayNode: SKNode {
    struct RequirementRow {
        let starCount: Int
        let timeText: String
        let highlighted: Bool
    }

    var onRetry: (() -> Void)?
    var onLevelSelect: (() -> Void)?
    var onNext: (() -> Void)?

    private let dimNode = SKSpriteNode(color: ArcadeStyle.Color.overlayDim, size: .zero)
    private let cardNode = SKSpriteNode()
    private let headlineLabel = SKLabelNode(fontNamed: ArcadeFont.title)
    private let timeLabel = SKLabelNode(fontNamed: ArcadeFont.digits)
    private let dividerNode = SKSpriteNode(color: ArcadeStyle.Color.textDisabled.withAlphaComponent(0.24), size: .zero)
    private let nextButton = ArcadeButtonNode(text: "NEXT", size: ArcadeStyle.Metric.buttonSize)
    private let retryButton = ArcadeButtonNode(text: "RETRY", size: ArcadeStyle.Metric.buttonSize)
    private let levelButton = ArcadeButtonNode(text: "MENU", size: ArcadeStyle.Metric.buttonSize)

    private var detailLabels: [SKLabelNode] = []
    private var starNodes: [SKSpriteNode] = []
    private var requirementRowNodes: [ResultRequirementRowNode] = []
    private var currentCardSize = CGSize.zero

    private let headline: String
    private let timeLine: String
    private let detailLines: [String]
    private let requirementRows: [RequirementRow]
    private let stars: Int?

    init(
        size: CGSize,
        safeTop: CGFloat,
        safeBottom: CGFloat,
        headline: String,
        timeLine: String,
        stars: Int?,
        detailLines: [String],
        requirementRows: [RequirementRow] = []
    ) {
        self.headline = headline
        self.timeLine = timeLine
        if let stars {
            self.stars = max(0, min(3, stars))
        } else {
            self.stars = nil
        }
        self.detailLines = detailLines
        self.requirementRows = requirementRows
        super.init()

        dimNode.zPosition = 0
        dimNode.alpha = 0
        addChild(dimNode)

        cardNode.zPosition = 1
        cardNode.alpha = 0
        cardNode.setScale(0.96)
        addChild(cardNode)

        headlineLabel.text = headline
        headlineLabel.fontSize = ArcadeStyle.FontSize.overlayTitle
        headlineLabel.fontColor = ArcadeStyle.Color.textPrimary
        headlineLabel.verticalAlignmentMode = .center
        headlineLabel.horizontalAlignmentMode = .center
        headlineLabel.zPosition = 3
        cardNode.addChild(headlineLabel)

        timeLabel.text = timeLine
        timeLabel.fontSize = 18
        timeLabel.fontColor = ArcadeStyle.Color.textSecondary
        timeLabel.verticalAlignmentMode = .center
        timeLabel.horizontalAlignmentMode = .center
        timeLabel.zPosition = 3
        cardNode.addChild(timeLabel)

        dividerNode.zPosition = 2
        cardNode.addChild(dividerNode)

        buildDetailLabels()
        buildRequirementRows()
        buildStars()

        nextButton.name = "btn_next"
        retryButton.name = "btn_retry"
        levelButton.name = "btn_levelselect"
        nextButton.onTap = { [weak self] in self?.onNext?() }
        retryButton.onTap = { [weak self] in self?.onRetry?() }
        levelButton.onTap = { [weak self] in self?.onLevelSelect?() }

        nextButton.zPosition = 4
        retryButton.zPosition = 4
        levelButton.zPosition = 4
        cardNode.addChild(nextButton)
        cardNode.addChild(retryButton)
        cardNode.addChild(levelButton)

        layout(in: size, safeTop: safeTop, safeBottom: safeBottom)
        runEntranceAnimation()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func setNextEnabled(_ enabled: Bool) {
        nextButton.setEnabled(enabled)
    }

    func layout(in size: CGSize, safeTop: CGFloat, safeBottom: CGFloat) {
        dimNode.size = size
        dimNode.position = snap(.zero)

        let availableHeight = max(300, safeTop - safeBottom - 24)
        let desiredWidth = min(340, size.width - 28)
        let usesRequirementRows = !requirementRowNodes.isEmpty
        let showsStarRow = stars != nil
        let rowCount = usesRequirementRows ? requirementRowNodes.count : detailLabels.count
        let rowHeight: CGFloat = usesRequirementRows ? 24 : 16
        let rowSpacing: CGFloat = usesRequirementRows ? 8 : 10
        let detailBlockHeight = rowCount > 0
            ? CGFloat(rowCount) * rowHeight + CGFloat(max(0, rowCount - 1)) * rowSpacing
            : 0

        let topPadding: CGFloat = 26
        let headlineHeight: CGFloat = 24
        let headlineToStars: CGFloat = showsStarRow ? 16 : 10
        let starsToTime: CGFloat = showsStarRow ? 18 : 0
        let timeHeight: CGFloat = 18
        let buttonHeight: CGFloat = 46
        let buttonsTopSpacing: CGFloat = rowCount > 0 ? 16 : 18
        let bottomPadding: CGFloat = 24
        let detailSectionHeight = rowCount > 0 ? (14 + 1 + 12 + detailBlockHeight) : 0
        let contentHeight =
            topPadding +
            headlineHeight +
            headlineToStars +
            (showsStarRow ? ArcadeStyle.Metric.resultStarSize : 0) +
            starsToTime +
            timeHeight +
            detailSectionHeight +
            buttonsTopSpacing +
            buttonHeight +
            bottomPadding
        let desiredHeight = min(availableHeight, max(308, contentHeight))
        currentCardSize = snapSize(CGSize(width: desiredWidth, height: desiredHeight))
        cardNode.size = currentCardSize
        cardNode.texture = TextureFactory.shared.cardTexture(size: currentCardSize, style: .overlay)

        let desiredY = safeTop - currentCardSize.height * 0.5
        let minY = safeBottom + currentCardSize.height * 0.5 + 16
        cardNode.position = snap(CGPoint(x: 0, y: max(desiredY, minY)))

        var cursorY = currentCardSize.height / 2 - topPadding

        headlineLabel.position = snap(CGPoint(x: 0, y: cursorY - headlineHeight * 0.5))
        cursorY -= headlineHeight + headlineToStars

        if showsStarRow {
            let starSpacing: CGFloat = 48
            let starY = cursorY - ArcadeStyle.Metric.resultStarSize * 0.5
            for (index, star) in starNodes.enumerated() {
                star.position = snap(CGPoint(x: -starSpacing + CGFloat(index) * starSpacing, y: starY))
            }
            cursorY = starY - ArcadeStyle.Metric.resultStarSize * 0.5 - starsToTime
        } else {
            cursorY -= 4
        }

        timeLabel.position = snap(CGPoint(x: 0, y: cursorY - timeHeight * 0.5))
        cursorY -= timeHeight

        if rowCount > 0 {
            cursorY -= 14
            dividerNode.size = snapSize(CGSize(width: currentCardSize.width - 56, height: 1))
            dividerNode.position = snap(CGPoint(x: 0, y: cursorY - 0.5))
            cursorY -= 1 + 12
        } else {
            dividerNode.size = .zero
        }

        if usesRequirementRows {
            let rowWidth = currentCardSize.width - 56
            for (index, rowNode) in requirementRowNodes.enumerated() {
                let rowCenterY = cursorY - rowHeight * 0.5 - CGFloat(index) * (rowHeight + rowSpacing)
                rowNode.layout(width: rowWidth)
                rowNode.position = snap(CGPoint(x: 0, y: rowCenterY))
            }
        } else {
            for (index, label) in detailLabels.enumerated() {
                let labelCenterY = cursorY - rowHeight * 0.5 - CGFloat(index) * (rowHeight + rowSpacing)
                label.position = snap(CGPoint(x: 0, y: labelCenterY))
            }
        }

        let availableWidth = currentCardSize.width - 24
        let buttonSpacing: CGFloat = 10
        let buttonWidth = (availableWidth - buttonSpacing * 2) / 3
        let buttonSize = snapSize(CGSize(width: buttonWidth, height: buttonHeight))
        nextButton.size = buttonSize
        retryButton.size = buttonSize
        levelButton.size = buttonSize

        let buttonsY = -currentCardSize.height / 2 + bottomPadding + buttonHeight * 0.5
        nextButton.position = snap(CGPoint(x: -buttonWidth - buttonSpacing, y: buttonsY))
        retryButton.position = snap(CGPoint(x: 0, y: buttonsY))
        levelButton.position = snap(CGPoint(x: buttonWidth + buttonSpacing, y: buttonsY))

    }

    func button(at point: CGPoint, in node: SKNode) -> ArcadeButtonNode? {
        let localPoint = convert(point, from: node)
        let buttons = [nextButton, retryButton, levelButton]
        for button in buttons {
            guard button.isEnabled else { continue }
            let buttonPoint = button.convert(localPoint, from: self)
            if button.contains(buttonPoint) {
                return button
            }
        }
        return nil
    }

    func handleTap(button: ArcadeButtonNode) {
        if button === nextButton {
            nextButton.onTap?()
        } else if button === retryButton {
            retryButton.onTap?()
        } else if button === levelButton {
            levelButton.onTap?()
        }
    }

    private func buildDetailLabels() {
        detailLabels.forEach { $0.removeFromParent() }
        detailLabels.removeAll()

        guard requirementRows.isEmpty else { return }

        for line in detailLines {
            let label = SKLabelNode(fontNamed: ArcadeFont.body)
            label.text = line
            label.fontSize = 14
            label.fontColor = ArcadeStyle.Color.textSecondary
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.zPosition = 3
            cardNode.addChild(label)
            detailLabels.append(label)
        }
    }

    private func buildRequirementRows() {
        requirementRowNodes.forEach { $0.removeFromParent() }
        requirementRowNodes.removeAll()

        for row in requirementRows {
            let rowNode = ResultRequirementRowNode(
                starCount: row.starCount,
                timeText: row.timeText,
                highlighted: row.highlighted
            )
            rowNode.zPosition = 3
            cardNode.addChild(rowNode)
            requirementRowNodes.append(rowNode)
        }
    }

    private func buildStars() {
        starNodes.forEach { $0.removeFromParent() }
        starNodes.removeAll()

        guard let stars else { return }

        let starSize = ArcadeStyle.Metric.resultStarSize
        let filledTexture = TextureFactory.shared.starFilledTexture(size: CGSize(width: starSize, height: starSize))
        let outlineTexture = TextureFactory.shared.starOutlineTexture(size: CGSize(width: starSize, height: starSize))

        for index in 0..<3 {
            let isEarned = index < stars
            let star = SKSpriteNode(texture: isEarned ? filledTexture : outlineTexture)
            star.size = snapSize(CGSize(width: starSize, height: starSize))
            star.alpha = isEarned ? 0.12 : 0.35
            star.setScale(isEarned ? 0.72 : 1.0)
            star.color = isEarned ? .white : ArcadeStyle.Color.textDisabled
            star.colorBlendFactor = isEarned ? 0 : 0.45
            star.zPosition = 2
            cardNode.addChild(star)
            starNodes.append(star)
        }
    }

    private func runEntranceAnimation() {
        dimNode.run(.fadeAlpha(to: 1.0, duration: 0.16))
        cardNode.run(.group([
            .fadeIn(withDuration: 0.18),
            .scale(to: 1.0, duration: 0.18)
        ]))

        guard let stars else { return }
        for (index, star) in starNodes.enumerated() {
            guard index < stars else { continue }
            let delay = 0.12 + Double(index) * 0.08
            let grow = SKAction.group([
                .fadeAlpha(to: 1.0, duration: 0.12),
                .scale(to: 1.0, duration: 0.12)
            ])
            if stars == 3 && index == 2 {
                let emphasis = SKAction.sequence([
                    .scale(to: 1.08, duration: 0.08),
                    .scale(to: 1.0, duration: 0.10)
                ])
                star.run(.sequence([.wait(forDuration: delay), grow, emphasis]))
            } else {
                star.run(.sequence([.wait(forDuration: delay), grow]))
            }
        }
    }

    private func snap(_ point: CGPoint) -> CGPoint {
        CGPoint(x: round(point.x), y: round(point.y))
    }

    private func snapSize(_ size: CGSize) -> CGSize {
        CGSize(width: round(size.width), height: round(size.height))
    }
}
