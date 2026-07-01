 import SpriteKit

private final class ResultRequirementRowNode: SKNode {
    enum Role {
        case base
        case achieved
        case next
    }

    let starCount: Int

    private let backgroundNode = SKSpriteNode(color: ArcadeStyle.Color.textPrimary.withAlphaComponent(0.035), size: .zero)
    private let glowNode = SKSpriteNode(color: ArcadeStyle.Color.accentCyan.withAlphaComponent(0.08), size: .zero)
    private let accentLineNode = SKSpriteNode(color: ArcadeStyle.Color.accentCyan.withAlphaComponent(0.82), size: .zero)
    private let laneLineNode = SKSpriteNode(color: SKColor(white: 1.0, alpha: 0.06), size: .zero)
    private let timeLabel = SKLabelNode(fontNamed: ArcadeFont.digits)
    private var starNodes: [SKSpriteNode] = []
    private let role: Role
    var moduleRole: Role { role }

    init(starCount: Int, timeText: String, role: Role) {
        self.starCount = starCount
        self.role = role
        super.init()

        backgroundNode.zPosition = 0
        addChild(backgroundNode)

        glowNode.zPosition = 0.2
        glowNode.alpha = 0
        glowNode.blendMode = .add
        addChild(glowNode)

        accentLineNode.zPosition = 0.5
        addChild(accentLineNode)

        laneLineNode.zPosition = 0.45
        addChild(laneLineNode)

        let starSize: CGFloat = 18
        let filledTexture = TextureFactory.shared.starFilledTexture(size: CGSize(width: starSize, height: starSize))
        for index in 0..<max(1, min(3, starCount)) {
            let star = SKSpriteNode(texture: filledTexture)
            star.size = CGSize(width: starSize, height: starSize)
            star.zPosition = 1
            addChild(star)
            starNodes.append(star)
            star.name = "requirement_star_\(index)"
        }

        timeLabel.text = timeText
        timeLabel.fontSize = 16
        timeLabel.fontColor = role == .achieved
            ? ArcadeStyle.Color.textPrimary
            : role == .next
                ? ArcadeStyle.Color.accentYellow
                : ArcadeStyle.Color.textSecondary.withAlphaComponent(0.96)
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
        let rowHeight: CGFloat = role == .achieved ? 28 : 24
        backgroundNode.size = CGSize(width: rowWidth, height: rowHeight)
        backgroundNode.position = .zero
        glowNode.size = CGSize(width: rowWidth - 8, height: rowHeight - 8)
        glowNode.position = .zero
        backgroundNode.color = role == .achieved
            ? ArcadeStyle.Color.accentCyan.withAlphaComponent(0.08)
            : role == .next
                ? ArcadeStyle.Color.accentYellow.withAlphaComponent(0.03)
                : ArcadeStyle.Color.textPrimary.withAlphaComponent(0.012)
        backgroundNode.alpha = role == .achieved ? 1.0 : role == .next ? 0.82 : 0.52

        accentLineNode.size = CGSize(width: 4, height: rowHeight - 8)
        accentLineNode.position = CGPoint(x: -rowWidth / 2 + 10, y: 0)
        accentLineNode.alpha = role == .achieved ? 0.92 : 0.0

        laneLineNode.size = CGSize(width: rowWidth - 12, height: 1)
        laneLineNode.position = CGPoint(x: 0, y: -rowHeight * 0.5 + 1)
        laneLineNode.alpha = role == .achieved ? 0.0 : role == .next ? 0.08 : 0.05

        let starSpacing: CGFloat = 15
        let leftAnchorX = -rowWidth / 2 + 26
        let firstStarCenterX = leftAnchorX + CGFloat(max(1, starCount) - 1) * starSpacing * 0.5
        for (index, star) in starNodes.enumerated() {
            star.color = role == .achieved ? ArcadeStyle.Color.accentYellow : ArcadeStyle.Color.textSecondary
            star.colorBlendFactor = role == .achieved ? 0.1 : 0.22
            star.alpha = role == .achieved ? 1.0 : role == .next ? 0.86 : 0.68
            star.position = CGPoint(x: firstStarCenterX - CGFloat(index) * starSpacing, y: 0)
        }

        timeLabel.fontColor = role == .achieved
            ? ArcadeStyle.Color.textPrimary
            : role == .next
                ? ArcadeStyle.Color.accentYellow
                : ArcadeStyle.Color.textSecondary.withAlphaComponent(0.96)
        timeLabel.position = CGPoint(x: rowWidth / 2 - 6, y: 0)

        glowNode.alpha = role == .achieved ? 0.18 : (role == .next ? 0.06 : 0.0)
    }

    func animateIn(delay: TimeInterval) {
        alpha = 0
        setScale(0.985)
        let targetPosition = position
        position = CGPoint(x: targetPosition.x + 8, y: targetPosition.y)
        run(.sequence([
            .wait(forDuration: delay),
            .group([
                timed(.fadeAlpha(to: 1.0, duration: 0.18), mode: .easeOut),
                timed(.move(to: targetPosition, duration: 0.18), mode: .easeOut),
                timed(.scale(to: 1.0, duration: 0.18), mode: .easeOut)
            ]),
            .run { [weak self] in
                self?.playRoleReveal()
            }
        ]), withKey: "rowEntrance")
    }

    private func playRoleReveal() {
        switch role {
        case .achieved:
            glowNode.run(.sequence([
                timed(.fadeAlpha(to: 0.46, duration: 0.12), mode: .easeOut),
                timed(.fadeAlpha(to: 0.28, duration: 0.22), mode: .easeInEaseOut)
            ]), withKey: "heroGlow")
            let sweep = SKSpriteNode(color: ArcadeStyle.Color.accentCyan.withAlphaComponent(0.24), size: CGSize(width: backgroundNode.size.width * 0.3, height: backgroundNode.size.height - 6))
            sweep.position = CGPoint(x: -backgroundNode.size.width * 0.38, y: 0)
            sweep.blendMode = .add
            sweep.zPosition = 0.9
            addChild(sweep)
            sweep.run(.sequence([
                .group([
                    timed(.moveTo(x: backgroundNode.size.width * 0.38, duration: 0.32), mode: .easeInEaseOut),
                    timed(.fadeOut(withDuration: 0.32), mode: .easeInEaseOut)
                ]),
                .removeFromParent()
            ]))
        case .next:
            backgroundNode.run(.sequence([
                timed(.fadeAlpha(to: 0.94, duration: 0.1), mode: .easeOut),
                timed(.fadeAlpha(to: 0.82, duration: 0.18), mode: .easeInEaseOut)
            ]), withKey: "nextPulse")
        case .base:
            break
        }
    }

