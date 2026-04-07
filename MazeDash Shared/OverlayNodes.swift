import SpriteKit

final class PauseOverlayNode: SKNode {
    var onResume: (() -> Void)?
    var onRestart: (() -> Void)?
    var onLevelSelect: (() -> Void)?

    private let dimNode = SKSpriteNode(color: ArcadeStyle.Color.overlayDim, size: .zero)
    private let cardNode = SKSpriteNode()
    private let accentBand = SKSpriteNode(color: ArcadeStyle.Color.accentCyan.withAlphaComponent(0.14), size: .zero)
    private let subtitleLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let titleLabel = SKLabelNode(fontNamed: ArcadeFont.title)

    private let resumeButton = ArcadeButtonNode(text: "RESUME", size: ArcadeStyle.Metric.buttonSize)
    private let restartButton = ArcadeButtonNode(text: "RESTART", size: ArcadeStyle.Metric.buttonSize)
    private let levelButton = ArcadeButtonNode(text: "MENU", size: ArcadeStyle.Metric.buttonSize)

    init(size: CGSize, safeTop: CGFloat, safeBottom: CGFloat) {
        super.init()

        resumeButton.name = "btn_pause_resume"
        restartButton.name = "btn_pause_restart"
        levelButton.name = "btn_pause_menu"

        dimNode.position = snap(.zero)
        dimNode.zPosition = 0
        addChild(dimNode)

        cardNode.zPosition = 1
        addChild(cardNode)

        accentBand.zPosition = 2
        cardNode.addChild(accentBand)

        subtitleLabel.text = "RUN PAUSED"
        subtitleLabel.fontSize = 11
        subtitleLabel.fontColor = ArcadeStyle.Color.textMuted
        subtitleLabel.horizontalAlignmentMode = .center
        subtitleLabel.verticalAlignmentMode = .center
        subtitleLabel.zPosition = 3
        cardNode.addChild(subtitleLabel)

        titleLabel.text = "PAUSED"
        titleLabel.fontSize = ArcadeStyle.FontSize.pauseTitle + 6
        titleLabel.fontColor = ArcadeStyle.Color.textPrimary
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode = .center
        titleLabel.zPosition = 3
        cardNode.addChild(titleLabel)

        resumeButton.setAccentColor(ArcadeStyle.Color.accentCyan)
        restartButton.setAccentColor(ArcadeStyle.Color.accentYellow)
        levelButton.setAccentColor(ArcadeStyle.Color.accentMagenta)

        resumeButton.onTap = { [weak self] in self?.onResume?() }
        restartButton.onTap = { [weak self] in self?.onRestart?() }
        levelButton.onTap = { [weak self] in self?.onLevelSelect?() }

        resumeButton.zPosition = 4
        restartButton.zPosition = 4
        levelButton.zPosition = 4
        cardNode.addChild(resumeButton)
        cardNode.addChild(restartButton)
        cardNode.addChild(levelButton)

        layout(in: size, safeTop: safeTop, safeBottom: safeBottom)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func layout(in size: CGSize, safeTop: CGFloat, safeBottom: CGFloat) {
        dimNode.size = size
        dimNode.position = snap(.zero)

        let maxWidth = max(240, size.width - 28)
        let cardWidth = min(ArcadeStyle.Metric.pauseCardSize.width, maxWidth)
        let cardHeight = max(286, ArcadeStyle.Metric.pauseCardSize.height + 52)
        let cardSize = snapSize(CGSize(width: cardWidth, height: cardHeight))

        cardNode.texture = TextureFactory.shared.cardTexture(size: cardSize, style: .overlay)
        cardNode.size = cardSize

        let desiredY: CGFloat = 0
        let minY = safeBottom + cardSize.height / 2 + 18
        let maxY = safeTop - cardSize.height / 2 - 18
        let cardY = min(max(desiredY, minY), maxY)
        cardNode.position = snap(CGPoint(x: 0, y: cardY))

        accentBand.size = snapSize(CGSize(width: cardSize.width * 0.82, height: 30))
        accentBand.position = snap(CGPoint(x: 0, y: cardSize.height / 2 - 34))

        subtitleLabel.position = snap(CGPoint(x: 0, y: cardSize.height / 2 - 36))
        titleLabel.position = snap(CGPoint(x: 0, y: cardSize.height / 2 - 70))

        let buttonWidth = max(188, min(cardSize.width - 36, ArcadeStyle.Metric.buttonSize.width))
        let buttonSize = snapSize(CGSize(width: buttonWidth, height: 52))
        let spacing: CGFloat = 14
        let startY = cardSize.height * 0.1

        resumeButton.size = buttonSize
        restartButton.size = buttonSize
        levelButton.size = buttonSize

        resumeButton.position = snap(CGPoint(x: 0, y: startY))
        restartButton.position = snap(CGPoint(x: 0, y: startY - buttonSize.height - spacing))
        levelButton.position = snap(CGPoint(x: 0, y: startY - (buttonSize.height + spacing) * 2))
    }

    func button(at point: CGPoint, in scene: SKScene) -> ArcadeButtonNode? {
        let localPoint: CGPoint
        if let camera = scene.camera, inParentHierarchy(camera) {
            let cameraPoint = camera.convert(point, from: scene)
            localPoint = convert(cameraPoint, from: camera)
        } else {
            localPoint = convert(point, from: scene)
        }
        let buttons = [resumeButton, restartButton, levelButton]
        for button in buttons {
            let buttonPoint = button.convert(localPoint, from: self)
            if button.contains(buttonPoint) {
                return button
            }
        }
        return nil
    }

    func handleTap(button: ArcadeButtonNode) {
        if button === resumeButton {
            resumeButton.onTap?()
        } else if button === restartButton {
            restartButton.onTap?()
        } else if button === levelButton {
            levelButton.onTap?()
        }
    }

    func handleTap(named name: String) {
        if name == "btn_pause_resume" {
            resumeButton.onTap?()
        } else if name == "btn_pause_restart" {
            restartButton.onTap?()
        } else if name == "btn_pause_menu" {
            levelButton.onTap?()
        }
    }

    private func snap(_ point: CGPoint) -> CGPoint {
        CGPoint(x: round(point.x), y: round(point.y))
    }

    private func snapSize(_ size: CGSize) -> CGSize {
        CGSize(width: round(size.width), height: round(size.height))
    }
}

final class ChallengeResultOverlayNode: SKNode {
    var onRetry: (() -> Void)?
    var onMenu: (() -> Void)?