    private func timed(_ action: SKAction, mode: SKActionTimingMode) -> SKAction {
        action.timingMode = mode
        return action
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
    var onLeaderboard: (() -> Void)?

    private let dimNode = SKSpriteNode(color: ArcadeStyle.Color.overlayDim, size: .zero)
    private let cardNode = SKSpriteNode()
    private let headlineLabel = SKLabelNode(fontNamed: ArcadeFont.title)
    private let timeCaptionLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let timeValueShadowLabel = SKLabelNode(fontNamed: ArcadeFont.digits)
    private let timeValueLabel = SKLabelNode(fontNamed: ArcadeFont.digits)
    private let requirementModuleNode = SKSpriteNode(color: SKColor(white: 1.0, alpha: 0.012), size: .zero)
    private let requirementGlowNode = SKSpriteNode(color: ArcadeStyle.Color.accentCyan.withAlphaComponent(0.12), size: .zero)
    private let requirementDividerNode = SKSpriteNode(color: SKColor(white: 1.0, alpha: 0.07), size: .zero)
    private let leaderboardButton = ArcadeButtonNode(text: "LEADERBOARD", size: CGSize(width: 156, height: 34))
    private let nextButton = ArcadeButtonNode(text: "NEXT", size: ArcadeStyle.Metric.buttonSize)
    private let retryButton = ArcadeButtonNode(text: "RETRY", size: ArcadeStyle.Metric.buttonSize)
    private let levelButton = ArcadeButtonNode(text: "MENU", size: ArcadeStyle.Metric.buttonSize)

    private var detailLabels: [SKLabelNode] = []
    private var starGlowNodes: [SKSpriteNode] = []
    private var starNodes: [SKSpriteNode] = []
    private var requirementRowNodes: [ResultRequirementRowNode] = []
    private var currentCardSize = CGSize.zero
    private var cardRestPosition = CGPoint.zero
    private var requirementModuleHeight: CGFloat = 0

    private let headline: String
    private let timeCaption: String
    private let timeValue: String
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
        let parsedTime = ResultOverlayNode.parseTimeLine(timeLine)
        self.timeCaption = parsedTime.caption
        self.timeValue = parsedTime.value
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
        cardNode.setScale(0.92)
        addChild(cardNode)

        headlineLabel.text = headline
        headlineLabel.fontSize = ArcadeStyle.FontSize.overlayTitle
        headlineLabel.fontColor = ArcadeStyle.Color.textPrimary
        headlineLabel.verticalAlignmentMode = .center
        headlineLabel.horizontalAlignmentMode = .center
        headlineLabel.zPosition = 3
        cardNode.addChild(headlineLabel)

        timeCaptionLabel.text = timeCaption
        timeCaptionLabel.fontSize = 11
        timeCaptionLabel.fontColor = ArcadeStyle.Color.textMuted
        timeCaptionLabel.verticalAlignmentMode = .center
        timeCaptionLabel.horizontalAlignmentMode = .center
        timeCaptionLabel.zPosition = 3
        cardNode.addChild(timeCaptionLabel)

        timeValueShadowLabel.text = timeValue
        timeValueShadowLabel.fontSize = 28
        timeValueShadowLabel.fontColor = SKColor(white: 0.0, alpha: 0.74)
        timeValueShadowLabel.verticalAlignmentMode = .center
        timeValueShadowLabel.horizontalAlignmentMode = .center
        timeValueShadowLabel.zPosition = 2.8
        cardNode.addChild(timeValueShadowLabel)

        timeValueLabel.text = timeValue
        timeValueLabel.fontSize = 28
        timeValueLabel.fontColor = ArcadeStyle.Color.textPrimary
        timeValueLabel.verticalAlignmentMode = .center
        timeValueLabel.horizontalAlignmentMode = .center
        timeValueLabel.zPosition = 3
        cardNode.addChild(timeValueLabel)

        requirementModuleNode.zPosition = 2
        cardNode.addChild(requirementModuleNode)

        requirementGlowNode.zPosition = 2.1
        requirementGlowNode.blendMode = .add
        requirementGlowNode.alpha = 0
        cardNode.addChild(requirementGlowNode)

        requirementDividerNode.zPosition = 2.15
        requirementDividerNode.alpha = 0.0
        cardNode.addChild(requirementDividerNode)

        buildDetailLabels()
        buildRequirementRows()
        buildStars()

        leaderboardButton.name = "btn_story_leaderboard"
        leaderboardButton.onTap = { [weak self] in self?.onLeaderboard?() }
        leaderboardButton.setCardStyle(.shellPanel)
        leaderboardButton.setAccentColor(ArcadeStyle.Color.accentGreen)
        leaderboardButton.setEmphasisStyle(.quiet)
        leaderboardButton.label.fontSize = 11
        leaderboardButton.zPosition = 4
        leaderboardButton.alpha = 0
        leaderboardButton.isHidden = true
        cardNode.addChild(leaderboardButton)

        nextButton.name = "btn_next"
        retryButton.name = "btn_retry"
        levelButton.name = "btn_levelselect"
        nextButton.onTap = { [weak self] in self?.onNext?() }
        retryButton.onTap = { [weak self] in self?.onRetry?() }
        levelButton.onTap = { [weak self] in self?.onLevelSelect?() }
        nextButton.setCardStyle(.shellAccent)
        nextButton.setAccentColor(ArcadeStyle.Color.accentYellow)
        nextButton.setEmphasisStyle(.primary)
        retryButton.setCardStyle(.shellPanel)
        retryButton.setAccentColor(ArcadeStyle.Color.accentCyan)
        retryButton.setEmphasisStyle(.quiet)
        levelButton.setCardStyle(.shellPanel)
        levelButton.setAccentColor(ArcadeStyle.Color.accentMagenta)
        levelButton.setEmphasisStyle(.quiet)

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

    func setLeaderboardVisible(_ visible: Bool, title: String = "LEADERBOARD") {
        leaderboardButton.isHidden = !visible
        leaderboardButton.alpha = visible ? 1.0 : 0.0
        leaderboardButton.label.text = title
    }

    func layout(in size: CGSize, safeTop: CGFloat, safeBottom: CGFloat) {
        dimNode.size = size
        dimNode.position = snap(.zero)

        let safeHeight = max(100, safeTop - safeBottom)
        let safeCenterY = (safeTop + safeBottom) * 0.5
        let verticalSafePadding: CGFloat = 14
        let availableHeight = max(300, safeHeight - verticalSafePadding * 2)
        let desiredWidth = min(340, size.width - 28)
        let usesRequirementRows = !requirementRowNodes.isEmpty
        let showsStarRow = stars != nil
        let showsLeaderboardButton = !leaderboardButton.isHidden
        let rowCount = usesRequirementRows ? requirementRowNodes.count : detailLabels.count
        let rowHeight: CGFloat = usesRequirementRows ? 34 : 16
        let rowSpacing: CGFloat = usesRequirementRows ? 10 : 10
        let detailBlockHeight = rowCount > 0
            ? CGFloat(rowCount) * rowHeight + CGFloat(max(0, rowCount - 1)) * rowSpacing
            : 0

        let topPadding: CGFloat = 32
        let headlineHeight: CGFloat = 24
        let headlineToStars: CGFloat = showsStarRow ? 12 : 8
        let starVisualHeight: CGFloat = showsStarRow ? ArcadeStyle.Metric.resultStarSize + 8 : 0
        let starsToTime: CGFloat = showsStarRow ? 14 : 4
        let timeCaptionHeight: CGFloat = 12
        let timeValueHeight: CGFloat = 28
        let timeCaptionSpacing: CGFloat = 4
        let leaderboardButtonHeight: CGFloat = showsLeaderboardButton ? 34 : 0
        let leaderboardSpacing: CGFloat = showsLeaderboardButton ? 14 : (rowCount > 0 ? 18 : 8)
        let buttonHeight: CGFloat = 46
        let buttonsTopSpacing: CGFloat = rowCount > 0 ? 14 : 16
        let bottomPadding: CGFloat = 22
        let detailSectionHeight = rowCount > 0
            ? usesRequirementRows
                ? (10 + detailBlockHeight + 8)
                : (12 + detailBlockHeight)
            : 0
        let contentHeight =
            topPadding +
            headlineHeight +
            headlineToStars +
            starVisualHeight +
            starsToTime +
            timeCaptionHeight +
            timeCaptionSpacing +
            timeValueHeight +
            leaderboardSpacing +
            leaderboardButtonHeight +
            detailSectionHeight +
            buttonsTopSpacing +
            buttonHeight +
            bottomPadding
        let desiredHeight = min(availableHeight, max(318, contentHeight))
        currentCardSize = snapSize(CGSize(width: desiredWidth, height: desiredHeight))
        cardNode.size = currentCardSize
        cardNode.texture = TextureFactory.shared.cardTexture(size: currentCardSize, style: .shellPanel)

        let maxY = safeTop - verticalSafePadding - currentCardSize.height * 0.5
        let minY = safeBottom + verticalSafePadding + currentCardSize.height * 0.5
        let desiredY = safeCenterY
        cardRestPosition = snap(CGPoint(x: 0, y: min(max(desiredY, minY), maxY)))
        cardNode.position = cardRestPosition

        var cursorY = currentCardSize.height / 2 - topPadding

        headlineLabel.position = snap(CGPoint(x: 0, y: cursorY - headlineHeight * 0.5))
        cursorY -= headlineHeight + headlineToStars

        if showsStarRow {
            let starSpacing: CGFloat = 48
            let starY = cursorY - starVisualHeight * 0.5 + 2
            for (index, star) in starNodes.enumerated() {
                star.position = snap(CGPoint(x: -starSpacing + CGFloat(index) * starSpacing, y: starY))
            }
            for (index, glow) in starGlowNodes.enumerated() {
                glow.position = snap(CGPoint(x: -starSpacing + CGFloat(index) * starSpacing, y: starY))
            }
            cursorY = starY - starVisualHeight * 0.5 - starsToTime
        } else {
            cursorY -= 2
        }

        timeCaptionLabel.position = snap(CGPoint(x: 0, y: cursorY - timeCaptionHeight * 0.5))
        cursorY -= timeCaptionHeight + timeCaptionSpacing
        let timeValueCenterY = cursorY - timeValueHeight * 0.5
        timeValueShadowLabel.position = snap(CGPoint(x: 1, y: timeValueCenterY - 1))
        timeValueLabel.position = snap(CGPoint(x: 0, y: timeValueCenterY))
        cursorY -= timeValueHeight

        cursorY -= leaderboardSpacing

        if showsLeaderboardButton {
            leaderboardButton.size = snapSize(CGSize(width: min(168, currentCardSize.width - 74), height: leaderboardButtonHeight))
            leaderboardButton.position = snap(CGPoint(x: 0, y: cursorY - leaderboardButtonHeight * 0.5))
            cursorY -= leaderboardButtonHeight
        }

        if rowCount > 0 {
            cursorY -= usesRequirementRows ? 18 : 12
        }

        if usesRequirementRows {
            let moduleWidth = currentCardSize.width - 40
            let moduleTopInset: CGFloat = 6
            let moduleBottomInset: CGFloat = 8
            let bodyHeight = detailBlockHeight
            requirementModuleHeight = moduleTopInset + bodyHeight + moduleBottomInset
            requirementModuleNode.size = snapSize(CGSize(width: moduleWidth, height: requirementModuleHeight))
            requirementModuleNode.position = snap(CGPoint(x: 0, y: cursorY - requirementModuleHeight * 0.5))
            requirementModuleNode.color = SKColor(white: 1.0, alpha: 0.012)
            requirementGlowNode.size = snapSize(CGSize(width: moduleWidth - 12, height: requirementModuleHeight - 10))
            requirementGlowNode.position = requirementModuleNode.position
            requirementDividerNode.size = snapSize(CGSize(width: moduleWidth, height: 1))
            requirementDividerNode.position = snap(CGPoint(x: 0, y: requirementModuleNode.position.y + requirementModuleHeight * 0.5 - 2))

            let rowBaseWidth = moduleWidth - 22
            let firstRowCenterY = requirementModuleNode.position.y + requirementModuleHeight * 0.5 - moduleTopInset - rowHeight * 0.5
            for (index, rowNode) in requirementRowNodes.enumerated() {
                let rowCenterY = firstRowCenterY - CGFloat(index) * (rowHeight + rowSpacing)
                let rowWidth: CGFloat
                let rowOffsetX: CGFloat
                switch rowNode.moduleRole {
                case .achieved:
                    rowWidth = rowBaseWidth
                    rowOffsetX = 0
                case .next:
                    rowWidth = rowBaseWidth - 4
                    rowOffsetX = 0
                case .base:
                    rowWidth = rowBaseWidth - 8
                    rowOffsetX = 0
                }
                rowNode.layout(width: rowWidth)
                rowNode.position = snap(CGPoint(x: rowOffsetX, y: rowCenterY))
            }
            cursorY = requirementModuleNode.position.y - requirementModuleHeight * 0.5
        } else {
            requirementModuleNode.size = .zero
            requirementGlowNode.size = .zero
            requirementDividerNode.size = .zero
            for (index, label) in detailLabels.enumerated() {
                let labelCenterY = cursorY - rowHeight * 0.5 - CGFloat(index) * (rowHeight + rowSpacing)
                label.position = snap(CGPoint(x: 0, y: labelCenterY))
            }
            cursorY -= detailBlockHeight
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

    func button(at point: CGPoint, in scene: SKScene) -> ArcadeButtonNode? {
        let buttons = [nextButton, retryButton, levelButton]
        if leaderboardButton.isHidden == false, leaderboardButton.hitTest(point, in: scene) {
            return leaderboardButton
        }
        for button in buttons {
            if button.hitTest(point, in: scene) {
                return button
            }
        }
        return nil
    }

    func handleTap(button: ArcadeButtonNode) {
        button.playConfirmMotion()
        if button === leaderboardButton {
            leaderboardButton.onTap?()
        } else if button === nextButton {
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
            label.fontSize = 13
            label.fontColor = ArcadeStyle.Color.textSecondary.withAlphaComponent(0.94)
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

        let achievedIndex = requirementRows.firstIndex(where: { $0.highlighted })
        let nextIndex: Int? = {
            guard let achievedIndex else { return requirementRows.isEmpty ? nil : 0 }
            let candidate = achievedIndex + 1
            return candidate < requirementRows.count ? candidate : nil
        }()

        for (index, row) in requirementRows.enumerated() {
            let role: ResultRequirementRowNode.Role
            if row.highlighted {
                role = .achieved
            } else if index == nextIndex {
                role = .next
            } else {
                role = .base
            }
            let rowNode = ResultRequirementRowNode(
                starCount: row.starCount,
                timeText: row.timeText,
                role: role
            )
            rowNode.zPosition = 3
            cardNode.addChild(rowNode)
            requirementRowNodes.append(rowNode)
        }
    }

    private func buildStars() {
        starGlowNodes.forEach { $0.removeFromParent() }
        starNodes.forEach { $0.removeFromParent() }
        starGlowNodes.removeAll()
        starNodes.removeAll()

        guard let stars else { return }

        let starSize = ArcadeStyle.Metric.resultStarSize + 6
        let filledTexture = TextureFactory.shared.starFilledTexture(size: CGSize(width: starSize, height: starSize))
        let outlineTexture = TextureFactory.shared.starOutlineTexture(size: CGSize(width: starSize, height: starSize))
        let glowTexture = TextureFactory.shared.starGlowTexture(size: CGSize(width: starSize + 20, height: starSize + 20))

        for index in 0..<3 {
            let isEarned = index < stars
            let glow = SKSpriteNode(texture: glowTexture)
            glow.size = snapSize(CGSize(width: starSize + 20, height: starSize + 20))
            glow.alpha = 0
            glow.blendMode = .add
            glow.zPosition = 1.8
            cardNode.addChild(glow)
            starGlowNodes.append(glow)

            let star = SKSpriteNode(texture: isEarned ? filledTexture : outlineTexture)
            star.size = snapSize(CGSize(width: starSize, height: starSize))
            star.alpha = 0
            star.setScale(isEarned ? 0.6 : 0.9)
            star.color = isEarned ? .white : ArcadeStyle.Color.textDisabled
            star.colorBlendFactor = isEarned ? 0 : 0.45
            star.zPosition = 2
            cardNode.addChild(star)
            starNodes.append(star)
        }
    }

    private func runEntranceAnimation() {
        dimNode.removeAllActions()
        cardNode.removeAllActions()
        dimNode.alpha = 0
        cardNode.alpha = 0
        cardNode.setScale(0.92)
        cardNode.position = CGPoint(x: cardRestPosition.x, y: cardRestPosition.y - 12)

        let dimFade = SKAction.fadeAlpha(to: 1.0, duration: 0.17)
        dimFade.timingMode = .easeOut
        dimNode.run(dimFade)

        let move = SKAction.move(to: cardRestPosition, duration: 0.24)
        move.timingMode = .easeOut
        let fade = SKAction.fadeAlpha(to: 1.0, duration: 0.2)
        fade.timingMode = .easeOut
        let scale = SKAction.scale(to: 1.0, duration: 0.24)
        scale.timingMode = .easeOut
        cardNode.run(.group([move, fade, scale]), withKey: "overlayIn")

        animateLabelEntrance(headlineLabel, delay: 0.03, offsetY: 8)
        animateLabelEntrance(timeCaptionLabel, delay: 0.08, offsetY: 4)
        animateLabelEntrance(timeValueShadowLabel, delay: 0.1, offsetY: 4)
        animateLabelEntrance(timeValueLabel, delay: 0.1, offsetY: 4, scaleFrom: 0.94)
        animateButtonEntrance(nextButton, delay: 0.16)
        animateButtonEntrance(retryButton, delay: 0.18)
        animateButtonEntrance(levelButton, delay: 0.20)

        animateRequirementModuleEntrance()
        for (index, label) in detailLabels.enumerated() {
            animateLabelEntrance(label, delay: 0.12 + Double(index) * 0.04, offsetY: 4)
        }
        if !leaderboardButton.isHidden {
            animateButtonEntrance(leaderboardButton, delay: 0.15)
            animateLabelEntrance(leaderboardButton.label, delay: 0.17, offsetY: 0)
        }
        animateLabelEntrance(nextButton.label, delay: 0.18, offsetY: 0)
        animateLabelEntrance(retryButton.label, delay: 0.2, offsetY: 0)
        animateLabelEntrance(levelButton.label, delay: 0.22, offsetY: 0)
        timeValueLabel.run(.sequence([
            .wait(forDuration: 0.16),
            .group([
                timed(.scale(to: 1.06, duration: 0.1), mode: .easeOut),
                timed(.fadeAlpha(to: 1.0, duration: 0.1), mode: .easeOut)
            ]),
            timed(.scale(to: 1.0, duration: 0.16), mode: .easeInEaseOut)
        ]))
        timeValueShadowLabel.run(.sequence([
            .wait(forDuration: 0.16),
            .group([
                timed(.scale(to: 1.04, duration: 0.1), mode: .easeOut),
                timed(.fadeAlpha(to: 0.82, duration: 0.1), mode: .easeOut)
            ]),
            timed(.scale(to: 1.0, duration: 0.16), mode: .easeInEaseOut)
        ]))

        guard let stars else { return }
        for (index, star) in starNodes.enumerated() {
            let delay = 0.10 + Double(index) * 0.10
            if index < stars {
                let pop = SKAction.group([
                    timed(.fadeAlpha(to: 1.0, duration: 0.14), mode: .easeOut),
                    timed(.scale(to: 1.18, duration: 0.14), mode: .easeOut),
                    timed(.rotate(byAngle: CGFloat.pi / 20, duration: 0.14), mode: .easeOut)
                ])
                let settle = SKAction.group([
                    timed(.scale(to: 1.0, duration: 0.12), mode: .easeInEaseOut),
                    timed(.rotate(toAngle: 0, duration: 0.12, shortestUnitArc: true), mode: .easeInEaseOut)
                ])
                let glow = starGlowNodes[index]
                let glowPulse = SKAction.sequence([
                    .group([
                        timed(.fadeAlpha(to: stars == 3 && index == 2 ? 0.56 : 0.42, duration: 0.12), mode: .easeOut),
                        timed(.scale(to: 1.08, duration: 0.12), mode: .easeOut)
                    ]),
                    .group([
                        timed(.fadeAlpha(to: 0.16, duration: 0.22), mode: .easeInEaseOut),
                        timed(.scale(to: 1.0, duration: 0.22), mode: .easeInEaseOut)
                    ])
                ])
                star.run(.sequence([.wait(forDuration: delay), pop, settle]))
                glow.run(.sequence([.wait(forDuration: delay), glowPulse]))
                spawnStarSparkles(around: star, delay: delay + 0.04)
            } else {
                let fadeIn = SKAction.group([
                    timed(.fadeAlpha(to: 0.42, duration: 0.18), mode: .easeOut),
                    timed(.scale(to: 1.0, duration: 0.18), mode: .easeOut)
                ])
                star.run(.sequence([.wait(forDuration: delay), fadeIn]))
            }
        }
    }

    private func animateRequirementModuleEntrance() {
        guard !requirementRowNodes.isEmpty else { return }

        let moduleTarget = requirementModuleNode.position
        requirementModuleNode.alpha = 0
        requirementModuleNode.position = CGPoint(x: moduleTarget.x, y: moduleTarget.y - 6)
        requirementModuleNode.setScale(0.985)
        requirementGlowNode.alpha = 0
        requirementGlowNode.position = requirementModuleNode.position
        requirementDividerNode.alpha = 0

        requirementModuleNode.run(.sequence([
            .wait(forDuration: 0.12),
            .group([
                timed(.fadeAlpha(to: 1.0, duration: 0.2), mode: .easeOut),
                timed(.move(to: moduleTarget, duration: 0.2), mode: .easeOut),
                timed(.scale(to: 1.0, duration: 0.2), mode: .easeOut)
            ])
        ]))
        requirementGlowNode.run(.sequence([
            .wait(forDuration: 0.18),
            timed(.fadeAlpha(to: 0.08, duration: 0.18), mode: .easeOut)
        ]))
        requirementDividerNode.run(.sequence([
            .wait(forDuration: 0.18),
            timed(.fadeAlpha(to: 1.0, duration: 0.16), mode: .easeOut)
        ]))
        for (index, rowNode) in requirementRowNodes.enumerated() {
            rowNode.animateIn(delay: 0.16 + Double(index) * 0.05)
        }
    }

    private func animateLabelEntrance(_ label: SKNode, delay: TimeInterval, offsetY: CGFloat, scaleFrom: CGFloat = 1.0) {
        let targetPosition = label.position
        label.alpha = 0
        label.position = CGPoint(x: targetPosition.x, y: targetPosition.y - offsetY)
        label.setScale(scaleFrom)
        let wait = SKAction.wait(forDuration: delay)
        let fade = timed(.fadeAlpha(to: 1.0, duration: 0.18), mode: .easeOut)
        let move = timed(.move(to: targetPosition, duration: 0.18), mode: .easeOut)
        let scale = timed(.scale(to: 1.0, duration: 0.18), mode: .easeOut)
        label.run(.sequence([wait, .group([fade, move, scale])]))
    }

    private func animateButtonEntrance(_ button: ArcadeButtonNode, delay: TimeInterval) {
        let targetPosition = button.position
        button.alpha = 0
        button.position = CGPoint(x: targetPosition.x, y: targetPosition.y - 8)
        button.setScale(0.96)
        button.run(.sequence([
            .wait(forDuration: delay),
            .group([
                timed(.fadeAlpha(to: 1.0, duration: 0.18), mode: .easeOut),
                timed(.move(to: targetPosition, duration: 0.18), mode: .easeOut),
                timed(.scale(to: 1.0, duration: 0.18), mode: .easeOut)
            ])
        ]))
    }

    private func spawnStarSparkles(around star: SKSpriteNode, delay: TimeInterval) {
        let offsets = [
            CGPoint(x: -14, y: 8),
            CGPoint(x: 0, y: 16),
            CGPoint(x: 15, y: 4)
        ]
        for (index, offset) in offsets.enumerated() {
            let sparkle = SKShapeNode(circleOfRadius: index == 1 ? 2.4 : 1.8)
            sparkle.fillColor = index == 1 ? ArcadeStyle.Color.accentYellow : ArcadeStyle.Color.accentCyan
            sparkle.strokeColor = .clear
            sparkle.alpha = 0
            sparkle.zPosition = 2.6
            sparkle.position = star.position.applying(.init(translationX: offset.x, y: offset.y))
            cardNode.addChild(sparkle)

            let wait = SKAction.wait(forDuration: delay + Double(index) * 0.03)
            let pop = SKAction.group([
                timed(.fadeAlpha(to: 0.95, duration: 0.05), mode: .easeOut),
                timed(.scale(to: 1.35, duration: 0.05), mode: .easeOut)
            ])
            let fade = SKAction.group([
                timed(.fadeOut(withDuration: 0.18), mode: .easeInEaseOut),
                timed(.scale(to: 0.15, duration: 0.18), mode: .easeInEaseOut)
            ])
            sparkle.run(.sequence([wait, pop, fade, .removeFromParent()]))
        }
    }

    private static func parseTimeLine(_ line: String) -> (caption: String, value: String) {
        let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else {
            return ("TIME", line)
        }
        return (String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines), String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func timed(_ action: SKAction, mode: SKActionTimingMode) -> SKAction {
        action.timingMode = mode
        return action
    }

    private func snap(_ point: CGPoint) -> CGPoint {
        CGPoint(x: round(point.x), y: round(point.y))
    }

    private func snapSize(_ size: CGSize) -> CGSize {
        CGSize(width: round(size.width), height: round(size.height))
    }
}

final class DailyResultOverlayNode: SKNode {
    var onRetry: (() -> Void)?
    var onMenu: (() -> Void)?

    private let dimNode = SKSpriteNode(color: ArcadeStyle.Color.overlayDim, size: .zero)
    private let cardNode = SKSpriteNode()
    private let accentBand = SKSpriteNode(color: ArcadeStyle.Color.accentYellow.withAlphaComponent(0.16), size: .zero)
    private let sectionLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let titleLabel = SKLabelNode(fontNamed: ArcadeFont.title)
    private let difficultyChip = SKSpriteNode()
    private let difficultyLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let timeCaptionLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let timeValueShadowLabel = SKLabelNode(fontNamed: ArcadeFont.digits)
    private let timeValueLabel = SKLabelNode(fontNamed: ArcadeFont.digits)
    private let rewardCard = SKSpriteNode()
    private let rewardCaptionLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let rewardValueLabel = SKLabelNode(fontNamed: ArcadeFont.header)
    private let bestLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let statusLabel = SKLabelNode(fontNamed: ArcadeFont.header)
    private let retryButton = ArcadeButtonNode(text: "RUN AGAIN", size: ArcadeStyle.Metric.buttonSize)
    private let menuButton = ArcadeButtonNode(text: "MENU", size: ArcadeStyle.Metric.buttonSize)

    private let difficultyText: String
    private let timeText: String
    private let bestText: String
    private let rewardText: String
    private let rewardAccentColor: SKColor
    private let isNewBest: Bool
    private let rewardClaimed: Bool
    private var cardRestPosition = CGPoint.zero

    init(
        size: CGSize,
        safeTop: CGFloat,
        safeBottom: CGFloat,
        difficultyText: String,
        timeText: String,
        bestText: String,
        rewardText: String,
        rewardAccentColor: SKColor,
        isNewBest: Bool,
        rewardClaimed: Bool
    ) {
        self.difficultyText = difficultyText
        self.timeText = timeText
        self.bestText = bestText
        self.rewardText = rewardText
        self.rewardAccentColor = rewardAccentColor
        self.isNewBest = isNewBest
        self.rewardClaimed = rewardClaimed
        super.init()

        dimNode.zPosition = 0
        dimNode.alpha = 0
        addChild(dimNode)

        cardNode.zPosition = 1
        cardNode.alpha = 0
        cardNode.setScale(0.92)
        addChild(cardNode)

        accentBand.zPosition = 1.5
        cardNode.addChild(accentBand)

        sectionLabel.text = "DAILY CHALLENGE"
        sectionLabel.fontSize = 11
        sectionLabel.fontColor = ArcadeStyle.Color.textMuted
        sectionLabel.verticalAlignmentMode = .center
        sectionLabel.horizontalAlignmentMode = .center
        sectionLabel.zPosition = 3
        cardNode.addChild(sectionLabel)

        titleLabel.text = "DAILY CLEARED"
        titleLabel.fontSize = 30
        titleLabel.fontColor = ArcadeStyle.Color.textPrimary
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.zPosition = 3
        cardNode.addChild(titleLabel)

        difficultyChip.zPosition = 2.2
        cardNode.addChild(difficultyChip)

        difficultyLabel.text = difficultyText
        difficultyLabel.fontSize = 11
        difficultyLabel.fontColor = ArcadeStyle.Color.textPrimary
        difficultyLabel.verticalAlignmentMode = .center
        difficultyLabel.horizontalAlignmentMode = .center
        difficultyLabel.zPosition = 3
        cardNode.addChild(difficultyLabel)

        timeCaptionLabel.text = "YOUR TIME"
        timeCaptionLabel.fontSize = 11
        timeCaptionLabel.fontColor = ArcadeStyle.Color.textMuted
        timeCaptionLabel.verticalAlignmentMode = .center
        timeCaptionLabel.horizontalAlignmentMode = .center
        timeCaptionLabel.zPosition = 3
        cardNode.addChild(timeCaptionLabel)

        timeValueShadowLabel.text = timeText
        timeValueShadowLabel.fontSize = 30
        timeValueShadowLabel.fontColor = SKColor(white: 0.0, alpha: 0.74)
        timeValueShadowLabel.verticalAlignmentMode = .center
        timeValueShadowLabel.horizontalAlignmentMode = .center
        timeValueShadowLabel.zPosition = 2.8
        cardNode.addChild(timeValueShadowLabel)

        timeValueLabel.text = timeText
        timeValueLabel.fontSize = 30
        timeValueLabel.fontColor = ArcadeStyle.Color.textPrimary
        timeValueLabel.verticalAlignmentMode = .center
        timeValueLabel.horizontalAlignmentMode = .center
        timeValueLabel.zPosition = 3
        cardNode.addChild(timeValueLabel)

        rewardCard.zPosition = 2.1
        cardNode.addChild(rewardCard)

        rewardCaptionLabel.text = rewardClaimed ? "DAILY STATUS" : "DAILY PAYOUT"
        rewardCaptionLabel.fontSize = 10
        rewardCaptionLabel.fontColor = ArcadeStyle.Color.textMuted
        rewardCaptionLabel.verticalAlignmentMode = .center
        rewardCaptionLabel.horizontalAlignmentMode = .center
        rewardCaptionLabel.zPosition = 3
        cardNode.addChild(rewardCaptionLabel)

        rewardValueLabel.text = rewardText
        rewardValueLabel.fontSize = rewardClaimed ? 17 : 19
        rewardValueLabel.fontColor = rewardAccentColor
        rewardValueLabel.verticalAlignmentMode = .center
        rewardValueLabel.horizontalAlignmentMode = .center
        rewardValueLabel.zPosition = 3
        cardNode.addChild(rewardValueLabel)

        bestLabel.text = "BEST · \(bestText)"
        bestLabel.fontSize = 12
        bestLabel.fontColor = ArcadeStyle.Color.textSecondary
        bestLabel.verticalAlignmentMode = .center
        bestLabel.horizontalAlignmentMode = .center
        bestLabel.zPosition = 3
        cardNode.addChild(bestLabel)

        statusLabel.text = isNewBest ? "NEW BEST!" : "CHALLENGE COMPLETE"
        statusLabel.fontSize = 18
        statusLabel.fontColor = isNewBest ? ArcadeStyle.Color.accentYellow : ArcadeStyle.Color.accentGreen
        statusLabel.verticalAlignmentMode = .center
        statusLabel.horizontalAlignmentMode = .center
        statusLabel.zPosition = 3
        cardNode.addChild(statusLabel)

        retryButton.name = "btn_retry"
        menuButton.name = "btn_levelselect"
        retryButton.setAccentColor(ArcadeStyle.Color.accentCyan)
        menuButton.setAccentColor(ArcadeStyle.Color.accentMagenta)
        retryButton.setCardStyle(.shellAccent)
        menuButton.setCardStyle(.shellPanel)
        retryButton.setEmphasisStyle(.primary)
        menuButton.setEmphasisStyle(.quiet)
        retryButton.onTap = { [weak self] in self?.onRetry?() }
        menuButton.onTap = { [weak self] in self?.onMenu?() }
        retryButton.zPosition = 4
        menuButton.zPosition = 4
        cardNode.addChild(retryButton)
        cardNode.addChild(menuButton)

        layout(in: size, safeTop: safeTop, safeBottom: safeBottom)
        animateIn()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func layout(in size: CGSize, safeTop: CGFloat, safeBottom: CGFloat) {
        dimNode.size = size
        dimNode.position = snap(.zero)

        let cardWidth = min(max(292, size.width - 28), 348)
        let cardHeight: CGFloat = 388
        let cardSize = snapSize(CGSize(width: cardWidth, height: cardHeight))
        cardNode.texture = TextureFactory.shared.cardTexture(size: cardSize, style: .shellPanel)
        cardNode.size = cardSize

        let desiredY = (safeTop + safeBottom) * 0.5
        let minY = safeBottom + cardHeight / 2 + 18
        let maxY = safeTop - cardHeight / 2 - 14
        let cardY = min(max(desiredY, minY), maxY)
        cardRestPosition = snap(CGPoint(x: 0, y: cardY))
        cardNode.position = cardRestPosition

        accentBand.size = snapSize(CGSize(width: cardSize.width * 0.5, height: 1))
        accentBand.position = snap(CGPoint(x: 0, y: cardSize.height / 2 - 36))

        let topY = cardSize.height / 2
        sectionLabel.position = snap(CGPoint(x: 0, y: topY - 34))
        titleLabel.position = snap(CGPoint(x: 0, y: topY - 72))

        let chipSize = snapSize(CGSize(width: 118, height: 28))
        difficultyChip.texture = TextureFactory.shared.cardTexture(size: chipSize, style: .shellFeature)
        difficultyChip.size = chipSize
        difficultyChip.position = snap(CGPoint(x: 0, y: topY - 112))
        difficultyLabel.position = difficultyChip.position

        timeCaptionLabel.position = snap(CGPoint(x: 0, y: topY - 146))
        timeValueShadowLabel.position = snap(CGPoint(x: 1, y: topY - 179))
        timeValueLabel.position = snap(CGPoint(x: 0, y: topY - 178))

        let rewardSize = snapSize(CGSize(width: cardSize.width - 40, height: 74))
        rewardCard.texture = TextureFactory.shared.cardTexture(
            size: rewardSize,
            style: rewardClaimed ? .shellFeature : .shellAccent
        )
        rewardCard.size = rewardSize
        rewardCard.position = snap(CGPoint(x: 0, y: topY - 232))
        rewardCaptionLabel.position = snap(CGPoint(x: 0, y: rewardCard.position.y + 14))
        rewardValueLabel.position = snap(CGPoint(x: 0, y: rewardCard.position.y - 8))

        let buttonSpacing: CGFloat = 12
        let buttonWidth = (cardSize.width - 36 - buttonSpacing) / 2
        let buttonSize = snapSize(CGSize(width: buttonWidth, height: 48))
        retryButton.size = buttonSize
        menuButton.size = buttonSize
        let buttonY = -cardSize.height / 2 + 38
        retryButton.position = snap(CGPoint(x: -(buttonWidth + buttonSpacing) / 2, y: buttonY))
        menuButton.position = snap(CGPoint(x: (buttonWidth + buttonSpacing) / 2, y: buttonY))

        let footerTop = buttonY + buttonSize.height / 2
        bestLabel.position = snap(CGPoint(x: 0, y: footerTop + 12))
        statusLabel.position = snap(CGPoint(x: 0, y: footerTop + 34))
    }

    func button(at point: CGPoint, in scene: SKScene) -> ArcadeButtonNode? {
        let buttons = [retryButton, menuButton]
        for button in buttons where button.hitTest(point, in: scene) {
                return button
        }
        return nil
    }

    func handleTap(button: ArcadeButtonNode) {
        if button === retryButton {
            retryButton.onTap?()
        } else if button === menuButton {
            menuButton.onTap?()
        }
    }

    private func animateIn() {
        ShellMotion.animateOverlayIn(dimNode: dimNode, cardNode: cardNode, restPosition: cardRestPosition)
        animateNode(sectionLabel, delay: 0.04, offsetY: 8, scaleFrom: 0.96)
        animateNode(titleLabel, delay: 0.07, offsetY: 10, scaleFrom: 0.96)
        animateNode(difficultyChip, delay: 0.10, offsetY: 8, scaleFrom: 0.94)
        animateNode(difficultyLabel, delay: 0.11, offsetY: 8, scaleFrom: 0.96)
        animateNode(timeCaptionLabel, delay: 0.14, offsetY: 8, scaleFrom: 0.96)
        animateNode(timeValueShadowLabel, delay: 0.17, offsetY: 10, scaleFrom: 0.94)
        animateNode(timeValueLabel, delay: 0.17, offsetY: 10, scaleFrom: 0.94)
        animateNode(rewardCard, delay: 0.21, offsetY: 12, scaleFrom: 0.9)
        animateNode(rewardCaptionLabel, delay: 0.24, offsetY: 8, scaleFrom: 0.96)
        animateNode(rewardValueLabel, delay: 0.24, offsetY: 8, scaleFrom: 0.96)
        animateNode(bestLabel, delay: 0.28, offsetY: 8, scaleFrom: 0.96)
        animateNode(statusLabel, delay: 0.31, offsetY: 8, scaleFrom: 0.96)
        animateNode(retryButton, delay: 0.34, offsetY: 10, scaleFrom: 0.94)
        animateNode(menuButton, delay: 0.38, offsetY: 10, scaleFrom: 0.94)

        rewardCard.run(.sequence([
            .wait(forDuration: 0.24),
            .group([
                timed(.scale(to: 1.03, duration: 0.12), mode: .easeOut),
                timed(.colorize(with: rewardAccentColor, colorBlendFactor: rewardClaimed ? 0.08 : 0.14, duration: 0.12), mode: .easeOut)
            ]),
            timed(.scale(to: 1.0, duration: 0.16), mode: .easeInEaseOut)
        ]), withKey: "dailyRewardPulse")

        spawnRewardBursts()
    }

    private func animateNode(_ node: SKNode, delay: TimeInterval, offsetY: CGFloat, scaleFrom: CGFloat) {
        let targetPosition = node.position
        let targetAlpha = node.alpha
        node.alpha = 0
        node.position = CGPoint(x: targetPosition.x, y: targetPosition.y + offsetY)
        node.setScale(scaleFrom)
        node.run(.sequence([
            .wait(forDuration: delay),
            .group([
                timed(.fadeAlpha(to: targetAlpha, duration: 0.18), mode: .easeOut),
                timed(.move(to: targetPosition, duration: 0.2), mode: .easeOut),
                timed(.scale(to: 1.0, duration: 0.2), mode: .easeOut)
            ])
        ]))
    }

    private func spawnRewardBursts() {
        for index in 0..<6 {
            let spark = SKSpriteNode(color: rewardAccentColor.withAlphaComponent(0.9), size: CGSize(width: 6, height: 6))
            spark.position = rewardCard.position
            spark.zPosition = 3.4
            spark.blendMode = .add
            cardNode.addChild(spark)
            let angle = CGFloat(index) / 6 * .pi * 2
            let distance: CGFloat = rewardClaimed ? 24 : 34
            let target = CGPoint(
                x: rewardCard.position.x + cos(angle) * distance,
                y: rewardCard.position.y + sin(angle) * distance * 0.6
            )
            spark.run(.sequence([
                .wait(forDuration: 0.26 + Double(index) * 0.015),
                .group([
                    timed(.move(to: target, duration: 0.22), mode: .easeOut),
                    timed(.fadeOut(withDuration: 0.22), mode: .easeOut),
                    timed(.scale(to: 0.15, duration: 0.22), mode: .easeOut)
                ]),
                .removeFromParent()
            ]))
        }
    }

    private func timed(_ action: SKAction, mode: SKActionTimingMode) -> SKAction {
        action.timingMode = mode
        return action
    }

    private func snap(_ point: CGPoint) -> CGPoint {
        CGPoint(x: round(point.x), y: round(point.y))
    }

    private func snapSize(_ size: CGSize) -> CGSize {
        CGSize(width: round(size.width), height: round(size.height))
    }
}