    private let dimNode = SKSpriteNode(color: ArcadeStyle.Color.overlayDim, size: .zero)
    private let cardNode = SKSpriteNode()
    private let accentBand = SKSpriteNode(color: ArcadeStyle.Color.accentMagenta.withAlphaComponent(0.14), size: .zero)
    private let sectionLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let titleLabel = SKLabelNode(fontNamed: ArcadeFont.title)
    private let completedValueLabel = SKLabelNode(fontNamed: ArcadeFont.title)
    private let completedCaptionLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let modeLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let bestLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let recordLabel = SKLabelNode(fontNamed: ArcadeFont.header)

    private let retryButton = ArcadeButtonNode(text: "RUN AGAIN", size: ArcadeStyle.Metric.buttonSize)
    private let menuButton = ArcadeButtonNode(text: "MENU", size: ArcadeStyle.Metric.buttonSize)

    private let duration: TimeChallengeDuration
    private let completedMazes: Int
    private let bestMazes: Int
    private let isNewRecord: Bool

    init(size: CGSize, safeTop: CGFloat, safeBottom: CGFloat, duration: TimeChallengeDuration, completedMazes: Int, bestMazes: Int, isNewRecord: Bool) {
        self.duration = duration
        self.completedMazes = completedMazes
        self.bestMazes = bestMazes
        self.isNewRecord = isNewRecord
        super.init()

        retryButton.name = "btn_retry"
        menuButton.name = "btn_levelselect"

        retryButton.setAccentColor(ArcadeStyle.Color.accentCyan)
        menuButton.setAccentColor(ArcadeStyle.Color.accentMagenta)
        retryButton.onTap = { [weak self] in self?.onRetry?() }
        menuButton.onTap = { [weak self] in self?.onMenu?() }

        dimNode.zPosition = 0
        addChild(dimNode)

        cardNode.zPosition = 1
        addChild(cardNode)

        accentBand.zPosition = 1.5
        cardNode.addChild(accentBand)

        sectionLabel.text = "TIME CHALLENGE"
        sectionLabel.fontSize = 11
        sectionLabel.fontColor = ArcadeStyle.Color.textMuted
        sectionLabel.verticalAlignmentMode = .center
        sectionLabel.horizontalAlignmentMode = .center
        sectionLabel.zPosition = 3
        cardNode.addChild(sectionLabel)

        titleLabel.text = "TIME UP"
        titleLabel.fontSize = 30
        titleLabel.fontColor = ArcadeStyle.Color.textPrimary
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.zPosition = 3
        cardNode.addChild(titleLabel)

        completedValueLabel.text = "\(completedMazes)"
        completedValueLabel.fontSize = 46
        completedValueLabel.fontColor = ArcadeStyle.Color.accentCyan
        completedValueLabel.verticalAlignmentMode = .center
        completedValueLabel.horizontalAlignmentMode = .center
        completedValueLabel.zPosition = 3
        cardNode.addChild(completedValueLabel)

        completedCaptionLabel.text = completedMazes == 1 ? "MAZE COMPLETED" : "MAZES COMPLETED"
        completedCaptionLabel.fontSize = 12
        completedCaptionLabel.fontColor = ArcadeStyle.Color.textSecondary
        completedCaptionLabel.verticalAlignmentMode = .center
        completedCaptionLabel.horizontalAlignmentMode = .center
        completedCaptionLabel.zPosition = 3
        cardNode.addChild(completedCaptionLabel)

        modeLabel.text = duration.summaryLine.uppercased()
        modeLabel.fontSize = 13
        modeLabel.fontColor = ArcadeStyle.Color.textPrimary
        modeLabel.verticalAlignmentMode = .center
        modeLabel.horizontalAlignmentMode = .center
        modeLabel.zPosition = 3
        cardNode.addChild(modeLabel)

        bestLabel.text = "BEST RUN · \(bestMazes) \(bestMazes == 1 ? "MAZE" : "MAZES")"
        bestLabel.fontSize = 12
        bestLabel.fontColor = ArcadeStyle.Color.textMuted
        bestLabel.verticalAlignmentMode = .center
        bestLabel.horizontalAlignmentMode = .center
        bestLabel.zPosition = 3
        cardNode.addChild(bestLabel)

        recordLabel.text = isNewRecord ? "NEW RECORD!" : "KEEP PUSHING"
        recordLabel.fontSize = 18
        recordLabel.fontColor = isNewRecord ? ArcadeStyle.Color.accentYellow : ArcadeStyle.Color.accentMagenta
        recordLabel.verticalAlignmentMode = .center
        recordLabel.horizontalAlignmentMode = .center
        recordLabel.zPosition = 3
        cardNode.addChild(recordLabel)

        retryButton.zPosition = 4
        menuButton.zPosition = 4
        cardNode.addChild(retryButton)
        cardNode.addChild(menuButton)

        layout(in: size, safeTop: safeTop, safeBottom: safeBottom)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func layout(in size: CGSize, safeTop: CGFloat, safeBottom: CGFloat) {
        dimNode.size = size
        dimNode.position = snap(.zero)

        let cardWidth = min(max(284, size.width - 28), 338)
        let cardHeight: CGFloat = 348
        let cardSize = snapSize(CGSize(width: cardWidth, height: cardHeight))
        cardNode.texture = TextureFactory.shared.cardTexture(size: cardSize, style: .overlay)
        cardNode.size = cardSize

        let desiredY = safeTop - cardHeight * 0.48
        let minY = safeBottom + cardHeight / 2 + 18
        let maxY = safeTop - cardHeight / 2 - 14
        let cardY = min(max(desiredY, minY), maxY)
        cardNode.position = snap(CGPoint(x: 0, y: cardY))

        accentBand.size = snapSize(CGSize(width: cardSize.width * 0.82, height: 30))
        accentBand.position = snap(CGPoint(x: 0, y: cardSize.height / 2 - 34))

        let topY = cardSize.height / 2
        sectionLabel.position = snap(CGPoint(x: 0, y: topY - 34))
        titleLabel.position = snap(CGPoint(x: 0, y: topY - 72))
        completedValueLabel.position = snap(CGPoint(x: 0, y: topY - 132))
        completedCaptionLabel.position = snap(CGPoint(x: 0, y: topY - 168))
        recordLabel.position = snap(CGPoint(x: 0, y: topY - 200))
        modeLabel.position = snap(CGPoint(x: 0, y: topY - 228))
        bestLabel.position = snap(CGPoint(x: 0, y: topY - 254))

        let buttonSpacing: CGFloat = 12
        let buttonWidth = (cardSize.width - 36 - buttonSpacing) / 2
        let buttonSize = snapSize(CGSize(width: buttonWidth, height: 48))
        retryButton.size = buttonSize
        menuButton.size = buttonSize
        retryButton.position = snap(CGPoint(x: -(buttonWidth + buttonSpacing) / 2, y: -cardSize.height / 2 + 42))
        menuButton.position = snap(CGPoint(x: (buttonWidth + buttonSpacing) / 2, y: -cardSize.height / 2 + 42))
    }

    func button(at point: CGPoint, in node: SKNode) -> ArcadeButtonNode? {
        let localPoint = convert(point, from: node)
        let buttons = [retryButton, menuButton]
        for button in buttons where button.isEnabled {
            let buttonPoint = button.convert(localPoint, from: self)
            if button.contains(buttonPoint) {
                return button
            }
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

    private func snap(_ point: CGPoint) -> CGPoint {
        CGPoint(x: round(point.x), y: round(point.y))
    }

    private func snapSize(_ size: CGSize) -> CGSize {
        CGSize(width: round(size.width), height: round(size.height))
    }
}

final class MechanicTutorialOverlayNode: SKNode {
    let mechanic: Mechanic
    var onContinue: (() -> Void)?

    private let descriptor: MechanicTutorialDescriptor
    private let dimNode = SKSpriteNode(color: ArcadeStyle.Color.overlayDim, size: .zero)
    private let cardNode = SKSpriteNode()
    private let accentBand = SKSpriteNode(color: ArcadeStyle.Color.accentCyan.withAlphaComponent(0.12), size: .zero)
    private let sectionLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let titleLabel = SKLabelNode(fontNamed: ArcadeFont.title)
    private let demoFrame = SKSpriteNode()
    private let messageContainer = SKNode()
    private let continueButton = ArcadeButtonNode(text: "CONTINUE", size: ArcadeStyle.Metric.buttonSize)

    init(size: CGSize, safeTop: CGFloat, safeBottom: CGFloat, mechanic: Mechanic) {
        self.mechanic = mechanic
        self.descriptor = tutorialDescriptor(for: mechanic)
        super.init()

        continueButton.name = "btn_tutorial_continue"
        continueButton.setAccentColor(ArcadeStyle.Color.accentCyan)
        continueButton.onTap = { [weak self] in
            self?.onContinue?()
        }

        dimNode.zPosition = 0
        addChild(dimNode)

        cardNode.zPosition = 1
        addChild(cardNode)

        accentBand.zPosition = 1.2
        cardNode.addChild(accentBand)

        sectionLabel.text = "NEW MECHANIC"
        sectionLabel.fontSize = 11
        sectionLabel.fontColor = ArcadeStyle.Color.textMuted
        sectionLabel.verticalAlignmentMode = .center
        sectionLabel.horizontalAlignmentMode = .center
        sectionLabel.zPosition = 3
        cardNode.addChild(sectionLabel)

        titleLabel.text = descriptor.title
        titleLabel.fontSize = 24
        titleLabel.fontColor = ArcadeStyle.Color.textPrimary
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.zPosition = 3
        cardNode.addChild(titleLabel)

        demoFrame.zPosition = 2
        cardNode.addChild(demoFrame)

        messageContainer.zPosition = 3
        cardNode.addChild(messageContainer)

        continueButton.zPosition = 4
        cardNode.addChild(continueButton)

        layout(in: size, safeTop: safeTop, safeBottom: safeBottom)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func layout(in size: CGSize, safeTop: CGFloat, safeBottom: CGFloat) {
        dimNode.size = size
        dimNode.position = snap(.zero)

        let cardWidth = min(max(300, size.width - 28), 364)
        let cardHeight: CGFloat = 336
        let cardSize = snapSize(CGSize(width: cardWidth, height: cardHeight))
        cardNode.texture = TextureFactory.shared.cardTexture(size: cardSize, style: .overlay)
        cardNode.size = cardSize

        let desiredY: CGFloat = 0
        let minY = safeBottom + cardHeight / 2 + 18
        let maxY = safeTop - cardHeight / 2 - 18
        let cardY = min(max(desiredY, minY), maxY)
        cardNode.position = snap(CGPoint(x: 0, y: cardY))

        accentBand.size = snapSize(CGSize(width: cardSize.width * 0.84, height: 30))
        accentBand.position = snap(CGPoint(x: 0, y: cardSize.height / 2 - 34))

        let topY = cardSize.height / 2
        sectionLabel.position = snap(CGPoint(x: 0, y: topY - 34))
        titleLabel.position = snap(CGPoint(x: 0, y: topY - 66))

        let demoSize = snapSize(CGSize(width: cardSize.width - 34, height: 126))
        demoFrame.texture = TextureFactory.shared.cardTexture(size: demoSize, style: .hud)
        demoFrame.size = demoSize
        demoFrame.position = snap(CGPoint(x: 0, y: 28))

        layoutMessage(maxWidth: cardSize.width - 44)
        let buttonWidth = min(cardSize.width - 40, ArcadeStyle.Metric.buttonSize.width)
        continueButton.size = snapSize(CGSize(width: buttonWidth, height: 50))
        continueButton.position = snap(CGPoint(x: 0, y: -cardSize.height / 2 + 42))

        configureDemo(in: demoSize)
    }

    func button(at point: CGPoint, in scene: SKScene) -> ArcadeButtonNode? {
        let localPoint: CGPoint
        if let camera = scene.camera, inParentHierarchy(camera) {
            let cameraPoint = camera.convert(point, from: scene)
            localPoint = convert(cameraPoint, from: camera)
        } else {
            localPoint = convert(point, from: scene)
        }
        let buttonPoint = continueButton.convert(localPoint, from: self)
        return continueButton.contains(buttonPoint) ? continueButton : nil
    }

    func handleTap(button: ArcadeButtonNode) {
        if button === continueButton {
            continueButton.onTap?()
        }
    }

    private func layoutMessage(maxWidth: CGFloat) {
        messageContainer.removeAllChildren()
        let lines = wrappedLines(for: descriptor.message, maxCharacters: maxWidth > 320 ? 38 : 32)
        let startY: CGFloat = -58
        for (index, line) in lines.enumerated() {
            let shadow = SKLabelNode(fontNamed: ArcadeFont.body)
            shadow.text = line
            shadow.fontSize = 14
            shadow.fontColor = SKColor(white: 0.0, alpha: 0.44)
            shadow.alpha = 0.9
            shadow.horizontalAlignmentMode = .center
            shadow.verticalAlignmentMode = .center
            shadow.position = snap(CGPoint(x: 1, y: startY - CGFloat(index) * 18 - 1))
            messageContainer.addChild(shadow)

            let label = SKLabelNode(fontNamed: ArcadeFont.body)
            label.text = line
            label.fontSize = 14
            label.fontColor = ArcadeStyle.Color.textSecondary
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.position = snap(CGPoint(x: 0, y: startY - CGFloat(index) * 18))
            messageContainer.addChild(label)
        }
    }

    private func configureDemo(in size: CGSize) {
        demoFrame.removeAllChildren()

        let floor = SKShapeNode(rectOf: CGSize(width: size.width - 16, height: size.height - 16), cornerRadius: 18)
        floor.fillColor = SKColor(white: 0.05, alpha: 0.36)
        floor.strokeColor = ArcadeStyle.Color.panelBorder.withAlphaComponent(0.45)
        floor.lineWidth = 1
        floor.zPosition = 0
        demoFrame.addChild(floor)

        addDemoGrid(to: demoFrame, size: size)

        switch mechanic {
        case .oneWay:
            configureArrowDemo(in: size)
        case .fog:
            configureFogDemo(in: size)
        case .teleporters:
            configureTeleporterDemo(in: size)
        case .switchDoors:
            configureSwitchDemo(in: size)
        case .keysDoors:
            configureKeyDoorDemo(in: size)
        case .timingGates:
            configureGateDemo(in: size)
        }
    }

    private func configureArrowDemo(in size: CGSize) {
        let laneWidth = size.width - 42
        let lane = SKShapeNode(rectOf: CGSize(width: laneWidth, height: 18), cornerRadius: 9)
        lane.fillColor = SKColor(white: 0.12, alpha: 0.82)
        lane.strokeColor = ArcadeStyle.Color.panelBorder.withAlphaComponent(0.3)
        lane.lineWidth = 1
        lane.position = snap(CGPoint(x: 0, y: 0))
        demoFrame.addChild(lane)

        let arrowTile = SKShapeNode(rectOf: CGSize(width: 34, height: 34), cornerRadius: 10)
        arrowTile.fillColor = ArcadeStyle.Color.accentMagenta.withAlphaComponent(0.24)
        arrowTile.strokeColor = ArcadeStyle.Color.accentMagenta
        arrowTile.lineWidth = 1.5
        arrowTile.position = snap(CGPoint(x: 0, y: 0))
        demoFrame.addChild(arrowTile)

        let arrowLabel = SKLabelNode(fontNamed: ArcadeFont.title)
        arrowLabel.text = ">"
        arrowLabel.fontSize = 22
        arrowLabel.fontColor = ArcadeStyle.Color.accentMagenta
        arrowLabel.verticalAlignmentMode = .center
        arrowLabel.position = snap(CGPoint(x: 0, y: -1))
        arrowTile.addChild(arrowLabel)

        let runner = makeDemoRunner(color: ArcadeStyle.Color.accentCyan)
        runner.position = snap(CGPoint(x: -laneWidth / 2 + 12, y: 0))
        demoFrame.addChild(runner)
        runner.run(.repeatForever(.sequence([
            .moveTo(x: laneWidth / 2 - 12, duration: 1.15),
            .wait(forDuration: 0.2),
            .moveTo(x: -laneWidth / 2 + 12, duration: 0)
        ])))

        let blockedRunner = makeDemoRunner(color: ArcadeStyle.Color.accentYellow.withAlphaComponent(0.95))
        blockedRunner.setScale(0.8)
        blockedRunner.position = snap(CGPoint(x: laneWidth / 2 - 20, y: -26))
        demoFrame.addChild(blockedRunner)
        blockedRunner.run(.repeatForever(.sequence([
            .moveTo(x: 14, duration: 0.45),
            .group([
                .moveBy(x: 10, y: 0, duration: 0.12),
                .rotate(byAngle: 0.08, duration: 0.12)
            ]),
            .moveTo(x: laneWidth / 2 - 20, duration: 0.0),
            .rotate(toAngle: 0, duration: 0.0),
            .wait(forDuration: 0.58)
        ])))

        let denyLabel = SKLabelNode(fontNamed: ArcadeFont.body)
        denyLabel.text = "BLOCKED"
        denyLabel.fontSize = 10
        denyLabel.fontColor = ArcadeStyle.Color.accentYellow
        denyLabel.position = snap(CGPoint(x: 30, y: -27))
        denyLabel.alpha = 0
        demoFrame.addChild(denyLabel)
        denyLabel.run(.repeatForever(.sequence([
            .wait(forDuration: 0.26),
            .fadeAlpha(to: 1.0, duration: 0.08),
            .wait(forDuration: 0.14),
            .fadeOut(withDuration: 0.18),
            .wait(forDuration: 0.49)
        ])))
    }

    private func configureFogDemo(in size: CGSize) {
        let contentNode = SKNode()
        contentNode.zPosition = 1
        demoFrame.addChild(contentNode)

        let pathColor = ArcadeStyle.Color.accentCyan.withAlphaComponent(0.22)
        let pathFrames = [
            CGRect(x: -size.width * 0.34, y: 18, width: size.width * 0.42, height: 14),
            CGRect(x: -size.width * 0.06, y: -4, width: 14, height: 54),
            CGRect(x: 0, y: -14, width: size.width * 0.34, height: 14)
        ]
        for rect in pathFrames {
            let node = SKShapeNode(rectOf: CGSize(width: rect.width, height: rect.height), cornerRadius: 6)
            node.fillColor = pathColor
            node.strokeColor = pathColor
            node.position = snap(CGPoint(x: rect.midX, y: rect.midY))
            contentNode.addChild(node)
        }

        let cropNode = SKCropNode()
        cropNode.zPosition = 2
        demoFrame.addChild(cropNode)

        let visibleContent = contentNode.copy() as? SKNode ?? SKNode()
        cropNode.addChild(visibleContent)

        let maskNode = SKShapeNode(circleOfRadius: 26)
        maskNode.fillColor = .white
        maskNode.strokeColor = .clear
        maskNode.position = snap(CGPoint(x: -size.width * 0.28, y: 22))
        cropNode.maskNode = maskNode

        let player = makeDemoRunner(color: ArcadeStyle.Color.accentCyan)
        player.position = maskNode.position
        demoFrame.addChild(player)

        let fogCover = SKShapeNode(rectOf: CGSize(width: size.width - 18, height: size.height - 18), cornerRadius: 18)
        fogCover.fillColor = SKColor(white: 0.01, alpha: 0.82)
        fogCover.strokeColor = .clear
        fogCover.zPosition = 1.8
        demoFrame.addChild(fogCover)

        let revealRing = SKShapeNode(circleOfRadius: 28)
        revealRing.fillColor = .clear
        revealRing.strokeColor = ArcadeStyle.Color.accentCyan.withAlphaComponent(0.45)
        revealRing.lineWidth = 2
        revealRing.position = maskNode.position
        revealRing.zPosition = 3
        demoFrame.addChild(revealRing)

        let waypoints = [
            snap(CGPoint(x: -size.width * 0.28, y: 22)),
            snap(CGPoint(x: -size.width * 0.02, y: 22)),
            snap(CGPoint(x: -size.width * 0.02, y: -22)),
            snap(CGPoint(x: size.width * 0.2, y: -22))
        ]
        let segmentDuration: TimeInterval = 0.42
        let pathActions = zip(waypoints, waypoints.dropFirst()).flatMap { _, next in
            [
                SKAction.move(to: next, duration: segmentDuration),
                SKAction.run {
                    revealRing.run(.sequence([
                        .scale(to: 1.08, duration: 0.12),
                        .scale(to: 1.0, duration: 0.16)
                    ]))
                }
            ]
        }
        let reset = SKAction.run {
            if let first = waypoints.first {
                player.position = first
                maskNode.position = first
                revealRing.position = first
            }
        }
        let follow = SKAction.run {
            maskNode.position = player.position
            revealRing.position = player.position
        }
        let sequence = SKAction.sequence(pathActions.flatMap { [ $0, follow ] } + [reset, .wait(forDuration: 0.36)])
        player.run(.repeatForever(sequence))
    }

    private func configureTeleporterDemo(in size: CGSize) {
        let leftPortal = makePortalNode(label: "A")
        leftPortal.position = snap(CGPoint(x: -size.width * 0.24, y: 0))
        demoFrame.addChild(leftPortal)

        let rightPortal = makePortalNode(label: "B")
        rightPortal.position = snap(CGPoint(x: size.width * 0.24, y: 0))
        demoFrame.addChild(rightPortal)

        let runner = makeDemoRunner(color: ArcadeStyle.Color.accentCyan)
        runner.position = snap(CGPoint(x: -size.width * 0.38, y: 0))
        demoFrame.addChild(runner)

        runner.run(.repeatForever(.sequence([
            .moveTo(x: leftPortal.position.x, duration: 0.55),
            .group([
                .fadeOut(withDuration: 0.12),
                .scale(to: 0.55, duration: 0.12)
            ]),
            .run {
                runner.position = rightPortal.position
            },
            .group([
                .fadeIn(withDuration: 0.12),
                .scale(to: 1.0, duration: 0.12)
            ]),
            .moveTo(x: size.width * 0.38, duration: 0.45),
            .run {
                runner.position = self.snap(CGPoint(x: -size.width * 0.38, y: 0))
            },
            .wait(forDuration: 0.24)
        ])))
    }

    private func configureSwitchDemo(in size: CGSize) {
        let switchNode = SKShapeNode(rectOf: CGSize(width: 34, height: 22), cornerRadius: 8)
        switchNode.fillColor = ArcadeStyle.Color.accentCyan.withAlphaComponent(0.22)
        switchNode.strokeColor = ArcadeStyle.Color.accentCyan
        switchNode.lineWidth = 1.4
        switchNode.position = snap(CGPoint(x: -size.width * 0.24, y: 0))
        demoFrame.addChild(switchNode)

        let switchBar = SKShapeNode(rectOf: CGSize(width: 18, height: 4), cornerRadius: 2)
        switchBar.fillColor = ArcadeStyle.Color.accentCyan
        switchBar.strokeColor = .clear
        switchBar.position = snap(CGPoint(x: 0, y: 0))
        switchNode.addChild(switchBar)

        let doorNode = SKShapeNode(rectOf: CGSize(width: 18, height: 58), cornerRadius: 8)
        doorNode.fillColor = ArcadeStyle.Color.accentMagenta.withAlphaComponent(0.24)
        doorNode.strokeColor = ArcadeStyle.Color.accentMagenta
        doorNode.lineWidth = 1.5
        doorNode.position = snap(CGPoint(x: size.width * 0.18, y: 0))
        demoFrame.addChild(doorNode)

        let runner = makeDemoRunner(color: ArcadeStyle.Color.accentCyan)
        runner.position = snap(CGPoint(x: -size.width * 0.38, y: 0))
        demoFrame.addChild(runner)

        let openAction = SKAction.group([
            .fadeAlpha(to: 0.25, duration: 0.16),
            .scaleX(to: 0.2, duration: 0.16)
        ])
        let resetAction = SKAction.group([
            .fadeAlpha(to: 1.0, duration: 0.0),
            .scaleX(to: 1.0, duration: 0.0)
        ])

        runner.run(.repeatForever(.sequence([
            .moveTo(x: switchNode.position.x, duration: 0.42),
            .run {
                switchNode.run(.sequence([
                    .scale(to: 1.08, duration: 0.08),
                    .scale(to: 1.0, duration: 0.12)
                ]))
                switchNode.fillColor = ArcadeStyle.Color.accentYellow.withAlphaComponent(0.28)
                switchBar.fillColor = ArcadeStyle.Color.accentYellow
                doorNode.run(openAction)
            },
            .moveTo(x: size.width * 0.34, duration: 0.48),
            .run {
                runner.position = self.snap(CGPoint(x: -size.width * 0.38, y: 0))
                switchNode.fillColor = ArcadeStyle.Color.accentCyan.withAlphaComponent(0.22)
                switchBar.fillColor = ArcadeStyle.Color.accentCyan
                doorNode.run(resetAction)
            },
            .wait(forDuration: 0.26)
        ])))
    }

    private func configureKeyDoorDemo(in size: CGSize) {
        let keyNode = makeKeyNode()
        keyNode.position = snap(CGPoint(x: -size.width * 0.18, y: 0))
        demoFrame.addChild(keyNode)

        let doorNode = SKShapeNode(rectOf: CGSize(width: 20, height: 58), cornerRadius: 8)
        doorNode.fillColor = ArcadeStyle.Color.accentMagenta.withAlphaComponent(0.25)
        doorNode.strokeColor = ArcadeStyle.Color.accentMagenta
        doorNode.lineWidth = 1.5
        doorNode.position = snap(CGPoint(x: size.width * 0.18, y: 0))
        demoFrame.addChild(doorNode)

        let runner = makeDemoRunner(color: ArcadeStyle.Color.accentCyan)
        runner.position = snap(CGPoint(x: -size.width * 0.36, y: 0))
        demoFrame.addChild(runner)

        runner.run(.repeatForever(.sequence([
            .moveTo(x: keyNode.position.x, duration: 0.42),
            .run {
                keyNode.run(.group([
                    .fadeOut(withDuration: 0.14),
                    .scale(to: 0.4, duration: 0.14)
                ]))
                doorNode.run(.group([
                    .fadeAlpha(to: 0.25, duration: 0.14),
                    .scaleX(to: 0.22, duration: 0.14)
                ]))
            },
            .moveTo(x: size.width * 0.34, duration: 0.5),
            .run {
                runner.position = self.snap(CGPoint(x: -size.width * 0.36, y: 0))
                keyNode.alpha = 1.0
                keyNode.setScale(1.0)
                doorNode.alpha = 1.0
                doorNode.xScale = 1.0
            },
            .wait(forDuration: 0.28)
        ])))
    }

    private func configureGateDemo(in size: CGSize) {
        let gateNode = SKShapeNode(rectOf: CGSize(width: 18, height: 58), cornerRadius: 8)
        gateNode.fillColor = ArcadeStyle.Color.accentYellow.withAlphaComponent(0.24)
        gateNode.strokeColor = ArcadeStyle.Color.accentYellow
        gateNode.lineWidth = 1.5
        gateNode.position = snap(CGPoint(x: 0, y: 0))
        demoFrame.addChild(gateNode)

        let runner = makeDemoRunner(color: ArcadeStyle.Color.accentCyan)
        runner.position = snap(CGPoint(x: -size.width * 0.36, y: 0))
        demoFrame.addChild(runner)

        let gateLoop = SKAction.repeatForever(.sequence([
            .group([
                .fadeAlpha(to: 0.18, duration: 0.26),
                .scaleX(to: 0.18, duration: 0.26)
            ]),
            .wait(forDuration: 0.14),
            .group([
                .fadeAlpha(to: 1.0, duration: 0.24),
                .scaleX(to: 1.0, duration: 0.24)
            ]),
            .wait(forDuration: 0.26)
        ]))
        gateNode.run(gateLoop)

        runner.run(.repeatForever(.sequence([
            .wait(forDuration: 0.32),
            .moveTo(x: size.width * 0.34, duration: 0.54),
            .run {
                runner.position = self.snap(CGPoint(x: -size.width * 0.36, y: 0))
            },
            .wait(forDuration: 0.3)
        ])))
    }

    private func addDemoGrid(to parent: SKNode, size: CGSize) {
        let grid = SKNode()
        grid.zPosition = 0.5
        let spacing: CGFloat = 18
        let verticalCount = Int(size.width / spacing)
        let horizontalCount = Int(size.height / spacing)

        for index in 0...verticalCount {
            let x = -size.width / 2 + CGFloat(index) * spacing
            let line = SKSpriteNode(color: ArcadeStyle.Color.accentCyan.withAlphaComponent(0.06), size: CGSize(width: 1, height: size.height - 10))
            line.position = snap(CGPoint(x: x, y: 0))
            grid.addChild(line)
        }

        for index in 0...horizontalCount {
            let y = -size.height / 2 + CGFloat(index) * spacing
            let line = SKSpriteNode(color: ArcadeStyle.Color.accentMagenta.withAlphaComponent(0.04), size: CGSize(width: size.width - 10, height: 1))
            line.position = snap(CGPoint(x: 0, y: y))
            grid.addChild(line)
        }

        parent.addChild(grid)
    }

    private func makeDemoRunner(color: SKColor) -> SKSpriteNode {
        let size = snapSize(CGSize(width: 18, height: 18))
        let runner = SKSpriteNode(texture: TextureFactory.shared.playerTexture(size: size))
        runner.color = color
        runner.colorBlendFactor = 0.12
        runner.zPosition = 4
        return runner
    }

    private func makePortalNode(label: String) -> SKNode {
        let container = SKNode()
        let portal = SKSpriteNode(texture: TextureFactory.shared.teleporterTexture(size: CGSize(width: 32, height: 32)))
        portal.zPosition = 1
        portal.run(.repeatForever(.sequence([
            .group([
                .scale(to: 1.08, duration: 0.48),
                .fadeAlpha(to: 0.88, duration: 0.48)
            ]),
            .group([
                .scale(to: 1.0, duration: 0.48),
                .fadeAlpha(to: 1.0, duration: 0.48)
            ])
        ])))
        container.addChild(portal)

        let labelNode = SKLabelNode(fontNamed: ArcadeFont.body)
        labelNode.text = label
        labelNode.fontSize = 11
        labelNode.fontColor = ArcadeStyle.Color.textPrimary
        labelNode.verticalAlignmentMode = .center
        labelNode.position = snap(CGPoint(x: 0, y: -1))
        labelNode.zPosition = 2
        container.addChild(labelNode)
        return container
    }

    private func makeKeyNode() -> SKNode {
        let key = SKNode()

        let head = SKShapeNode(circleOfRadius: 8)
        head.fillColor = ArcadeStyle.Color.accentYellow
        head.strokeColor = SKColor(white: 1.0, alpha: 0.5)
        head.lineWidth = 1.2
        head.position = snap(CGPoint(x: -4, y: 0))
        key.addChild(head)

        let shaft = SKShapeNode(rectOf: CGSize(width: 16, height: 4), cornerRadius: 2)
        shaft.fillColor = ArcadeStyle.Color.accentYellow
        shaft.strokeColor = .clear
        shaft.position = snap(CGPoint(x: 7, y: 0))
        key.addChild(shaft)

        let toothA = SKShapeNode(rectOf: CGSize(width: 4, height: 5), cornerRadius: 1)
        toothA.fillColor = ArcadeStyle.Color.accentYellow
        toothA.strokeColor = .clear
        toothA.position = snap(CGPoint(x: 12, y: -4))
        key.addChild(toothA)

        let toothB = SKShapeNode(rectOf: CGSize(width: 4, height: 4), cornerRadius: 1)
        toothB.fillColor = ArcadeStyle.Color.accentYellow
        toothB.strokeColor = .clear
        toothB.position = snap(CGPoint(x: 16, y: 4))
        key.addChild(toothB)

        return key
    }

    private func wrappedLines(for text: String, maxCharacters: Int) -> [String] {
        let words = text.split(separator: " ").map(String.init)
        var lines: [String] = []
        var current = ""

        for word in words {
            let candidate = current.isEmpty ? word : "\(current) \(word)"
            if candidate.count <= maxCharacters {
                current = candidate
            } else {
                if !current.isEmpty {
                    lines.append(current)
                }
                current = word
            }
        }

        if !current.isEmpty {
            lines.append(current)
        }

        return lines
    }

    private func snap(_ point: CGPoint) -> CGPoint {
        CGPoint(x: round(point.x), y: round(point.y))
    }

    private func snapSize(_ size: CGSize) -> CGSize {
        CGSize(width: round(size.width), height: round(size.height))
    }
}

final class RewardUnlockOverlayNode: SKNode {
    var onContinue: (() -> Void)?

    private let reward: StoryCosmeticReward
    private let dimNode = SKSpriteNode(color: ArcadeStyle.Color.overlayDim, size: .zero)
    private let cardNode = SKSpriteNode()
    private let accentBand = SKSpriteNode(color: ArcadeStyle.Color.accentYellow.withAlphaComponent(0.16), size: .zero)
    private let titleLabel = SKLabelNode(fontNamed: ArcadeFont.header)
    private let itemLabel = SKLabelNode(fontNamed: ArcadeFont.title)
    private let detailLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let milestoneLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let previewNode = SKNode()
    private let continueButton = ArcadeButtonNode(text: "CONTINUE", size: ArcadeStyle.Metric.buttonSize)

    init(size: CGSize, safeTop: CGFloat, safeBottom: CGFloat, reward: StoryCosmeticReward) {
        self.reward = reward
        super.init()

        continueButton.name = "btn_reward_continue"
        continueButton.setAccentColor(ArcadeStyle.Color.accentYellow)
        continueButton.onTap = { [weak self] in
            self?.onContinue?()
        }

        dimNode.zPosition = 0
        addChild(dimNode)

        cardNode.zPosition = 1
        addChild(cardNode)

        accentBand.zPosition = 1.2
        cardNode.addChild(accentBand)

        titleLabel.text = reward.title
        titleLabel.fontSize = 14
        titleLabel.fontColor = ArcadeStyle.Color.accentYellow
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode = .center
        titleLabel.zPosition = 3
        titleLabel.numberOfLines = 1
        cardNode.addChild(titleLabel)

        itemLabel.text = reward.item.displayName
        itemLabel.fontSize = 23
        itemLabel.fontColor = ArcadeStyle.Color.textPrimary
        itemLabel.horizontalAlignmentMode = .center
        itemLabel.verticalAlignmentMode = .center
        itemLabel.zPosition = 3
        itemLabel.numberOfLines = 2
        itemLabel.lineBreakMode = .byWordWrapping
        cardNode.addChild(itemLabel)

        detailLabel.text = reward.detail
        detailLabel.fontSize = 11
        detailLabel.fontColor = ArcadeStyle.Color.textSecondary
        detailLabel.horizontalAlignmentMode = .center
        detailLabel.verticalAlignmentMode = .center
        detailLabel.zPosition = 3
        detailLabel.numberOfLines = 2
        detailLabel.lineBreakMode = .byWordWrapping
        cardNode.addChild(detailLabel)

        milestoneLabel.fontSize = 10
        milestoneLabel.fontColor = ArcadeStyle.Color.textMuted
        milestoneLabel.horizontalAlignmentMode = .center
        milestoneLabel.verticalAlignmentMode = .center
        milestoneLabel.zPosition = 3
        milestoneLabel.numberOfLines = 2
        milestoneLabel.lineBreakMode = .byWordWrapping
        cardNode.addChild(milestoneLabel)

        previewNode.zPosition = 3
        cardNode.addChild(previewNode)

        continueButton.zPosition = 4
        cardNode.addChild(continueButton)

        layout(in: size, safeTop: safeTop, safeBottom: safeBottom)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func layout(in size: CGSize, safeTop: CGFloat, safeBottom: CGFloat) {
        dimNode.size = size
        dimNode.position = .zero

        let cardWidth = min(max(300, size.width - 28), 360)
        let cardHeight: CGFloat = 344
        let cardSize = CGSize(width: cardWidth, height: cardHeight)
        cardNode.texture = TextureFactory.shared.cardTexture(size: cardSize, style: .overlay)
        cardNode.size = cardSize

        let desiredY: CGFloat = 0
        let minY = safeBottom + cardHeight / 2 + 18
        let maxY = safeTop - cardHeight / 2 - 18
        let cardY = min(max(desiredY, minY), maxY)
        cardNode.position = snap(CGPoint(x: 0, y: cardY))

        accentBand.size = snapSize(CGSize(width: cardSize.width * 0.78, height: 28))
        accentBand.position = snap(CGPoint(x: 0, y: cardSize.height / 2 - 34))

        titleLabel.position = snap(CGPoint(x: 0, y: cardSize.height / 2 - 34))
        itemLabel.position = snap(CGPoint(x: 0, y: cardSize.height / 2 - 84))
        detailLabel.position = snap(CGPoint(x: 0, y: cardSize.height / 2 - 126))
        milestoneLabel.position = snap(CGPoint(x: 0, y: cardSize.height / 2 - 148))
        itemLabel.preferredMaxLayoutWidth = cardSize.width * 0.8
        detailLabel.preferredMaxLayoutWidth = cardSize.width * 0.82
        milestoneLabel.preferredMaxLayoutWidth = cardSize.width * 0.82

        previewNode.position = snap(CGPoint(x: 0, y: -6))
        rebuildPreview()

        let buttonSize = snapSize(CGSize(width: min(ArcadeStyle.Metric.buttonSize.width, cardSize.width - 36), height: 52))
        continueButton.size = buttonSize
        continueButton.position = snap(CGPoint(x: 0, y: -cardSize.height / 2 + 40))
    }

    func button(at point: CGPoint, in scene: SKScene) -> ArcadeButtonNode? {
        let localPoint: CGPoint
        if let camera = scene.camera, inParentHierarchy(camera) {
            let cameraPoint = camera.convert(point, from: scene)
            localPoint = convert(cameraPoint, from: camera)
        } else {
            localPoint = convert(point, from: scene)
        }
        let buttonPoint = continueButton.convert(localPoint, from: self)
        return continueButton.contains(buttonPoint) ? continueButton : nil
    }

    func handleTap(button: ArcadeButtonNode) {
        if button === continueButton {
            continueButton.onTap?()
        }
    }

    private func rebuildPreview() {
        previewNode.removeAllChildren()
        if reward.milestoneLevel >= 30 {
            milestoneLabel.text = "STORY MODE COMPLETE · PRESTIGE COSMETIC UNLOCKED"
        } else {
            let nextChapter = storyChapterDescriptor(for: reward.milestoneLevel + 1)
            milestoneLabel.text = "NEXT SECTOR · \(nextChapter.title)"
        }
        switch reward.item {
        case let .player(skin):
            let sprite = SKSpriteNode(texture: TextureFactory.shared.playerTexture(size: CGSize(width: 56, height: 56)))
            CosmeticRenderer.applyPlayerSkin(skin, to: sprite, displayScale: TextureFactory.shared.displayScale)
            previewNode.addChild(sprite)
        case let .trail(style):
            let sprite = SKSpriteNode(texture: TextureFactory.shared.playerTexture(size: CGSize(width: 44, height: 44)))
            CosmeticRenderer.applyPlayerSkin(CosmeticsStore.shared.selectedPlayerSkin, to: sprite, displayScale: TextureFactory.shared.displayScale)
            sprite.position = CGPoint(x: 10, y: 0)
            previewNode.addChild(sprite)
            for index in 0..<5 {
                let dot = SKSpriteNode(texture: TextureFactory.shared.trailParticleTexture(size: CGSize(width: 10, height: 10), style: style))
                dot.position = CGPoint(x: -28 - CGFloat(index) * 10, y: CGFloat(index.isMultiple(of: 2) ? 4 : -4))
                dot.alpha = 0.85 - CGFloat(index) * 0.12
                dot.blendMode = .add
                previewNode.addChild(dot)
            }
        case let .win(style):
            let goal = SKSpriteNode(texture: TextureFactory.shared.exitTexture(size: CGSize(width: 44, height: 44)))
            previewNode.addChild(goal)
            if style == .lightBeamFinish {
                let beam = SKSpriteNode(color: reward.item.accentColor.withAlphaComponent(0.38), size: CGSize(width: 18, height: 70))
                beam.position = CGPoint(x: 0, y: 8)
                beam.blendMode = .add
                previewNode.addChild(beam)
            } else {
                let ring = SKShapeNode(circleOfRadius: 26)
                ring.strokeColor = reward.item.accentColor
                ring.lineWidth = 2.5
                ring.glowWidth = 8
                ring.fillColor = .clear
                previewNode.addChild(ring)
            }
        case let .teleporter(style):
            let portal = SKSpriteNode(texture: TextureFactory.shared.teleporterTexture(size: CGSize(width: 56, height: 56), style: style, accentColor: reward.item.accentColor))
            CosmeticRenderer.configureTeleporterNode(portal, key: "A", skin: style, tileSize: 40, accentColor: reward.item.accentColor)
            previewNode.addChild(portal)
        }
    }

    private func snap(_ point: CGPoint) -> CGPoint {
        CGPoint(x: round(point.x), y: round(point.y))
    }

    private func snapSize(_ size: CGSize) -> CGSize {
        CGSize(width: round(size.width), height: round(size.height))
    }
}
