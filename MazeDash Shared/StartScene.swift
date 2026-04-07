import SpriteKit

#if os(iOS) || os(tvOS)
import UIKit

final class StartScene: SKScene {
    private struct Metric {
        static let sidePadding: CGFloat = 20
        static let topMargin: CGFloat = 14
        static let buttonSpacing: CGFloat = 12
        static let statSpacing: CGFloat = 10
        static let baseBackgroundAlpha: CGFloat = 1.0
        static let vignetteAlpha: CGFloat = 0.25
        static let energyFieldAlpha: CGFloat = 0.16
        static let energyAccentAlpha: CGFloat = 0.07
        static let gridAlpha: CGFloat = 0.07
        static let gridSpeed: CGFloat = 8.0
        static let farParticleCount = 40
        static let mediumParticleCount = 18
        static let nearParticleCount = 7
        static let floatingAccentCount = 14
        static let sparkleCount = 10
        static let foregroundCapsuleCount = 3
        static let foregroundShardCount = 5
        static let farParticleSpeed: ClosedRange<CGFloat> = 4...8
        static let mediumParticleSpeed: ClosedRange<CGFloat> = 8...14
        static let nearParticleSpeed: ClosedRange<CGFloat> = 14...20
    }

    private let cameraNode = SKCameraNode()
    private let backgroundNode = SKSpriteNode()
    private let depthGradientNode = SKSpriteNode()
    private let energyFieldNode = SKSpriteNode()
    private let ambientGlowLeft = SKSpriteNode(color: ArcadeStyle.Color.accentCyan.withAlphaComponent(0.08), size: .zero)
    private let ambientGlowRight = SKSpriteNode(color: ArcadeStyle.Color.accentMagenta.withAlphaComponent(0.07), size: .zero)
    private let deepParticleNode = SKNode()
    private let accentParticleNode = SKNode()
    private let ambientMazeNode = SKNode()
    private let ambientRouteNode = SKNode()
    private let floatingAccentNode = SKNode()
    private let sparkleNode = SKNode()
    private let foregroundMotionNode = SKNode()
    private let sweepNode = SKSpriteNode(color: .white, size: .zero)
    private let sweepNodeSecondary = SKSpriteNode(color: .white, size: .zero)
    private let sweepNodeTertiary = SKSpriteNode(color: .white, size: .zero)
    private let vignetteNode = SKSpriteNode(color: .black, size: .zero)
    private let gridNode = SKSpriteNode()
    private let gridNodeSecondary = SKSpriteNode()
    private let particleNode = SKNode()
    private let contentNode = SKNode()
    private let utilityContainer = SKNode()

    private let titleLabel = SKLabelNode(fontNamed: ArcadeFont.title)
    private let subtitleLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let heroCard = SKSpriteNode()
    private let heroTrackNode = SKShapeNode()
    private let heroTrackGlowNode = SKShapeNode()
    private let heroBlock = SKSpriteNode()
    private let heroExit = SKSpriteNode()
    private let heroOrb = SKSpriteNode()
    private let heroCaptionLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let heroValueLabel = SKLabelNode(fontNamed: ArcadeFont.digits)
    private let heroMetaLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let heroFooterLabel = SKLabelNode(fontNamed: ArcadeFont.body)

    private let statContainer = SKNode()
    private var statCards: [SKSpriteNode] = []
    private var statTitles: [SKLabelNode] = []
    private var statTitleShadows: [SKLabelNode] = []
    private var statValues: [SKLabelNode] = []
    private var statValueShadows: [SKLabelNode] = []
    private let infoLabel = SKLabelNode(fontNamed: ArcadeFont.body)

    private let buttonContainer = SKNode()
    private let continueButton = ArcadeButtonNode(text: "CONTINUE", size: CGSize(width: 280, height: 58))
    private let continueDetailLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let challengeButton = ArcadeButtonNode(text: "TIME CHALLENGE", size: CGSize(width: 280, height: 56))
    private let challengeDetailLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let dailyButton = ArcadeButtonNode(text: "DAILY", size: CGSize(width: 132, height: 44))
    private let levelsButton = ArcadeButtonNode(text: "LEVELS", size: CGSize(width: 136, height: 54))
    private let settingsButton = ArcadeButtonNode(text: "SETTINGS", size: CGSize(width: 136, height: 54))
    private let shopButton = ArcadeButtonNode(text: "SHOP", size: CGSize(width: 112, height: 44))
    private let challengeIconNode = StartScene.makeClockIcon()
    private let continueIconNode = StartScene.makePlayIcon()
    private let settingsIconNode = StartScene.makeGearIcon()
    private let dailyIconNode = StartScene.makeDailyCalendarIcon()
    private let shopIconNode = StartScene.makeCoinIcon()

    private var activeButton: ArcadeButtonNode?
    private var touchStartPoint: CGPoint?
    private var safeInsets: UIEdgeInsets = .zero
    private var isTransitioning = false
    private var settingsOverlay: SettingsOverlayNode?
    private var dailyPromptOverlay: DailyPromptOverlayNode?
    private var activeVolumeSlider: VolumeSliderNode?
    private var didApplyScreenshotTarget = false

    override func didMove(to view: SKView) {
        backgroundColor = .black
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        updateSafeInsets()
        SoundFX.syncAudioState()
        MazeCache.shared.prewarmNormalLevels()
        let continueLevelId = ProgressStore.shared.continueLevelId
        MazeCache.shared.prefetch(levelIndex: continueLevelId - 1, config: makeLevelConfig(levelIndex: continueLevelId))
        let nextPlayableLevelId = ProgressStore.shared.nextPlayableLevelId
        MazeCache.shared.prefetch(levelIndex: nextPlayableLevelId - 1, config: makeLevelConfig(levelIndex: nextPlayableLevelId))
        let dailyDescriptor = DailyChallengeStore.shared.currentDescriptor()
        MazeCache.shared.prefetch(levelIndex: dailyDescriptor.cacheLevelIndex, config: dailyDescriptor.config)
        buildScene()
        refreshContent()
        layoutScene()
        if applyScreenshotTargetIfNeeded() {
            return
        }
        animateEntrance()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.updateSafeInsets()
            self.layoutScene()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { [weak self] in
            self?.presentDailyPromptIfNeeded()
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        updateSafeInsets()
        refreshBackground()
        setupGrid()
        configureBackgroundMotion()
        layoutScene()
    }

    private func buildScene() {
        removeAllChildren()

        camera = cameraNode
        addChild(cameraNode)

        cameraNode.addChild(backgroundNode)
        cameraNode.addChild(gridNode)
        cameraNode.addChild(gridNodeSecondary)
        cameraNode.addChild(sweepNode)
        cameraNode.addChild(sweepNodeSecondary)
        cameraNode.addChild(sweepNodeTertiary)
        cameraNode.addChild(ambientMazeNode)
        cameraNode.addChild(ambientRouteNode)
        cameraNode.addChild(floatingAccentNode)
        cameraNode.addChild(deepParticleNode)
        cameraNode.addChild(accentParticleNode)
        cameraNode.addChild(energyFieldNode)
        cameraNode.addChild(depthGradientNode)
        cameraNode.addChild(ambientGlowLeft)
        cameraNode.addChild(ambientGlowRight)
        cameraNode.addChild(sparkleNode)
        cameraNode.addChild(foregroundMotionNode)
        cameraNode.addChild(vignetteNode)
        cameraNode.addChild(particleNode)
        cameraNode.addChild(contentNode)

        setupBackground()
        setupGrid()
        setupTitle()
        setupButtons()
        setupInfoLabel()
        setupParticles()
    }

    private func applyScreenshotTargetIfNeeded() -> Bool {
        guard !didApplyScreenshotTarget else { return false }
        guard let target = ProcessInfo.processInfo.environment["MAZEDASH_SCREENSHOT_TARGET"]?.lowercased() else {
            return false
        }

        didApplyScreenshotTarget = true
        let transition = SKTransition.crossFade(withDuration: 0)

        switch target {
        case "menu":
            return true
        case "daily":
            guard let view else { return true }
            let scene = DailyChallengeScene(size: size)
            scene.scaleMode = .resizeFill
            view.presentScene(scene, transition: transition)
            return true
        case "levels":
            guard let view else { return true }
            let scene = LevelSelectScene(size: size)
            scene.scaleMode = .resizeFill
            view.presentScene(scene, transition: transition)
            return true
        default:
            return false
        }
    }

    private func setupBackground() {
        backgroundNode.zPosition = -220
        gridNode.zPosition = -210
        gridNodeSecondary.zPosition = -210
        sweepNode.zPosition = -206
        sweepNodeSecondary.zPosition = -205
        sweepNodeTertiary.zPosition = -204
        ambientMazeNode.zPosition = -203
        ambientRouteNode.zPosition = -202
        floatingAccentNode.zPosition = -201
        deepParticleNode.zPosition = -200
        accentParticleNode.zPosition = -199
        energyFieldNode.zPosition = -198
        depthGradientNode.zPosition = -197
        ambientGlowLeft.zPosition = -196
        ambientGlowRight.zPosition = -196
        sparkleNode.zPosition = -195
        foregroundMotionNode.zPosition = -194
        particleNode.zPosition = -193
        vignetteNode.zPosition = -190

        depthGradientNode.blendMode = .add
        energyFieldNode.blendMode = .add
        sweepNode.blendMode = .add
        sweepNodeSecondary.blendMode = .add
        sweepNodeTertiary.blendMode = .add
        ambientGlowLeft.blendMode = .add
        ambientGlowRight.blendMode = .add

        refreshBackground()
        refreshVignette()
    }

    private func refreshBackground() {
        backgroundNode.texture = Self.makeMenuBaseTexture(
            size: size,
            top: SKColor(hex: 0x070B14),
            middle: SKColor(hex: 0x090F1C),
            bottom: SKColor(hex: 0x05070D)
        )
        backgroundNode.size = size
        backgroundNode.position = .zero
        backgroundNode.alpha = Metric.baseBackgroundAlpha

        let coreWidth = size.width * 0.60
        let coreHeight = size.height * 0.24

        energyFieldNode.texture = Self.makeRadialGlowTexture(
            size: CGSize(width: coreWidth, height: coreHeight),
            color: SKColor(hex: 0x00D4FF),
            innerAlpha: 0.92,
            outerAlpha: 0.0
        )
        energyFieldNode.size = snapSize(CGSize(width: coreWidth, height: coreHeight))
        energyFieldNode.alpha = Metric.energyFieldAlpha

        depthGradientNode.texture = Self.makeRadialGlowTexture(
            size: CGSize(width: coreWidth * 0.76, height: coreHeight * 0.88),
            color: SKColor(hex: 0xFF2D9A),
            innerAlpha: 0.78,
            outerAlpha: 0.0
        )
        depthGradientNode.size = snapSize(CGSize(width: coreWidth * 0.76, height: coreHeight * 0.88))
        depthGradientNode.alpha = Metric.energyAccentAlpha

        let sideGlowSize = snapSize(CGSize(width: size.width * 0.32, height: size.height * 0.18))
        ambientGlowLeft.texture = Self.makeRadialGlowTexture(
            size: sideGlowSize,
            color: SKColor(hex: 0x00D4FF),
            innerAlpha: 0.52,
            outerAlpha: 0.0
        )
        ambientGlowLeft.size = sideGlowSize
        ambientGlowLeft.alpha = 0.09

        ambientGlowRight.texture = Self.makeRadialGlowTexture(
            size: sideGlowSize,
            color: SKColor(hex: 0xFF2D9A),
            innerAlpha: 0.46,
            outerAlpha: 0.0
        )
        ambientGlowRight.size = sideGlowSize
        ambientGlowRight.alpha = 0.07

        refreshVignette()
        layoutBackgroundMotion()
    }

    private func refreshVignette() {
        vignetteNode.texture = Self.makeVignetteTexture(size: size, edgeAlpha: Metric.vignetteAlpha)
        vignetteNode.size = size
        vignetteNode.position = .zero
        vignetteNode.alpha = 1.0
    }

    private func setupGrid() {
        let screenScale = resolvedScreenScale()
        let gridSize = snapSize(CGSize(width: size.width * 1.18, height: size.height * 1.18))
        let gridTexture = Self.makeGridTexture(
            size: gridSize,
            spacing: CGSize(width: 34, height: 34),
            lineWidth: 1.0 / screenScale,
            color: SKColor(hex: 0x00D4FF),
            alpha: Metric.gridAlpha,
            scale: screenScale
        )

        gridNode.texture = gridTexture
        gridNode.size = gridSize
        gridNode.position = .zero
        gridNode.alpha = 1.0
        gridNode.blendMode = .alpha
        gridNode.removeAllActions()

        gridNodeSecondary.texture = gridTexture
        gridNodeSecondary.size = gridSize
        gridNodeSecondary.alpha = 1.0
        gridNodeSecondary.blendMode = .alpha
        gridNodeSecondary.removeAllActions()
    }

    private func setupTitle() {
        titleLabel.text = "MazeDash"
        titleLabel.fontSize = ArcadeStyle.FontSize.menuTitle
        titleLabel.fontColor = ArcadeStyle.Color.textPrimary
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode = .center
        titleLabel.alpha = 0
        titleLabel.zPosition = 20
        contentNode.addChild(titleLabel)

        subtitleLabel.text = "Swipe. Flow. Escape."
        subtitleLabel.fontSize = ArcadeStyle.FontSize.menuSubtitle
        subtitleLabel.fontColor = ArcadeStyle.Color.textSecondary
        subtitleLabel.horizontalAlignmentMode = .center
        subtitleLabel.verticalAlignmentMode = .center
        subtitleLabel.alpha = 0
        subtitleLabel.zPosition = 20
        contentNode.addChild(subtitleLabel)
    }

    private func setupHero() {
        heroCard.zPosition = 15
        contentNode.addChild(heroCard)

        heroTrackGlowNode.strokeColor = ArcadeStyle.Color.accentCyan.withAlphaComponent(0.22)
        heroTrackGlowNode.lineWidth = 10
        heroTrackGlowNode.lineCap = .round
        heroTrackGlowNode.glowWidth = 0
        heroTrackGlowNode.zPosition = 0.8
        heroCard.addChild(heroTrackGlowNode)

        heroTrackNode.strokeColor = ArcadeStyle.Color.accentCyan.withAlphaComponent(0.95)
        heroTrackNode.lineWidth = 3
        heroTrackNode.lineCap = .round
        heroTrackNode.zPosition = 1
        heroCard.addChild(heroTrackNode)

        heroBlock.texture = TextureFactory.shared.playerTexture(size: CGSize(width: 42, height: 42))
        applySelectedSkin(to: heroBlock)
        heroBlock.zPosition = 3
        heroCard.addChild(heroBlock)

        heroExit.texture = TextureFactory.shared.exitTexture(size: CGSize(width: 44, height: 44))
        heroExit.zPosition = 2
        heroCard.addChild(heroExit)

        heroOrb.texture = TextureFactory.shared.orbTexture(size: CGSize(width: 18, height: 18))
        heroOrb.zPosition = 2
        heroCard.addChild(heroOrb)

        heroCaptionLabel.fontSize = 11
        heroCaptionLabel.fontColor = ArcadeStyle.Color.textPrimary.withAlphaComponent(0.82)
        heroCaptionLabel.horizontalAlignmentMode = .left
        heroCaptionLabel.verticalAlignmentMode = .center
        heroCaptionLabel.zPosition = 6
        heroCard.addChild(heroCaptionLabel)

        heroValueLabel.fontSize = 16
        heroValueLabel.fontColor = ArcadeStyle.Color.textPrimary
        heroValueLabel.horizontalAlignmentMode = .left
        heroValueLabel.verticalAlignmentMode = .center
        heroValueLabel.zPosition = 6
        heroCard.addChild(heroValueLabel)

        heroMetaLabel.fontSize = 11
        heroMetaLabel.fontColor = ArcadeStyle.Color.textPrimary.withAlphaComponent(0.76)
        heroMetaLabel.horizontalAlignmentMode = .left
        heroMetaLabel.verticalAlignmentMode = .center
        heroMetaLabel.zPosition = 6
        heroCard.addChild(heroMetaLabel)

        heroFooterLabel.fontSize = 11
        heroFooterLabel.fontColor = ArcadeStyle.Color.textPrimary.withAlphaComponent(0.64)
        heroFooterLabel.horizontalAlignmentMode = .left
        heroFooterLabel.verticalAlignmentMode = .center
        heroFooterLabel.zPosition = 6
        heroCard.addChild(heroFooterLabel)
    }

    private func setupStats() {
        statContainer.zPosition = 18
        contentNode.addChild(statContainer)

        let titles = ["CLEARED", "STARS", "COINS", "BEST"]
        for title in titles {
            let card = SKSpriteNode()
            let titleShadow = SKLabelNode(fontNamed: ArcadeFont.body)
            let titleLabel = SKLabelNode(fontNamed: ArcadeFont.body)
            let valueShadow = SKLabelNode(fontNamed: ArcadeFont.digits)
            let valueLabel = SKLabelNode(fontNamed: ArcadeFont.digits)

            titleShadow.text = title
            titleShadow.fontSize = 11
            titleShadow.fontColor = SKColor(white: 0.0, alpha: 0.62)
            titleShadow.horizontalAlignmentMode = .center
            titleShadow.verticalAlignmentMode = .center
            titleShadow.zPosition = 4

            titleLabel.text = title
            titleLabel.fontSize = 11
            titleLabel.fontColor = ArcadeStyle.Color.textSecondary
            titleLabel.horizontalAlignmentMode = .center
            titleLabel.verticalAlignmentMode = .center
            titleLabel.zPosition = 5

            valueShadow.fontSize = 18
            valueShadow.fontColor = SKColor(white: 0.0, alpha: 0.74)
            valueShadow.horizontalAlignmentMode = .center
            valueShadow.verticalAlignmentMode = .center
            valueShadow.zPosition = 4

            valueLabel.fontSize = 18
            valueLabel.fontColor = ArcadeStyle.Color.textPrimary
            valueLabel.horizontalAlignmentMode = .center
            valueLabel.verticalAlignmentMode = .center
            valueLabel.zPosition = 5

            card.addChild(titleShadow)
            card.addChild(titleLabel)
            card.addChild(valueShadow)
            card.addChild(valueLabel)
            statContainer.addChild(card)

            statCards.append(card)
            statTitles.append(titleLabel)
            statTitleShadows.append(titleShadow)
            statValues.append(valueLabel)
            statValueShadows.append(valueShadow)
        }
    }

    private func setupButtons() {
        buttonContainer.zPosition = 25
        utilityContainer.zPosition = 28
        contentNode.addChild(buttonContainer)
        contentNode.addChild(utilityContainer)

        challengeButton.setAccentColor(ArcadeStyle.Color.accentCyan.withAlphaComponent(0.98))
        continueButton.setAccentColor(ArcadeStyle.Color.accentYellow.withAlphaComponent(0.98))
        levelsButton.setAccentColor(ArcadeStyle.Color.accentCyan.withAlphaComponent(0.82))
        settingsButton.setAccentColor(ArcadeStyle.Color.accentMagenta.withAlphaComponent(0.9))
        dailyButton.setAccentColor(ArcadeStyle.Color.accentMagenta.withAlphaComponent(0.94))
        shopButton.setAccentColor(ArcadeStyle.Color.accentYellow.withAlphaComponent(0.94))

        continueDetailLabel.fontSize = 10
        continueDetailLabel.fontColor = ArcadeStyle.Color.textSecondary
        continueDetailLabel.horizontalAlignmentMode = .left
        continueDetailLabel.verticalAlignmentMode = .center
        continueDetailLabel.zPosition = 3.2
        continueButton.addChild(continueDetailLabel)

        challengeDetailLabel.fontSize = 10
        challengeDetailLabel.fontColor = ArcadeStyle.Color.textSecondary
        challengeDetailLabel.horizontalAlignmentMode = .left
        challengeDetailLabel.verticalAlignmentMode = .center
        challengeDetailLabel.zPosition = 3.2
        challengeButton.addChild(challengeDetailLabel)

        [challengeIconNode, continueIconNode, settingsIconNode, dailyIconNode, shopIconNode].forEach { node in
            node.removeFromParent()
        }
        challengeButton.addChild(challengeIconNode)
        continueButton.addChild(continueIconNode)
        settingsButton.addChild(settingsIconNode)
        dailyButton.addChild(dailyIconNode)
        shopButton.addChild(shopIconNode)

        continueButton.onTap = { [weak self] in
            self?.presentGame(levelId: ProgressStore.shared.continueLevelId)
        }
        challengeButton.onTap = { [weak self] in
            self?.presentChallengeSelect()
        }
        dailyButton.onTap = { [weak self] in
            self?.presentDailyChallengeSelect()
        }
        levelsButton.onTap = { [weak self] in
            self?.presentLevelSelect()
        }
        settingsButton.onTap = { [weak self] in
            self?.presentSettingsOverlay()
        }
        shopButton.onTap = { [weak self] in
            self?.presentShop()
        }

        buttonContainer.addChild(challengeButton)
        buttonContainer.addChild(continueButton)
        buttonContainer.addChild(levelsButton)
        buttonContainer.addChild(settingsButton)
        utilityContainer.addChild(dailyButton)
        utilityContainer.addChild(shopButton)
    }

    private func setupInfoLabel() {
        infoLabel.fontSize = 11
        infoLabel.fontColor = ArcadeStyle.Color.textPrimary.withAlphaComponent(0.78)
        infoLabel.horizontalAlignmentMode = .center
        infoLabel.verticalAlignmentMode = .center
        infoLabel.zPosition = 30
        contentNode.addChild(infoLabel)
    }

    private func setupParticles() {
        configureBackgroundMotion()
    }

    private func configureBackgroundMotion() {
        ambientMazeNode.removeAllActions()
        ambientMazeNode.removeAllChildren()
        ambientRouteNode.removeAllActions()
        ambientRouteNode.removeAllChildren()
        floatingAccentNode.removeAllActions()
        floatingAccentNode.removeAllChildren()
        sparkleNode.removeAllActions()
        sparkleNode.removeAllChildren()
        foregroundMotionNode.removeAllActions()
        foregroundMotionNode.removeAllChildren()
        deepParticleNode.removeAllChildren()
        accentParticleNode.removeAllChildren()
        particleNode.removeAllChildren()

        for _ in 0..<Metric.farParticleCount {
            spawnDeepParticle()
        }
        for _ in 0..<Metric.mediumParticleCount {
            spawnAccentParticle()
        }
        for _ in 0..<Metric.nearParticleCount {
            spawnParticle()
        }
        for _ in 0..<Metric.sparkleCount {
            spawnSparkle()
        }
        for _ in 0..<Metric.foregroundCapsuleCount {
            spawnForegroundFlyby()
        }
        for _ in 0..<Metric.foregroundShardCount {
            spawnForegroundShard()
        }

        configureAmbientMazeWorld()
        configureFloatingAccentLayer()

        ambientMazeNode.run(.repeatForever(.sequence([
            .moveBy(x: 8, y: -10, duration: 10.0),
            .moveBy(x: -8, y: 10, duration: 10.0)
        ])), withKey: "ambientMazeDrift")
        ambientRouteNode.run(.repeatForever(.sequence([
            .moveBy(x: 6, y: -8, duration: 9.0),
            .moveBy(x: -6, y: 8, duration: 9.0)
        ])), withKey: "ambientRouteDrift")
        floatingAccentNode.run(.repeatForever(.sequence([
            .moveBy(x: -5, y: 7, duration: 11.0),
            .moveBy(x: 5, y: -7, duration: 11.0)
        ])), withKey: "floatingAccentDrift")

        backgroundNode.removeAllActions()
        depthGradientNode.removeAllActions()
        energyFieldNode.removeAllActions()
        ambientGlowLeft.removeAllActions()
        ambientGlowRight.removeAllActions()
        gridNode.removeAllActions()
        gridNodeSecondary.removeAllActions()
        sweepNode.removeAllActions()
        sweepNodeSecondary.removeAllActions()
        sweepNodeTertiary.removeAllActions()

        let energyPulse = SKAction.sequence([
            .group([
                .fadeAlpha(to: Metric.energyFieldAlpha * 1.08, duration: 3.1),
                .scale(to: 1.06, duration: 3.1)
            ]),
            .group([
                .fadeAlpha(to: Metric.energyFieldAlpha * 0.92, duration: 3.1),
                .scale(to: 1.0, duration: 3.1)
            ])
        ])
        energyFieldNode.setScale(1.0)
        energyFieldNode.run(.repeatForever(energyPulse), withKey: "energyPulse")
        depthGradientNode.setScale(1.0)
        depthGradientNode.run(.repeatForever(.sequence([
            .group([
                .fadeAlpha(to: Metric.energyAccentAlpha * 1.12, duration: 3.4),
                .scale(to: 1.04, duration: 3.4)
            ]),
            .group([
                .fadeAlpha(to: Metric.energyAccentAlpha * 0.9, duration: 3.2),
                .scale(to: 1.0, duration: 3.2)
            ])
        ])), withKey: "accentPulse")

        ambientGlowLeft.setScale(1.0)
        ambientGlowLeft.run(.repeatForever(.sequence([
            .group([
                .fadeAlpha(to: 0.12, duration: 4.2),
                .scale(to: 1.08, duration: 4.2)
            ]),
            .group([
                .fadeAlpha(to: 0.07, duration: 4.8),
                .scale(to: 1.0, duration: 4.8)
            ])
        ])), withKey: "sideGlowPulse")

        ambientGlowRight.setScale(1.0)
        ambientGlowRight.run(.repeatForever(.sequence([
            .group([
                .fadeAlpha(to: 0.10, duration: 4.8),
                .scale(to: 1.06, duration: 4.8)
            ]),
            .group([
                .fadeAlpha(to: 0.06, duration: 5.0),
                .scale(to: 1.0, duration: 5.0)
            ])
        ])), withKey: "sideGlowPulse")

        let gridTravel = max(gridNode.size.height, 1)
        let gridDuration = Double(gridTravel / Metric.gridSpeed)
        let gridDrift = SKAction.repeatForever(.sequence([
            .moveBy(x: 0, y: -gridTravel, duration: gridDuration),
            .moveBy(x: 0, y: gridTravel, duration: 0)
        ]))
        gridNode.run(gridDrift, withKey: "gridDrift")
        gridNodeSecondary.run(gridDrift, withKey: "gridDrift")

        configureAmbientStreak(
            sweepNode,
            tint: SKColor(hex: 0x00D4FF),
            baseAlpha: 0.055,
            drift: CGPoint(x: 10, y: -12),
            duration: 19.0
        )
        configureAmbientStreak(
            sweepNodeSecondary,
            tint: SKColor(hex: 0xFF2D9A),
            baseAlpha: 0.045,
            drift: CGPoint(x: -8, y: 10),
            duration: 21.0
        )
        configureAmbientStreak(
            sweepNodeTertiary,
            tint: SKColor(hex: 0x00D4FF),
            baseAlpha: 0.038,
            drift: CGPoint(x: 6, y: -8),
            duration: 24.0
        )
    }

    private func layoutBackgroundMotion() {
        let gridHeight = gridNode.size.height
        gridNode.position = CGPoint(x: 0, y: 0)
        gridNodeSecondary.position = CGPoint(x: 0, y: gridHeight)

        layoutBackgroundPresentation()
    }

    private func configureAmbientStreak(
        _ node: SKSpriteNode,
        tint: SKColor,
        baseAlpha: CGFloat,
        drift: CGPoint,
        duration: TimeInterval
    ) {
        node.removeAllActions()
        node.alpha = baseAlpha
        node.run(.repeatForever(.sequence([
            .group([
                .moveBy(x: drift.x, y: drift.y, duration: duration),
                .fadeAlpha(to: baseAlpha * 1.1, duration: duration)
            ]),
            .group([
                .moveBy(x: -drift.x, y: -drift.y, duration: duration),
                .fadeAlpha(to: baseAlpha * 0.92, duration: duration)
            ])
        ])), withKey: "ambientDrift")
    }

    private func layoutBackgroundPresentation() {
        let titleCenter = snap(CGPoint(x: 0, y: titleLabel.position.y))
        let coreSize = snapSize(CGSize(width: size.width * 0.60, height: size.height * 0.24))
        energyFieldNode.size = coreSize
        energyFieldNode.position = titleCenter

        depthGradientNode.size = snapSize(CGSize(width: coreSize.width * 0.76, height: coreSize.height * 0.88))
        depthGradientNode.position = snap(CGPoint(x: 12, y: titleCenter.y - 4))

        ambientGlowLeft.position = snap(CGPoint(x: -size.width * 0.22, y: titleCenter.y - 14))
        ambientGlowRight.position = snap(CGPoint(x: size.width * 0.24, y: titleCenter.y - 8))

        let streakHeight = size.height * 0.74
        sweepNode.texture = Self.makeAmbientStreakTexture(
            size: CGSize(width: max(56, size.width * 0.14), height: streakHeight),
            tint: SKColor(hex: 0x00D4FF)
        )
        sweepNode.size = snapSize(CGSize(width: max(56, size.width * 0.14), height: streakHeight))
        sweepNode.position = snap(CGPoint(x: -size.width * 0.34, y: -size.height * 0.28))
        sweepNode.zRotation = -.pi / 6.3

        sweepNodeSecondary.texture = Self.makeAmbientStreakTexture(
            size: CGSize(width: max(48, size.width * 0.12), height: size.height * 0.66),
            tint: SKColor(hex: 0xFF2D9A)
        )
        sweepNodeSecondary.size = snapSize(CGSize(width: max(48, size.width * 0.12), height: size.height * 0.66))
        sweepNodeSecondary.position = snap(CGPoint(x: size.width * 0.29, y: -size.height * 0.36))
        sweepNodeSecondary.zRotation = -.pi / 5.6

        sweepNodeTertiary.texture = Self.makeAmbientStreakTexture(
            size: CGSize(width: max(44, size.width * 0.10), height: size.height * 0.58),
            tint: SKColor(hex: 0x00D4FF)
        )
        sweepNodeTertiary.size = snapSize(CGSize(width: max(44, size.width * 0.10), height: size.height * 0.58))
        sweepNodeTertiary.position = snap(CGPoint(x: 0, y: -size.height * 0.44))
        sweepNodeTertiary.zRotation = -.pi / 6.0
    }

    private func configureAmbientMazeWorld() {
        let fragments: [(CGRect, SKColor, Double)] = [
            (
                CGRect(
                    x: -size.width * 0.43,
                    y: -size.height * 0.34,
                    width: size.width * 0.32,
                    height: size.height * 0.18
                ),
                ArcadeStyle.Color.accentCyan,
                0.0
            ),
            (
                CGRect(
                    x: size.width * 0.08,
                    y: -size.height * 0.37,
                    width: size.width * 0.34,
                    height: size.height * 0.2
                ),
                ArcadeStyle.Color.accentMagenta,
                0.9
            ),
            (
                CGRect(
                    x: -size.width * 0.12,
                    y: -size.height * 0.47,
                    width: size.width * 0.26,
                    height: size.height * 0.14
                ),
                ArcadeStyle.Color.accentYellow,
                1.6
            ),
            (
                CGRect(
                    x: -size.width * 0.02,
                    y: -size.height * 0.28,
                    width: size.width * 0.22,
                    height: size.height * 0.12
                ),
                ArcadeStyle.Color.accentCyan,
                2.2
            ),
            (
                CGRect(
                    x: -size.width * 0.44,
                    y: size.height * 0.12,
                    width: size.width * 0.24,
                    height: size.height * 0.13
                ),
                ArcadeStyle.Color.accentCyan,
                0.6
            ),
            (
                CGRect(
                    x: size.width * 0.20,
                    y: size.height * 0.10,
                    width: size.width * 0.24,
                    height: size.height * 0.14
                ),
                ArcadeStyle.Color.accentMagenta,
                1.4
            )
        ]

        for (rect, tint, delay) in fragments {
            addAmbientMazeFragment(in: rect, tint: tint, delay: delay)
        }

        let routeA = [
            CGPoint(x: -size.width * 0.36, y: -size.height * 0.2),
            CGPoint(x: -size.width * 0.14, y: -size.height * 0.2),
            CGPoint(x: -size.width * 0.14, y: -size.height * 0.36),
            CGPoint(x: size.width * 0.08, y: -size.height * 0.36),
            CGPoint(x: size.width * 0.08, y: -size.height * 0.24),
            CGPoint(x: size.width * 0.28, y: -size.height * 0.24)
        ]
        let routeB = [
            CGPoint(x: size.width * 0.34, y: -size.height * 0.08),
            CGPoint(x: size.width * 0.34, y: -size.height * 0.28),
            CGPoint(x: size.width * 0.18, y: -size.height * 0.28),
            CGPoint(x: size.width * 0.18, y: -size.height * 0.42),
            CGPoint(x: -size.width * 0.02, y: -size.height * 0.42)
        ]
        let routeC = [
            CGPoint(x: -size.width * 0.42, y: -size.height * 0.46),
            CGPoint(x: -size.width * 0.24, y: -size.height * 0.46),
            CGPoint(x: -size.width * 0.24, y: -size.height * 0.30),
            CGPoint(x: 0, y: -size.height * 0.30),
            CGPoint(x: 0, y: -size.height * 0.16)
        ]
        let routeD = [
            CGPoint(x: -size.width * 0.44, y: size.height * 0.32),
            CGPoint(x: -size.width * 0.30, y: size.height * 0.32),
            CGPoint(x: -size.width * 0.30, y: size.height * 0.16),
            CGPoint(x: -size.width * 0.42, y: size.height * 0.16)
        ]
        let routeE = [
            CGPoint(x: size.width * 0.44, y: size.height * 0.30),
            CGPoint(x: size.width * 0.30, y: size.height * 0.30),
            CGPoint(x: size.width * 0.30, y: size.height * 0.14),
            CGPoint(x: size.width * 0.42, y: size.height * 0.14)
        ]

        addAmbientRunner(path: routeA, tint: ArcadeStyle.Color.accentCyan, delay: 0.4)
        addAmbientRunner(path: routeB, tint: ArcadeStyle.Color.accentMagenta, delay: 2.1)
        addAmbientRunner(path: routeC, tint: ArcadeStyle.Color.accentYellow, delay: 1.3)
        addAmbientRunner(path: routeD, tint: ArcadeStyle.Color.accentCyan, delay: 0.9)
        addAmbientRunner(path: routeE, tint: ArcadeStyle.Color.accentMagenta, delay: 1.7)
    }

    private func addAmbientMazeFragment(in rect: CGRect, tint: SKColor, delay: Double) {
        let glow = SKShapeNode(path: makeAmbientMazePath(in: rect))
        glow.strokeColor = tint.withAlphaComponent(0.05)
        glow.lineWidth = 7
        glow.lineCap = .round
        glow.lineJoin = .round
        glow.alpha = 0.7
        glow.zPosition = 0
        ambientMazeNode.addChild(glow)

        let shape = SKShapeNode(path: makeAmbientMazePath(in: rect))
        shape.strokeColor = tint.withAlphaComponent(0.16)
        shape.lineWidth = 1.6
        shape.lineCap = .round
        shape.lineJoin = .round
        shape.alpha = 0.9
        shape.zPosition = 1
        ambientMazeNode.addChild(shape)

        shape.run(.repeatForever(.sequence([
            .wait(forDuration: delay),
            .fadeAlpha(to: 0.52, duration: 2.8),
            .fadeAlpha(to: 0.92, duration: 3.4)
        ])), withKey: "mazeBreathe")

        glow.run(.repeatForever(.sequence([
            .wait(forDuration: delay * 0.5),
            .fadeAlpha(to: 0.36, duration: 3.2),
            .fadeAlpha(to: 0.72, duration: 3.8)
        ])), withKey: "mazeGlow")

        for point in ambientPulsePoints(in: rect) {
            let pulse = SKSpriteNode(color: tint.withAlphaComponent(0.45), size: CGSize(width: 5, height: 5))
            pulse.position = point
            pulse.alpha = 0
            pulse.blendMode = .add
            ambientMazeNode.addChild(pulse)
            pulse.run(.repeatForever(.sequence([
                .wait(forDuration: delay + Double.random(in: 0.4...1.6)),
                .group([
                    .fadeAlpha(to: 0.42, duration: 0.18),
                    .scale(to: 1.6, duration: 0.18)
                ]),
                .group([
                    .fadeOut(withDuration: 0.5),
                    .scale(to: 0.9, duration: 0.5)
                ])
            ])))
        }
    }

    private func makeAmbientMazePath(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        let x0 = rect.minX
        let x1 = rect.minX + rect.width * 0.34
        let x2 = rect.minX + rect.width * 0.62
        let x3 = rect.maxX
        let y0 = rect.minY
        let y1 = rect.minY + rect.height * 0.32
        let y2 = rect.minY + rect.height * 0.66
        let y3 = rect.maxY

        path.move(to: CGPoint(x: x0, y: y1))
        path.addLine(to: CGPoint(x: x1, y: y1))
        path.addLine(to: CGPoint(x: x1, y: y3))
        path.addLine(to: CGPoint(x: x2, y: y3))
        path.addLine(to: CGPoint(x: x2, y: y2))
        path.addLine(to: CGPoint(x: x3, y: y2))

        path.move(to: CGPoint(x: x0, y: y0))
        path.addLine(to: CGPoint(x: x0, y: y2))
        path.addLine(to: CGPoint(x: x2, y: y2))

        path.move(to: CGPoint(x: x1, y: y0))
        path.addLine(to: CGPoint(x: x1, y: y1))
        path.addLine(to: CGPoint(x: x3, y: y1))

        return path
    }

    private func ambientPulsePoints(in rect: CGRect) -> [CGPoint] {
        [
            CGPoint(x: rect.minX + rect.width * 0.34, y: rect.minY + rect.height * 0.32),
            CGPoint(x: rect.minX + rect.width * 0.62, y: rect.minY + rect.height * 0.66),
            CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.66)
        ]
    }

    private func addAmbientRunner(path points: [CGPoint], tint: SKColor, delay: Double) {
        guard points.count >= 2 else { return }

        let routePath = CGMutablePath()
        routePath.move(to: points[0])
        for point in points.dropFirst() {
            routePath.addLine(to: point)
        }

        let routeGlow = SKShapeNode(path: routePath)
        routeGlow.strokeColor = tint.withAlphaComponent(0.05)
        routeGlow.lineWidth = 6
        routeGlow.lineCap = .round
        routeGlow.lineJoin = .round
        routeGlow.alpha = 0.6
        routeGlow.zPosition = 0
        ambientRouteNode.addChild(routeGlow)

        let routeLine = SKShapeNode(path: routePath)
        routeLine.strokeColor = tint.withAlphaComponent(0.12)
        routeLine.lineWidth = 1.5
        routeLine.lineCap = .round
        routeLine.lineJoin = .round
        routeLine.alpha = 0.82
        routeLine.zPosition = 1
        ambientRouteNode.addChild(routeLine)

        let runner = SKSpriteNode(texture: TextureFactory.shared.playerTexture(size: CGSize(width: 18, height: 18)))
        runner.size = CGSize(width: 18, height: 18)
        applySelectedSkin(to: runner)
        runner.color = tint
        runner.colorBlendFactor = 0.28
        runner.alpha = 0.42
        runner.position = points[0]
        runner.zPosition = 3
        ambientRouteNode.addChild(runner)

        let pulse = SKSpriteNode(color: tint.withAlphaComponent(0.55), size: CGSize(width: 6, height: 6))
        pulse.alpha = 0
        pulse.blendMode = .add
        pulse.position = points[0]
        pulse.zPosition = 2
        ambientRouteNode.addChild(pulse)

        let durations = zip(points, points.dropFirst()).map { start, end in
            max(0.7, Double(hypot(end.x - start.x, end.y - start.y) / 80.0))
        }

        func runnerSequence() -> SKAction {
            var actions: [SKAction] = [.wait(forDuration: delay)]
            for (index, point) in points.dropFirst().enumerated() {
                let moveDuration = durations[index]
                actions.append(.group([
                    .move(to: point, duration: moveDuration),
                    .sequence([
                        .fadeAlpha(to: 0.46, duration: moveDuration * 0.25),
                        .fadeAlpha(to: 0.34, duration: moveDuration * 0.75)
                    ])
                ]))
            }
            actions.append(.wait(forDuration: Double.random(in: 0.6...1.2)))
            actions.append(.fadeOut(withDuration: 0.16))
            actions.append(.run {
                runner.position = points[0]
                runner.alpha = 0.42
            })
            return .sequence(actions)
        }

        func pulseSequence() -> SKAction {
            var actions: [SKAction] = [.wait(forDuration: delay + 0.18)]
            for (index, point) in points.dropFirst().enumerated() {
                let moveDuration = durations[index]
                actions.append(.group([
                    .move(to: point, duration: moveDuration),
                    .sequence([
                        .fadeAlpha(to: 0.32, duration: moveDuration * 0.2),
                        .fadeOut(withDuration: moveDuration * 0.8)
                    ]),
                    .sequence([
                        .scale(to: 1.8, duration: moveDuration * 0.22),
                        .scale(to: 0.9, duration: moveDuration * 0.78)
                    ])
                ]))
            }
            actions.append(.run {
                pulse.position = points[0]
                pulse.alpha = 0
                pulse.setScale(1.0)
            })
            actions.append(.wait(forDuration: Double.random(in: 0.8...1.4)))
            return .sequence(actions)
        }

        runner.run(.repeatForever(runnerSequence()), withKey: "ambientRunner")
        pulse.run(.repeatForever(pulseSequence()), withKey: "ambientPulse")
        routeLine.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.5, duration: 3.0),
            .fadeAlpha(to: 0.82, duration: 3.8)
        ])), withKey: "routeBreathe")
    }

    private func configureFloatingAccentLayer() {
        for index in 0..<Metric.floatingAccentCount {
            let tintOptions = [
                ArcadeStyle.Color.accentCyan,
                ArcadeStyle.Color.accentMagenta,
                ArcadeStyle.Color.accentYellow
            ]
            let tint = tintOptions[index % tintOptions.count]
            let accent: SKNode
            switch index % 4 {
            case 0:
                let sizeValue = CGFloat.random(in: 14...22)
                let frame = SKShapeNode(rectOf: CGSize(width: sizeValue, height: sizeValue), cornerRadius: 3)
                frame.strokeColor = tint.withAlphaComponent(0.24)
                frame.lineWidth = 1.0
                frame.fillColor = .clear
                accent = frame
            case 1:
                let width = CGFloat.random(in: 24...40)
                let height = CGFloat.random(in: 6...10)
                let capsule = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: height * 0.5)
                capsule.strokeColor = tint.withAlphaComponent(0.18)
                capsule.fillColor = tint.withAlphaComponent(0.06)
                capsule.lineWidth = 0.9
                accent = capsule
            case 2:
                let width = CGFloat.random(in: 18...34)
                let line = SKShapeNode(rectOf: CGSize(width: width, height: 2), cornerRadius: 1)
                line.strokeColor = .clear
                line.fillColor = tint.withAlphaComponent(0.16)
                accent = line
            default:
                let width = CGFloat.random(in: 10...16)
                let rect = SKShapeNode(rectOf: CGSize(width: width, height: width * 0.72), cornerRadius: 2)
                rect.strokeColor = tint.withAlphaComponent(0.22)
                rect.fillColor = tint.withAlphaComponent(0.05)
                rect.lineWidth = 0.8
                accent = rect
            }

            accent.alpha = CGFloat.random(in: 0.16...0.28)
            accent.position = floatingAccentSpawnPoint(index: index)
            accent.zRotation = CGFloat.random(in: -0.65...0.65)
            floatingAccentNode.addChild(accent)

            let drift = CGPoint(
                x: CGFloat.random(in: -26...26),
                y: CGFloat.random(in: -18...18)
            )
            let duration = Double.random(in: 7.5...12.5)
            let rotateAmount = CGFloat.random(in: -0.18...0.18)
            accent.run(.repeatForever(.sequence([
                .group([
                    .moveBy(x: drift.x, y: drift.y, duration: duration),
                    .rotate(byAngle: rotateAmount, duration: duration),
                    .fadeAlpha(to: max(0.08, accent.alpha * 0.68), duration: duration)
                ]),
                .group([
                    .moveBy(x: -drift.x, y: -drift.y, duration: duration),
                    .rotate(byAngle: -rotateAmount, duration: duration),
                    .fadeAlpha(to: accent.alpha, duration: duration)
                ])
            ])), withKey: "floatingAccent")
        }
    }

    private func floatingAccentSpawnPoint(index: Int) -> CGPoint {
        let columns: [CGFloat] = [-0.42, -0.34, -0.24, -0.14, 0.14, 0.24, 0.34, 0.42]
        let rows: [CGFloat] = [0.42, 0.34, 0.26, 0.16, -0.08, -0.18, -0.30, -0.42]
        let x = size.width * columns[index % columns.count]
        let y = size.height * rows[(index * 2) % rows.count]

        let titleBand = CGRect(
            x: -size.width * 0.26,
            y: size.height * 0.12,
            width: size.width * 0.52,
            height: size.height * 0.14
        )
        let buttonBand = CGRect(
            x: -size.width * 0.32,
            y: -size.height * 0.12,
            width: size.width * 0.64,
            height: size.height * 0.34
        )
        let point = CGPoint(x: x, y: y)
        if titleBand.contains(point) {
            return CGPoint(
                x: x < 0 ? -size.width * 0.4 : size.width * 0.4,
                y: y + size.height * 0.08
            )
        }
        if buttonBand.contains(point) {
            return CGPoint(
                x: x < 0 ? -size.width * 0.4 : size.width * 0.4,
                y: y - size.height * 0.16
            )
        }
        return point
    }

    private func spawnDeepParticle() {
        let sizeValue = CGFloat.random(in: 1.2...2.6)
        let dot = SKSpriteNode(
            color: Self.randomParticleColor(pinkChance: 0.18),
            size: CGSize(width: sizeValue, height: sizeValue)
        )
        dot.alpha = CGFloat.random(in: 0.08...0.16)
        dot.blendMode = .add
        dot.position = particleSpawnPoint(avoidingTitleBand: true, preferLowerHalf: false)
        deepParticleNode.addChild(dot)

        let speed = CGFloat.random(in: Metric.farParticleSpeed)
        let verticalTravel = size.height + 60
        let travelDuration = Double(verticalTravel / speed)
        let drift = SKAction.moveBy(
            x: CGFloat.random(in: -10...10),
            y: -verticalTravel,
            duration: travelDuration
        )
        let pulse = SKAction.sequence([
            .fadeAlpha(to: dot.alpha * 1.14, duration: 2.4),
            .fadeAlpha(to: dot.alpha * 0.78, duration: 2.6)
        ])
        dot.run(.group([.repeatForever(pulse), .sequence([
            drift,
            .removeFromParent(),
            .run { [weak self] in self?.spawnDeepParticle() }
        ])]))
    }

    private func spawnAccentParticle() {
        let sizeValue = CGFloat.random(in: 3.0...4.8)
        let dot = SKSpriteNode(
            color: Self.randomParticleColor(pinkChance: 0.24),
            size: CGSize(width: sizeValue, height: sizeValue)
        )
        dot.alpha = CGFloat.random(in: 0.12...0.22)
        dot.blendMode = .add
        dot.position = particleSpawnPoint(avoidingTitleBand: true, preferLowerHalf: true)
        accentParticleNode.addChild(dot)

        let speed = CGFloat.random(in: Metric.mediumParticleSpeed)
        let verticalTravel = size.height + 70
        let horizontalTravel = CGFloat.random(in: -70 ... -34) + CGFloat.random(in: 0...1) * 104
        let glideDuration = Double(verticalTravel / speed)
        let glide = SKAction.moveBy(
            x: horizontalTravel,
            y: -verticalTravel,
            duration: glideDuration
        )
        let shimmer = SKAction.sequence([
            .fadeAlpha(to: dot.alpha * 1.16, duration: 1.5),
            .fadeAlpha(to: dot.alpha * 0.74, duration: 1.8)
        ])
        dot.run(.group([.repeatForever(shimmer), .sequence([
            glide,
            .removeFromParent(),
            .run { [weak self] in self?.spawnAccentParticle() }
        ])]))
    }

    private func spawnParticle() {
        let particleSize = CGFloat.random(in: 5.4...8.0)
        let particle = SKSpriteNode(
            color: Self.randomParticleColor(pinkChance: 0.22),
            size: CGSize(width: particleSize, height: particleSize)
        )
        particle.alpha = CGFloat.random(in: 0.18...0.28)
        particle.blendMode = .add
        particle.position = particleSpawnPoint(avoidingTitleBand: true, preferLowerHalf: true)
        particleNode.addChild(particle)

        let speed = CGFloat.random(in: Metric.nearParticleSpeed)
        let verticalTravel = size.height + 90
        let horizontalTravel = CGFloat.random(in: 46...84) * (Bool.random() ? 1 : -1)
        let travelDuration = Double(verticalTravel / speed)
        let travel = SKAction.moveBy(
            x: horizontalTravel,
            y: -verticalTravel,
            duration: travelDuration
        )
        let fade = SKAction.sequence([
            .fadeAlpha(to: particle.alpha * 1.08, duration: travelDuration * 0.24),
            .fadeOut(withDuration: travelDuration * 0.76)
        ])
        particle.run(.sequence([
            .group([travel, fade]),
            .removeFromParent(),
            .run { [weak self] in self?.spawnParticle() }
        ]))
    }

    private func particleSpawnPoint(avoidingTitleBand: Bool, preferLowerHalf: Bool) -> CGPoint {
        let xRange = (-size.width / 2 - 20)...(size.width / 2 + 20)
        let yRange: ClosedRange<CGFloat>
        if preferLowerHalf {
            yRange = (-size.height / 2 - 30)...(size.height * 0.08)
        } else {
            yRange = (-size.height / 2 - 20)...(size.height / 2 + 20)
        }

        var point = CGPoint(
            x: CGFloat.random(in: xRange),
            y: CGFloat.random(in: yRange)
        )

        guard avoidingTitleBand else { return point }

        let protectedCenterY = abs(titleLabel.position.y) > 1 ? titleLabel.position.y : size.height * 0.18
        let protectedRect = CGRect(
            x: -size.width * 0.28,
            y: protectedCenterY - 42,
            width: size.width * 0.56,
            height: 84
        )
        if protectedRect.contains(point) {
            point.y = min(protectedRect.minY - CGFloat.random(in: 40...120), size.height / 2 + 20)
        }
        return point
    }

    private static func randomParticleColor(pinkChance: CGFloat) -> SKColor {
        CGFloat.random(in: 0...1) < pinkChance ? SKColor(hex: 0xFF2D9A) : SKColor(hex: 0x00D4FF)
    }

    fileprivate static func makeMenuBaseTexture(size: CGSize, top: SKColor, middle: SKColor, bottom: SKColor) -> SKTexture {
        renderTexture(size: size, scale: 2.0) { context, rendererSize in
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [top.cgColor, middle.cgColor, bottom.cgColor] as CFArray
            let locations: [CGFloat] = [0.0, 0.52, 1.0]
            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else { return }
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: rendererSize.width / 2, y: rendererSize.height),
                end: CGPoint(x: rendererSize.width / 2, y: 0),
                options: []
            )
        }
    }

    fileprivate static func makeVignetteTexture(size: CGSize, edgeAlpha: CGFloat) -> SKTexture {
        renderTexture(size: size, scale: 2.0) { context, rendererSize in
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let center = CGPoint(x: rendererSize.width / 2, y: rendererSize.height / 2)
            let radius = max(rendererSize.width, rendererSize.height) * 0.72
            let colors = [
                UIColor.black.withAlphaComponent(0.0).cgColor,
                UIColor.black.withAlphaComponent(edgeAlpha * 0.42).cgColor,
                UIColor.black.withAlphaComponent(edgeAlpha).cgColor
            ] as CFArray
            let locations: [CGFloat] = [0.22, 0.68, 1.0]
            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else { return }
            context.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: radius,
                options: [.drawsAfterEndLocation]
            )
        }
    }

    fileprivate static func makeGridTexture(size: CGSize, spacing: CGSize, lineWidth: CGFloat, color: SKColor, alpha: CGFloat, scale: CGFloat) -> SKTexture {
        renderTexture(size: size, scale: scale) { context, rendererSize in
            context.setLineWidth(max(lineWidth, 1.0 / scale))

            var verticalPositions: [CGFloat] = []
            var x: CGFloat = 0
            var columnIndex = 0
            while x <= rendererSize.width {
                let intensity = max(0.42, min(1.18, 0.78 + sin(CGFloat(columnIndex) * 0.72) * 0.18 + cos(CGFloat(columnIndex) * 0.21) * 0.08))
                context.setStrokeColor(color.withAlphaComponent(alpha * intensity).cgColor)
                context.move(to: CGPoint(x: x, y: 0))
                context.addLine(to: CGPoint(x: x, y: rendererSize.height))
                context.strokePath()
                verticalPositions.append(x)
                x += spacing.width
                columnIndex += 1
            }

            var horizontalPositions: [CGFloat] = []
            var y: CGFloat = 0
            var rowIndex = 0
            while y <= rendererSize.height {
                let intensity = max(0.4, min(1.16, 0.74 + cos(CGFloat(rowIndex) * 0.58) * 0.16 + sin(CGFloat(rowIndex) * 0.26) * 0.08))
                context.setStrokeColor(color.withAlphaComponent(alpha * intensity).cgColor)
                context.move(to: CGPoint(x: 0, y: y))
                context.addLine(to: CGPoint(x: rendererSize.width, y: y))
                context.strokePath()
                horizontalPositions.append(y)
                y += spacing.height
                rowIndex += 1
            }

            let dotSize = max(1.2, 1.8 / scale)
            for (xIndex, xPos) in verticalPositions.enumerated() where xIndex % 3 == 1 {
                for (yIndex, yPos) in horizontalPositions.enumerated() where yIndex % 4 == 2 {
                    let pulseFactor = max(0.0, 0.55 + sin(CGFloat(xIndex * 7 + yIndex * 3) * 0.33) * 0.22)
                    let dotAlpha = alpha * 0.8 * pulseFactor
                    context.setFillColor(color.withAlphaComponent(dotAlpha).cgColor)
                    context.fillEllipse(in: CGRect(
                        x: xPos - dotSize * 0.5,
                        y: yPos - dotSize * 0.5,
                        width: dotSize,
                        height: dotSize
                    ))
                }
            }
        }
    }

    fileprivate static func makeRadialGlowTexture(size: CGSize, color: SKColor, innerAlpha: CGFloat, outerAlpha: CGFloat) -> SKTexture {
        renderTexture(size: size, scale: 2.0) { context, rendererSize in
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let center = CGPoint(x: rendererSize.width / 2, y: rendererSize.height / 2)
            let colors = [
                color.withAlphaComponent(innerAlpha).cgColor,
                color.withAlphaComponent(innerAlpha * 0.42).cgColor,
                color.withAlphaComponent(outerAlpha).cgColor
            ] as CFArray
            let locations: [CGFloat] = [0.0, 0.52, 1.0]
            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else { return }
            context.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: max(rendererSize.width, rendererSize.height) * 0.5,
                options: [.drawsAfterEndLocation]
            )
        }
    }

    fileprivate static func makeAmbientStreakTexture(size: CGSize, tint: SKColor) -> SKTexture {
        renderTexture(size: size, scale: 2.0) { context, rendererSize in
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [
                tint.withAlphaComponent(0.0).cgColor,
                tint.withAlphaComponent(0.14).cgColor,
                tint.withAlphaComponent(0.0).cgColor
            ] as CFArray
            let locations: [CGFloat] = [0.0, 0.52, 1.0]
            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else { return }
            let start = CGPoint(x: 0, y: rendererSize.height)
            let end = CGPoint(x: rendererSize.width, y: 0)
            context.drawLinearGradient(gradient, start: start, end: end, options: [])
        }
    }

    private static func renderTexture(size: CGSize, scale: CGFloat, draw: (CGContext, CGSize) -> Void) -> SKTexture {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { rendererContext in
            draw(rendererContext.cgContext, size)
        }
        return SKTexture(image: image)
    }

    private func resolvedScreenScale() -> CGFloat {
        if let screenScale = view?.window?.windowScene?.screen.scale {
            return screenScale
        }
        if let contentScale = view?.contentScaleFactor, contentScale > 0 {
            return contentScale
        }
        return 2.0
    }

    private func spawnSparkle() {
        let sparkle = SKSpriteNode(color: Bool.random() ? ArcadeStyle.Color.accentYellow : ArcadeStyle.Color.accentCyan, size: CGSize(width: CGFloat.random(in: 8...14), height: 2))
        sparkle.alpha = 0
        sparkle.blendMode = .add
        sparkle.zRotation = CGFloat.random(in: -0.65...0.65)
        let x = Bool.random() ? CGFloat.random(in: -size.width * 0.46 ... -size.width * 0.18) : CGFloat.random(in: size.width * 0.18 ... size.width * 0.46)
        let y = CGFloat.random(in: -size.height * 0.36...size.height * 0.34)
        sparkle.position = CGPoint(x: x, y: y)
        sparkleNode.addChild(sparkle)

        sparkle.run(.sequence([
            .wait(forDuration: Double.random(in: 0.8...4.4)),
            .group([
                .fadeAlpha(to: CGFloat.random(in: 0.12...0.24), duration: 0.18),
                .scale(to: 1.18, duration: 0.18)
            ]),
            .group([
                .fadeOut(withDuration: 0.34),
                .scale(to: 0.74, duration: 0.34),
                .moveBy(x: CGFloat.random(in: -6...6), y: CGFloat.random(in: 10...22), duration: 0.34)
            ]),
            .removeFromParent(),
            .run { [weak self] in self?.spawnSparkle() }
        ]))
    }

    private func spawnForegroundFlyby() {
        let tintOptions = [
            ArcadeStyle.Color.accentCyan,
            ArcadeStyle.Color.accentMagenta,
            ArcadeStyle.Color.accentYellow
        ]
        let tint = tintOptions.randomElement() ?? ArcadeStyle.Color.accentCyan
        let width = CGFloat.random(in: 64...132)
        let height = CGFloat.random(in: 7...14)

        let body = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: height * 0.48)
        body.fillColor = tint.withAlphaComponent(CGFloat.random(in: 0.1...0.18))
        body.strokeColor = tint.withAlphaComponent(0.5)
        body.lineWidth = 1.2
        body.glowWidth = 1.4
        body.alpha = 0

        let core = SKShapeNode(rectOf: CGSize(width: width * 0.42, height: max(2.0, height * 0.24)), cornerRadius: max(1.0, height * 0.12))
        core.fillColor = .white.withAlphaComponent(0.26)
        core.strokeColor = .clear
        core.position = CGPoint(x: -width * 0.1, y: 0)
        body.addChild(core)

        let fromLeft = Bool.random()
        let startX = fromLeft ? -size.width * 0.82 : size.width * 0.82
        var startY = CGFloat.random(in: -size.height * 0.42...size.height * 0.30)
        if abs(startY) < size.height * 0.14 {
            startY -= size.height * 0.16
        }
        let endX = fromLeft ? size.width * 0.82 : -size.width * 0.82
        let endY = startY + CGFloat.random(in: -40...70)

        body.position = CGPoint(x: startX, y: startY)
        body.zRotation = CGFloat.random(in: -0.42 ... -0.18) * (fromLeft ? 1 : -1)
        foregroundMotionNode.addChild(body)

        let fadePeak = CGFloat.random(in: 0.16...0.26)
        let duration = Double.random(in: 5.8...8.4)
        body.run(.sequence([
            .wait(forDuration: Double.random(in: 0.4...2.2)),
            .group([
                .sequence([
                    .fadeAlpha(to: fadePeak, duration: duration * 0.24),
                    .fadeOut(withDuration: duration * 0.34)
                ]),
                .sequence([
                    .move(to: CGPoint(x: endX, y: endY), duration: duration)
                ])
            ]),
            .removeFromParent(),
            .run { [weak self] in self?.spawnForegroundFlyby() }
        ]))
    }

    private func spawnForegroundShard() {
        let tintOptions = [
            ArcadeStyle.Color.accentCyan.withAlphaComponent(0.14),
            ArcadeStyle.Color.accentMagenta.withAlphaComponent(0.12),
            ArcadeStyle.Color.accentYellow.withAlphaComponent(0.12)
        ]
        let tint = tintOptions.randomElement() ?? ArcadeStyle.Color.accentCyan.withAlphaComponent(0.14)
        let sizeValue = CGFloat.random(in: 10...18)
        let shard = SKShapeNode(rectOf: CGSize(width: sizeValue, height: sizeValue * 0.72), cornerRadius: sizeValue * 0.18)
        shard.fillColor = tint
        shard.strokeColor = tint.withAlphaComponent(0.65)
        shard.lineWidth = 0.9
        shard.glowWidth = 1.2
        shard.alpha = 0
        shard.zRotation = CGFloat.random(in: -0.7...0.7)

        let startX = CGFloat.random(in: -size.width * 0.7...size.width * 0.7)
        var startY = CGFloat.random(in: -size.height * 0.46...size.height * 0.24)
        if abs(startY) < size.height * 0.16 {
            startY -= size.height * 0.18
        }
        let endX = startX + CGFloat.random(in: -54...54)
        let endY = startY + CGFloat.random(in: 120...210)
        shard.position = CGPoint(x: startX, y: startY)
        foregroundMotionNode.addChild(shard)

        let maxAlpha = CGFloat.random(in: 0.14...0.24)
        let duration = Double.random(in: 7.0...10.5)
        shard.run(.sequence([
            .wait(forDuration: Double.random(in: 0.2...2.4)),
            .group([
                .sequence([
                    .fadeAlpha(to: maxAlpha, duration: duration * 0.18),
                    .fadeOut(withDuration: duration * 0.26)
                ]),
                .move(to: CGPoint(x: endX, y: endY), duration: duration),
                .rotate(byAngle: CGFloat.random(in: -0.45...0.45), duration: duration)
            ]),
            .removeFromParent(),
            .run { [weak self] in self?.spawnForegroundShard() }
        ]))
    }

    private func refreshContent() {
        let continueLevel = ProgressStore.shared.continueLevelId
        refreshBackground()

        challengeButton.label.text = "TIME CHALLENGE"
        challengeDetailLabel.text = nil
        challengeDetailLabel.isHidden = true
        levelsButton.label.text = "LEVELS"
        continueButton.label.text = "CONTINUE"
        continueDetailLabel.text = "LEVEL \(continueLevel)"
        dailyButton.label.text = "DAILY"
        shopButton.label.text = "SHOP"
        settingsButton.label.text = "SETTINGS"

        infoLabel.text = nil
        infoLabel.isHidden = true

        settingsOverlay?.refresh()
        dailyPromptOverlay?.refresh()
    }

    private func layoutScene() {
        let safeTop = size.height / 2 - safeInsets.top - Metric.topMargin
        let safeBottom = -size.height / 2 + safeInsets.bottom + 18
        let safeWidth = size.width - safeInsets.left - safeInsets.right
        titleLabel.fontSize = clamp(28, 34, safeWidth * 0.074)
        subtitleLabel.fontSize = 12

        let contentWidth = min(safeWidth - Metric.sidePadding * 2, 338)

        statContainer.removeAllChildren()
        statCards.removeAll()
        statTitles.removeAll()
        statTitleShadows.removeAll()
        statValues.removeAll()
        statValueShadows.removeAll()

        let actionGap: CGFloat = 12
        let challengeSize = snapSize(CGSize(width: contentWidth, height: 92))
        let continueSize = snapSize(CGSize(width: contentWidth, height: 70))
        let utilityButtonHeight: CGFloat = 44
        let levelsSize = snapSize(CGSize(width: floor((contentWidth - actionGap) / 2), height: 58))
        let settingsSize = levelsSize
        challengeButton.size = challengeSize
        continueButton.size = continueSize
        levelsButton.size = levelsSize
        settingsButton.size = settingsSize
        dailyButton.size = snapSize(CGSize(width: 124, height: utilityButtonHeight))
        shopButton.size = snapSize(CGSize(width: 104, height: utilityButtonHeight))

        challengeButton.label.fontSize = 23
        challengeButton.label.horizontalAlignmentMode = .left
        challengeButton.label.position = snap(CGPoint(x: -challengeSize.width / 2 + 92, y: 1))
        challengeDetailLabel.isHidden = true

        continueButton.label.fontSize = 20
        continueButton.label.horizontalAlignmentMode = .left
        continueButton.label.position = snap(CGPoint(x: -continueSize.width / 2 + 86, y: 10))
        continueDetailLabel.fontSize = 10
        continueDetailLabel.position = snap(CGPoint(x: -continueSize.width / 2 + 86, y: -12))

        levelsButton.label.fontSize = 17
        levelsButton.label.horizontalAlignmentMode = .center
        levelsButton.label.position = snap(CGPoint(x: 0, y: 1))

        settingsButton.label.fontSize = 16
        settingsButton.label.horizontalAlignmentMode = .left
        settingsButton.label.position = snap(CGPoint(x: -settingsSize.width / 2 + 64, y: 1))

        dailyButton.label.fontSize = 11
        dailyButton.label.horizontalAlignmentMode = .left
        dailyButton.label.position = snap(CGPoint(x: -dailyButton.size.width / 2 + 46, y: 1))
        shopButton.label.fontSize = 12
        shopButton.label.horizontalAlignmentMode = .left
        shopButton.label.position = snap(CGPoint(x: -shopButton.size.width / 2 + 46, y: 1))

        challengeIconNode.position = snap(CGPoint(x: -challengeSize.width / 2 + 42, y: 0))
        continueIconNode.position = snap(CGPoint(x: -continueSize.width / 2 + 42, y: 0))
        settingsIconNode.position = snap(CGPoint(x: -settingsSize.width / 2 + 28, y: 0))
        dailyIconNode.position = snap(CGPoint(x: -dailyButton.size.width / 2 + 22, y: 0))
        shopIconNode.position = snap(CGPoint(x: -shopButton.size.width / 2 + 22, y: 0))

        let utilityY = safeTop - utilityButtonHeight / 2
        utilityContainer.position = snap(CGPoint(x: 0, y: utilityY))
        let utilityTrailing = safeWidth / 2 - Metric.sidePadding
        let utilityLeading = -safeWidth / 2 + Metric.sidePadding
        shopButton.position = snap(CGPoint(x: utilityTrailing - shopButton.size.width / 2, y: 0))
        dailyButton.position = snap(CGPoint(x: utilityLeading + dailyButton.size.width / 2, y: 0))

        let titleBlockHeight: CGFloat = 58
        let titleToButtonsSpacing: CGFloat = 24
        let buttonsToInfoSpacing: CGFloat = 0
        let infoHeight: CGFloat = 0
        let actionRowHeight = max(levelsButton.size.height, settingsButton.size.height)
        let buttonStackHeight = challengeButton.size.height + continueButton.size.height + actionRowHeight + Metric.buttonSpacing * 2
        let totalStackHeight = titleBlockHeight + titleToButtonsSpacing + buttonStackHeight + buttonsToInfoSpacing + infoHeight
        let safeHeight = safeTop - safeBottom
        let stackTop = safeBottom + (safeHeight + totalStackHeight) / 2 - 4
        let titleCenterY = stackTop - titleBlockHeight / 2
        let buttonsCenterY = titleCenterY - titleBlockHeight / 2 - titleToButtonsSpacing - buttonStackHeight / 2
        let infoCenterY = buttonsCenterY - buttonStackHeight / 2 - buttonsToInfoSpacing - infoHeight / 2

        titleLabel.position = snap(CGPoint(x: 0, y: titleCenterY + 10))
        subtitleLabel.position = snap(CGPoint(x: 0, y: titleCenterY - 15))
        buttonContainer.position = snap(CGPoint(x: 0, y: buttonsCenterY))

        let challengeY = buttonStackHeight / 2 - challengeButton.size.height / 2
        let continueY = challengeY - challengeButton.size.height / 2 - Metric.buttonSpacing - continueButton.size.height / 2
        let actionRowY = continueY - continueButton.size.height / 2 - Metric.buttonSpacing - actionRowHeight / 2
        let actionRowWidth = levelsButton.size.width + actionGap + settingsButton.size.width
        let levelsX = -actionRowWidth / 2 + levelsButton.size.width / 2
        let settingsX = actionRowWidth / 2 - settingsButton.size.width / 2

        challengeButton.position = snap(CGPoint(x: 0, y: challengeY))
        continueButton.position = snap(CGPoint(x: 0, y: continueY))
        levelsButton.position = snap(CGPoint(x: levelsX, y: actionRowY))
        settingsButton.position = snap(CGPoint(x: settingsX, y: actionRowY))
        infoLabel.position = snap(CGPoint(x: 0, y: max(safeBottom + 12, infoCenterY)))

        settingsOverlay?.applyLayout(in: size, safeInsets: safeInsets)
        dailyPromptOverlay?.applyLayout(in: size, safeInsets: safeInsets)
    }

    private func animateEntrance() {
        titleLabel.alpha = 0
        subtitleLabel.alpha = 0
        titleLabel.run(.group([
            .fadeIn(withDuration: 0.28),
            .moveBy(x: 0, y: 6, duration: 0.28)
        ]))
        subtitleLabel.run(.sequence([
            .wait(forDuration: 0.08),
            .fadeIn(withDuration: 0.22)
        ]))

        challengeButton.run(.repeatForever(.sequence([
            .wait(forDuration: 1.0),
            .scale(to: 1.025, duration: 0.18),
            .scale(to: 1.0, duration: 0.18)
        ])), withKey: "ctaPulse")
        dailyButton.run(.repeatForever(.sequence([
            .wait(forDuration: 2.2),
            .moveBy(x: 0, y: 2, duration: 0.18),
            .moveBy(x: 0, y: -2, duration: 0.22)
        ])), withKey: "dailyFloat")
    }

    private func playTap() {
        SoundFX.playButtonTap(on: self)
    }

    private func playCashTap() {
        SoundFX.playReward(on: self)
    }

    private func presentSettingsOverlay() {
        guard settingsOverlay == nil else { return }
        playTap()
        let overlay = SettingsOverlayNode()
        overlay.onClose = { [weak self] in
            self?.dismissSettingsOverlay()
        }
        overlay.onToggleVibration = { [weak self] enabled in
            SettingsStore.shared.setVibrationEnabled(enabled)
            self?.refreshContent()
            if enabled {
                Haptics.impact(.light)
            }
        }
        overlay.onToggleEffects = { [weak self] enabled in
            SettingsStore.shared.setEffectsEnabled(enabled)
            SoundFX.syncAudioState()
            self?.refreshContent()
            if SettingsStore.shared.isEffectsPlaybackEnabled {
                if let self {
                    SoundFX.playButtonTap(on: self)
                } else {
                    SoundFX.playButtonTap(on: overlay)
                }
            }
        }
        overlay.onToggleMusic = { [weak self] enabled in
            SettingsStore.shared.setMusicEnabled(enabled)
            SoundFX.syncAudioState()
            self?.refreshContent()
            if SettingsStore.shared.isEffectsPlaybackEnabled {
                if let self {
                    SoundFX.play(.select2, on: self)
                } else {
                    SoundFX.play(.select2, on: overlay)
                }
            }
        }
        overlay.onVolumeChanged = { [weak self] value in
            SettingsStore.shared.setMasterVolume(value)
            SoundFX.syncAudioState()
            self?.refreshContent()
        }
        settingsOverlay = overlay
        cameraNode.addChild(overlay)
        overlay.alpha = 0
        overlay.applyLayout(in: size, safeInsets: safeInsets)
        overlay.refresh()
        overlay.run(.fadeAlpha(to: 1, duration: 0.18))
    }

    private func dismissSettingsOverlay() {
        guard let overlay = settingsOverlay else { return }
        playTap()
        settingsOverlay = nil
        activeVolumeSlider = nil
        overlay.run(.sequence([
            .fadeOut(withDuration: 0.16),
            .removeFromParent()
        ]))
    }

    private func presentDailyPromptIfNeeded() {
        guard dailyPromptOverlay == nil, settingsOverlay == nil, DailyPromptStore.shared.shouldShowPromptToday() else { return }
        DailyPromptStore.shared.markShownToday()
        let overlay = DailyPromptOverlayNode()
        overlay.onPlay = { [weak self] in
            guard let self else { return }
            self.dismissDailyPrompt(openDaily: true)
        }
        overlay.onLater = { [weak self] in
            self?.dismissDailyPrompt(openDaily: false)
        }
        dailyPromptOverlay = overlay
        cameraNode.addChild(overlay)
        overlay.alpha = 0
        overlay.applyLayout(in: size, safeInsets: safeInsets)
        overlay.refresh()
        SoundFX.play(.popupOpen, on: self)
        overlay.run(.fadeAlpha(to: 1, duration: 0.18))
    }

    private func dismissDailyPrompt(openDaily: Bool) {
        guard let overlay = dailyPromptOverlay else { return }
        dailyPromptOverlay = nil
        overlay.run(.sequence([
            .fadeOut(withDuration: 0.16),
            .removeFromParent()
        ]))
        if openDaily {
            presentDailyChallengeSelect()
        } else {
            playTap()
        }
    }

    private func presentLevelSelect() {
        guard let view = view, !isTransitioning else { return }
        isTransitioning = true
        SoundFX.play(.popupOpen, on: self)
        let scene = LevelSelectScene(size: size)
        scene.scaleMode = .resizeFill
        view.presentScene(scene, transition: .fade(withDuration: 0.35))
    }

    private func presentChallengeSelect() {
        guard let view = view, !isTransitioning else { return }
        isTransitioning = true
        SoundFX.play(.popupOpen, on: self)
        let scene = ChallengeSelectScene(size: size)
        scene.scaleMode = .resizeFill
        view.presentScene(scene, transition: .fade(withDuration: 0.35))
    }

    private func presentDailyChallengeSelect() {
        guard let view = view, !isTransitioning else { return }
        isTransitioning = true
        SoundFX.play(.popupOpen, on: self)
        let scene = DailyChallengeScene(size: size)
        scene.scaleMode = .resizeFill
        view.presentScene(scene, transition: .fade(withDuration: 0.35))
    }

    private func presentShop() {
        guard let view = view, !isTransitioning else { return }
        isTransitioning = true
        playCashTap()
        let scene = ShopScene(size: size)
        scene.scaleMode = .resizeFill
        view.presentScene(scene, transition: .fade(withDuration: 0.35))
    }

    private func presentGame(levelId: Int) {
        guard let view = view, !isTransitioning else { return }
        isTransitioning = true
        SoundFX.play(.popupOpen, on: self)
        let safeLevelId = min(LevelStore.levels.count, max(1, levelId))
        let scene = GameScene(size: size, levelIndex: safeLevelId - 1)
        scene.scaleMode = .resizeFill
        view.presentScene(scene, transition: .fade(withDuration: 0.35))
    }

    private func updateSafeInsets() {
        if let windowInsets = view?.window?.safeAreaInsets,
           windowInsets != .zero {
            safeInsets = windowInsets
            return
        }
        safeInsets = view?.safeAreaInsets ?? .zero
    }

    private func formattedClockTime(_ time: TimeInterval) -> String {
        let clamped = max(0, time)
        let minutes = Int(clamped / 60)
        let seconds = clamped - Double(minutes * 60)
        return String(format: "%02d:%05.2f", minutes, seconds)
    }

    private func nextRewardStatus(from continueLevel: Int) -> String {
        let nextThemeUnlockLevel = (((max(1, continueLevel) - 1) / 5) + 1) * 5
        if nextThemeUnlockLevel <= LevelStore.levels.count {
            let remaining = max(0, nextThemeUnlockLevel - ProgressStore.shared.completedLevelCount)
            if remaining <= 1 {
                let themeName = themeName(for: ThemeUnlocker.theme(for: nextThemeUnlockLevel))
                return "NEXT THEME READY · \(themeName)"
            }
            return "NEXT THEME IN \(remaining)"
        }
        return "ALL THEMES UNLOCKED"
    }

    private func nextGoalStatus() -> String {
        if let achievement = AchievementStore.shared.nextLockedAchievement() {
            return "NEXT GOAL · \(achievement.title)"
        }
        return "ALL ACHIEVEMENTS UNLOCKED"
    }

    private func themeName(for theme: MazeTheme) -> String {
        switch theme {
        case .defaultTheme:
            return "NEON CORE"
        case .vaporwave:
            return "VAPORWAVE"
        case .neonMint:
            return "MINT CIRCUIT"
        case .sunsetPulse:
            return "SUNSET PULSE"
        case .arctic:
            return "ARCTIC DRIVE"
        case .ember:
            return "EMBER SHIFT"
        }
    }

    private func applySelectedSkin(to sprite: SKSpriteNode) {
        CosmeticRenderer.applyPlayerSkin(PlayerSkinStore.shared.selectedSkin, to: sprite, displayScale: TextureFactory.shared.displayScale)
    }

    private func snap(_ point: CGPoint) -> CGPoint {
        CGPoint(x: round(point.x), y: round(point.y))
    }

    private func snapSize(_ size: CGSize) -> CGSize {
        CGSize(width: round(size.width), height: round(size.height))
    }

    private func clamp(_ minValue: CGFloat, _ maxValue: CGFloat, _ value: CGFloat) -> CGFloat {
        min(maxValue, max(minValue, value))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        if let slider = settingsOverlay?.slider(at: point, in: self) {
            activeVolumeSlider = slider
            slider.updateValue(with: point, in: self)
            return
        }
        guard let button = menuButton(at: point) else { return }
        touchStartPoint = point
        activeButton = button
        button.setPressed(true)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        if let slider = activeVolumeSlider {
            slider.updateValue(with: point, in: self)
            return
        }
        guard let button = activeButton else { return }
        button.setPressed(button.hitTest(point, in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let slider = activeVolumeSlider, let point = touches.first?.location(in: self) {
            slider.updateValue(with: point, in: self)
            activeVolumeSlider = nil
            return
        }
        guard let button = activeButton, let point = touches.first?.location(in: self) else {
            activeButton?.setPressed(false)
            activeButton = nil
            touchStartPoint = nil
            return
        }
        let movement = touchStartPoint.map { hypot(point.x - $0.x, point.y - $0.y) } ?? 0
        let shouldTap = button.hitTest(point, in: self) || movement <= 14
        button.setPressed(false)
        activeButton = nil
        touchStartPoint = nil
        if shouldTap {
            activate(button)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeButton?.setPressed(false)
        activeButton = nil
        touchStartPoint = nil
        activeVolumeSlider = nil
    }

    private func menuButton(at scenePoint: CGPoint) -> ArcadeButtonNode? {
        if let overlay = dailyPromptOverlay {
            return overlay.button(at: scenePoint, in: self)
        }
        if let overlay = settingsOverlay {
            return overlay.button(at: scenePoint, in: self)
        }
        let buttons = [dailyButton, shopButton, challengeButton, continueButton, levelsButton, settingsButton]
        for button in buttons where button.hitTest(scenePoint, in: self) {
            return button
        }
        return nil
    }

    private func activate(_ button: ArcadeButtonNode) {
        if button === continueButton {
            presentGame(levelId: ProgressStore.shared.continueLevelId)
        } else if button === challengeButton {
            presentChallengeSelect()
        } else if button === dailyButton {
            presentDailyChallengeSelect()
        } else if button === levelsButton {
            presentLevelSelect()
        } else if button === shopButton {
            presentShop()
        } else {
            button.onTap?()
        }
    }

    private static func makeClockIcon() -> SKNode {
        makeBundledIconNode(
            assetName: "StartIconTime",
            radius: 19,
            iconSize: CGSize(width: 24, height: 24),
            fill: ArcadeStyle.Color.accentCyan.withAlphaComponent(0.34),
            stroke: ArcadeStyle.Color.accentCyan.withAlphaComponent(1.0)
        )
    }

    private static func makePlayIcon() -> SKNode {
        makeBundledIconNode(
            assetName: "StartIconPlay",
            radius: 18,
            iconSize: CGSize(width: 22, height: 22),
            fill: ArcadeStyle.Color.accentYellow.withAlphaComponent(0.4),
            stroke: ArcadeStyle.Color.accentYellow
        )
    }

    private static func makeGearIcon() -> SKNode {
        makeBundledIconNode(
            assetName: "StartIconSettings",
            radius: 18,
            iconSize: CGSize(width: 22, height: 22),
            fill: ArcadeStyle.Color.accentMagenta.withAlphaComponent(0.34),
            stroke: ArcadeStyle.Color.accentMagenta
        )
    }

    private static func makeDailyCalendarIcon() -> SKNode {
        makeBundledIconNode(
            assetName: "StartIconCalendar",
            radius: 16,
            iconSize: CGSize(width: 21, height: 21),
            fill: ArcadeStyle.Color.accentMagenta.withAlphaComponent(0.34),
            stroke: ArcadeStyle.Color.accentMagenta
        )
    }

    private static func makeCoinIcon() -> SKNode {
        let root = SKNode()

        let plate = SKShapeNode(circleOfRadius: 16)
        plate.fillColor = ArcadeStyle.Color.accentYellow.withAlphaComponent(0.34)
        plate.strokeColor = ArcadeStyle.Color.accentYellow
        plate.lineWidth = 2.0
        plate.glowWidth = 4.8
        root.addChild(plate)

        let glow = makeTintedSpriteIcon(
            assetName: "StartIconShop",
            size: CGSize(width: 24, height: 24),
            tint: ArcadeStyle.Color.accentYellow
        )
        glow.alpha = 0.3
        glow.position = CGPoint(x: 0, y: 0.5)
        glow.zPosition = 1
        root.addChild(glow)

        let icon = makeTintedSpriteIcon(
            assetName: "StartIconShop",
            size: CGSize(width: 22, height: 22),
            tint: ArcadeStyle.Color.textPrimary
        )
        icon.position = CGPoint(x: 0, y: 0.5)
        root.addChild(icon)
        return root
    }

    private static func makeBundledIconNode(
        assetName: String,
        radius: CGFloat,
        iconSize: CGSize,
        fill: SKColor,
        stroke: SKColor
    ) -> SKNode {
        let root = SKNode()

        let plate = SKShapeNode(circleOfRadius: radius)
        plate.fillColor = fill
        plate.strokeColor = stroke
        plate.lineWidth = 2.0
        plate.glowWidth = 5.2
        root.addChild(plate)

        let glow = makeTintedSpriteIcon(assetName: assetName, size: CGSize(width: iconSize.width + 3, height: iconSize.height + 3), tint: stroke)
        glow.alpha = 0.38
        glow.position = CGPoint(x: 0, y: 0.5)
        glow.zPosition = 1
        root.addChild(glow)

        let icon = makeTintedSpriteIcon(assetName: assetName, size: iconSize, tint: ArcadeStyle.Color.textPrimary)
        icon.position = CGPoint(x: 0, y: 0.5)
        root.addChild(icon)
        return root
    }

    private static func makeTintedSpriteIcon(assetName: String, size: CGSize, tint: SKColor) -> SKSpriteNode {
        let texture: SKTexture
        if let image = UIImage(named: assetName) {
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = image.scale
            let tintedImage = UIGraphicsImageRenderer(size: image.size, format: format).image { context in
                let rect = CGRect(origin: .zero, size: image.size)
                tint.setFill()
                context.fill(rect)
                image.draw(in: rect, blendMode: .destinationIn, alpha: 1.0)
            }
            texture = SKTexture(image: tintedImage)
        } else {
            texture = SKTexture(imageNamed: assetName)
        }

        let sprite = SKSpriteNode(texture: texture)
        sprite.size = size
        sprite.alpha = 1.0
        sprite.blendMode = .alpha
        sprite.zPosition = 2
        return sprite
    }
}

private final class VolumeSliderNode: SKNode {
    private let trackNode = SKShapeNode()
    private let fillNode = SKShapeNode()
    private let thumbNode = SKShapeNode(circleOfRadius: 9)
    private var sliderWidth: CGFloat

    var onChanged: ((Float) -> Void)?
    private(set) var value: Float = SettingsStore.shared.masterVolume

    init(width: CGFloat = 180) {
        self.sliderWidth = width
        super.init()

        trackNode.strokeColor = ArcadeStyle.Color.panelBorder
        trackNode.fillColor = SKColor(white: 1.0, alpha: 0.08)
        trackNode.lineWidth = 1.4
        trackNode.zPosition = 1
        addChild(trackNode)

        fillNode.strokeColor = ArcadeStyle.Color.accentCyan
        fillNode.fillColor = ArcadeStyle.Color.accentCyan.withAlphaComponent(0.22)
        fillNode.lineWidth = 1.2
        fillNode.zPosition = 2
        addChild(fillNode)

        thumbNode.fillColor = ArcadeStyle.Color.textPrimary
        thumbNode.strokeColor = ArcadeStyle.Color.accentYellow
        thumbNode.lineWidth = 2
        thumbNode.glowWidth = 2
        thumbNode.zPosition = 3
        addChild(thumbNode)

        applySize(width)
        updateVisuals()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func applySize(_ width: CGFloat) {
        sliderWidth = max(120, width)
        let trackRect = CGRect(x: -sliderWidth / 2, y: -7, width: sliderWidth, height: 14)
        let fillRect = CGRect(x: -sliderWidth / 2, y: -7, width: sliderWidth * CGFloat(value), height: 14)
        trackNode.path = CGPath(roundedRect: trackRect, cornerWidth: 7, cornerHeight: 7, transform: nil)
        fillNode.path = CGPath(roundedRect: fillRect, cornerWidth: 7, cornerHeight: 7, transform: nil)
        updateThumbPosition()
    }

    func setValue(_ newValue: Float, notify: Bool) {
        value = min(1, max(0, newValue))
        updateVisuals()
        if notify {
            onChanged?(value)
        }
    }

    func updateValue(with scenePoint: CGPoint, in scene: SKScene) {
        let localPoint = pointInLocalSpace(scenePoint, from: scene)
        let normalized = Float((localPoint.x + sliderWidth / 2) / sliderWidth)
        setValue(normalized, notify: true)
    }

    func hitTest(_ scenePoint: CGPoint, in scene: SKScene) -> Bool {
        let localPoint = pointInLocalSpace(scenePoint, from: scene)
        let bounds = CGRect(x: -sliderWidth / 2 - 18, y: -20, width: sliderWidth + 36, height: 40)
        return bounds.contains(localPoint)
    }

    private func updateVisuals() {
        let fillRect = CGRect(x: -sliderWidth / 2, y: -7, width: sliderWidth * CGFloat(value), height: 14)
        fillNode.path = CGPath(roundedRect: fillRect, cornerWidth: 7, cornerHeight: 7, transform: nil)
        updateThumbPosition()
    }

    private func updateThumbPosition() {
        thumbNode.position = CGPoint(x: -sliderWidth / 2 + sliderWidth * CGFloat(value), y: 0)
    }

    private func pointInLocalSpace(_ scenePoint: CGPoint, from scene: SKScene) -> CGPoint {
        if let camera = scene.camera, inParentHierarchy(camera) {
            let cameraPoint = camera.convert(scenePoint, from: scene)
            return convert(cameraPoint, from: camera)
        }
        return convert(scenePoint, from: scene)
    }
}

private final class SettingsOverlayNode: SKNode {
    private let scrimNode = SKSpriteNode(color: SKColor(white: 0.0, alpha: 0.62), size: .zero)
    private let cardNode = SKSpriteNode()
    private let titleLabel = SKLabelNode(fontNamed: ArcadeFont.header)
    private let subtitleLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let vibrationLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let volumeLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let effectsLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let musicLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    let closeButton = ArcadeButtonNode(text: "DONE", size: CGSize(width: 108, height: 42))
    let vibrationToggle = ArcadeButtonNode(text: "ON", size: CGSize(width: 84, height: 38))
    let effectsToggle = ArcadeButtonNode(text: "ON", size: CGSize(width: 84, height: 38))
    let musicToggle = ArcadeButtonNode(text: "ON", size: CGSize(width: 84, height: 38))
    let volumeSlider = VolumeSliderNode()
    private let volumeValueLabel = SKLabelNode(fontNamed: ArcadeFont.digits)

    var onClose: (() -> Void)?
    var onToggleVibration: ((Bool) -> Void)?
    var onToggleEffects: ((Bool) -> Void)?
    var onToggleMusic: ((Bool) -> Void)?
    var onVolumeChanged: ((Float) -> Void)?

    override init() {
        super.init()

        zPosition = 120

        scrimNode.zPosition = 0
        addChild(scrimNode)

        cardNode.zPosition = 1
        addChild(cardNode)

        titleLabel.text = "SETTINGS"
        titleLabel.fontSize = 24
        titleLabel.fontColor = ArcadeStyle.Color.textPrimary
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode = .center
        titleLabel.zPosition = 4
        cardNode.addChild(titleLabel)

        subtitleLabel.text = "Tune the feel. Keep the flow."
        subtitleLabel.fontSize = 11
        subtitleLabel.fontColor = ArcadeStyle.Color.textSecondary
        subtitleLabel.horizontalAlignmentMode = .center
        subtitleLabel.verticalAlignmentMode = .center
        subtitleLabel.zPosition = 4
        cardNode.addChild(subtitleLabel)

        [vibrationLabel, volumeLabel, effectsLabel, musicLabel].forEach { label in
            label.fontSize = 12
            label.fontColor = ArcadeStyle.Color.textPrimary
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .center
            label.zPosition = 4
            cardNode.addChild(label)
        }
        vibrationLabel.text = "VIBRATION"
        volumeLabel.text = "MASTER VOLUME"
        effectsLabel.text = "SOUND FX"
        musicLabel.text = "MUSIC"

        volumeValueLabel.fontSize = 12
        volumeValueLabel.fontColor = ArcadeStyle.Color.accentYellow
        volumeValueLabel.horizontalAlignmentMode = .right
        volumeValueLabel.verticalAlignmentMode = .center
        volumeValueLabel.zPosition = 4
        cardNode.addChild(volumeValueLabel)

        vibrationToggle.setAccentColor(ArcadeStyle.Color.accentYellow)
        effectsToggle.setAccentColor(ArcadeStyle.Color.accentCyan)
        musicToggle.setAccentColor(ArcadeStyle.Color.accentMagenta)
        closeButton.setAccentColor(ArcadeStyle.Color.accentCyan)

        cardNode.addChild(vibrationToggle)
        cardNode.addChild(effectsToggle)
        cardNode.addChild(musicToggle)
        cardNode.addChild(volumeSlider)
        cardNode.addChild(closeButton)

        closeButton.onTap = { [weak self] in
            self?.onClose?()
        }
        vibrationToggle.onTap = { [weak self] in
            guard let self else { return }
            self.onToggleVibration?(!SettingsStore.shared.isVibrationEnabled)
        }
        effectsToggle.onTap = { [weak self] in
            guard let self else { return }
            self.onToggleEffects?(!SettingsStore.shared.isEffectsEnabled)
        }
        musicToggle.onTap = { [weak self] in
            guard let self else { return }
            self.onToggleMusic?(!SettingsStore.shared.isMusicEnabled)
        }
        volumeSlider.onChanged = { [weak self] value in
            self?.onVolumeChanged?(value)
            self?.refresh()
        }
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func refresh() {
        let settings = SettingsStore.shared
        vibrationToggle.label.text = settings.isVibrationEnabled ? "ON" : "OFF"
        effectsToggle.label.text = settings.isEffectsEnabled ? "ON" : "OFF"
        musicToggle.label.text = settings.isMusicEnabled ? "ON" : "OFF"
        vibrationToggle.setAccentColor(settings.isVibrationEnabled ? ArcadeStyle.Color.accentYellow : ArcadeStyle.Color.textMuted)
        effectsToggle.setAccentColor(settings.isEffectsEnabled ? ArcadeStyle.Color.accentCyan : ArcadeStyle.Color.textMuted)
        musicToggle.setAccentColor(settings.isMusicEnabled ? ArcadeStyle.Color.accentMagenta : ArcadeStyle.Color.textMuted)
        volumeSlider.setValue(settings.masterVolume, notify: false)
        volumeValueLabel.text = "\(Int(round(settings.masterVolume * 100)))%"
    }

    func applyLayout(in sceneSize: CGSize, safeInsets: UIEdgeInsets) {
        scrimNode.size = sceneSize
        scrimNode.position = .zero

        let safeWidth = sceneSize.width - safeInsets.left - safeInsets.right
        let cardSize = CGSize(width: min(336, safeWidth - 36), height: 312)
        cardNode.texture = TextureFactory.shared.cardTexture(size: cardSize, style: .overlay)
        cardNode.size = cardSize
        cardNode.position = CGPoint(x: 0, y: 0)

        titleLabel.position = CGPoint(x: 0, y: cardSize.height / 2 - 42)
        subtitleLabel.position = CGPoint(x: 0, y: cardSize.height / 2 - 66)

        let leftX = -cardSize.width / 2 + 24
        let rightX = cardSize.width / 2 - 24
        vibrationLabel.position = CGPoint(x: leftX, y: 62)
        vibrationToggle.position = CGPoint(x: rightX - vibrationToggle.size.width / 2, y: 62)

        volumeLabel.position = CGPoint(x: leftX, y: 14)
        volumeValueLabel.position = CGPoint(x: rightX, y: 14)
        volumeSlider.position = CGPoint(x: 0, y: -18)
        volumeSlider.applySize(cardSize.width - 56)

        effectsLabel.position = CGPoint(x: leftX, y: -72)
        effectsToggle.position = CGPoint(x: rightX - effectsToggle.size.width / 2, y: -72)

        musicLabel.position = CGPoint(x: leftX, y: -118)
        musicToggle.position = CGPoint(x: rightX - musicToggle.size.width / 2, y: -118)

        closeButton.position = CGPoint(x: 0, y: -cardSize.height / 2 + 34)
    }

    func button(at scenePoint: CGPoint, in scene: SKScene) -> ArcadeButtonNode? {
        let buttons = [closeButton, vibrationToggle, effectsToggle, musicToggle]
        for button in buttons where button.hitTest(scenePoint, in: scene) {
            return button
        }
        return nil
    }

    func slider(at scenePoint: CGPoint, in scene: SKScene) -> VolumeSliderNode? {
        volumeSlider.hitTest(scenePoint, in: scene) ? volumeSlider : nil
    }
}

private final class DailyPromptOverlayNode: SKNode {
    private let scrimNode = SKSpriteNode(color: SKColor(white: 0.0, alpha: 0.58), size: .zero)
    private let cardNode = SKSpriteNode()
    private let titleLabel = SKLabelNode(fontNamed: ArcadeFont.header)
    private let bodyLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let rewardLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    let playButton = ArcadeButtonNode(text: "PLAY NOW", size: CGSize(width: 150, height: 46))
    let laterButton = ArcadeButtonNode(text: "LATER", size: CGSize(width: 110, height: 46))

    var onPlay: (() -> Void)?
    var onLater: (() -> Void)?

    override init() {
        super.init()

        zPosition = 120

        scrimNode.zPosition = 0
        addChild(scrimNode)

        cardNode.zPosition = 1
        addChild(cardNode)

        titleLabel.fontSize = 24
        titleLabel.fontColor = ArcadeStyle.Color.textPrimary
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode = .center
        titleLabel.zPosition = 4
        cardNode.addChild(titleLabel)

        bodyLabel.fontSize = 12
        bodyLabel.fontColor = ArcadeStyle.Color.textSecondary
        bodyLabel.horizontalAlignmentMode = .center
        bodyLabel.verticalAlignmentMode = .center
        bodyLabel.zPosition = 4
        cardNode.addChild(bodyLabel)

        rewardLabel.fontSize = 11
        rewardLabel.fontColor = ArcadeStyle.Color.accentYellow
        rewardLabel.horizontalAlignmentMode = .center
        rewardLabel.verticalAlignmentMode = .center
        rewardLabel.zPosition = 4
        cardNode.addChild(rewardLabel)

        playButton.setAccentColor(ArcadeStyle.Color.accentYellow)
        laterButton.setAccentColor(ArcadeStyle.Color.accentCyan)
        playButton.onTap = { [weak self] in self?.onPlay?() }
        laterButton.onTap = { [weak self] in self?.onLater?() }
        cardNode.addChild(playButton)
        cardNode.addChild(laterButton)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func refresh() {
        let descriptor = DailyChallengeStore.shared.currentDescriptor()
        titleLabel.text = "DAILY CHALLENGE"
        bodyLabel.text = "A fresh race is live today."
        rewardLabel.text = "EASY +\(descriptor.easyReward)  •  HARD +\(descriptor.hardReward)"
    }

    func applyLayout(in sceneSize: CGSize, safeInsets: UIEdgeInsets) {
        scrimNode.size = sceneSize
        scrimNode.position = .zero

        let safeWidth = sceneSize.width - safeInsets.left - safeInsets.right
        let cardSize = CGSize(width: min(320, safeWidth - 40), height: 204)
        cardNode.texture = TextureFactory.shared.cardTexture(size: cardSize, style: .overlay)
        cardNode.size = cardSize
        cardNode.position = CGPoint(x: 0, y: 0)

        titleLabel.position = CGPoint(x: 0, y: cardSize.height / 2 - 40)
        bodyLabel.position = CGPoint(x: 0, y: 24)
        rewardLabel.position = CGPoint(x: 0, y: -2)

        playButton.position = CGPoint(x: -48, y: -cardSize.height / 2 + 38)
        laterButton.position = CGPoint(x: 88, y: -cardSize.height / 2 + 38)
    }

    func button(at scenePoint: CGPoint, in scene: SKScene) -> ArcadeButtonNode? {
        if playButton.hitTest(scenePoint, in: scene) {
            return playButton
        }
        if laterButton.hitTest(scenePoint, in: scene) {
            return laterButton
        }
        return nil
    }
}

private final class ChallengeDurationCardNode: SKNode {
    let duration: TimeChallengeDuration
    let button: ArcadeButtonNode

    private let titleLabel = SKLabelNode(fontNamed: ArcadeFont.header)
    private let bestLabel = SKLabelNode(fontNamed: ArcadeFont.digits)
    private let detailLabel = SKLabelNode(fontNamed: ArcadeFont.body)

    init(duration: TimeChallengeDuration) {
        self.duration = duration
        self.button = ArcadeButtonNode(text: "", size: CGSize(width: 280, height: 92))
        super.init()

        button.setAccentColor(ArcadeStyle.Color.accentCyan)
        addChild(button)

        titleLabel.fontSize = 20
        titleLabel.fontColor = ArcadeStyle.Color.textPrimary
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.verticalAlignmentMode = .center
        titleLabel.zPosition = 4
        button.addChild(titleLabel)

        bestLabel.fontSize = 14
        bestLabel.fontColor = ArcadeStyle.Color.accentYellow
        bestLabel.horizontalAlignmentMode = .right
        bestLabel.verticalAlignmentMode = .center
        bestLabel.zPosition = 4
        button.addChild(bestLabel)

        detailLabel.fontSize = 10
        detailLabel.fontColor = ArcadeStyle.Color.textSecondary
        detailLabel.horizontalAlignmentMode = .left
        detailLabel.verticalAlignmentMode = .center
        detailLabel.zPosition = 4
        button.addChild(detailLabel)

        refresh()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func applySize(_ size: CGSize) {
        button.size = snapSize(size)
        layoutContent()
    }

    func refresh() {
        let best = ChallengeStore.shared.best(for: duration)
        titleLabel.text = duration.title
        bestLabel.text = "BEST \(best)"
        detailLabel.text = duration.summaryLine
        layoutContent()
    }

    private func layoutContent() {
        let width = button.size.width
        titleLabel.position = snap(CGPoint(x: -width / 2 + 18, y: 10))
        bestLabel.position = snap(CGPoint(x: width / 2 - 18, y: 10))
        detailLabel.position = snap(CGPoint(x: -width / 2 + 18, y: -14))
    }

    private func snap(_ point: CGPoint) -> CGPoint {
        CGPoint(x: round(point.x), y: round(point.y))
    }

    private func snapSize(_ size: CGSize) -> CGSize {
        CGSize(width: round(size.width), height: round(size.height))
    }
}

private final class ShopItemCardNode: SKNode {
    let item: ShopItem
    let button: ArcadeButtonNode

    private let previewContainer = SKNode()
    private let titleLabel = SKLabelNode(fontNamed: ArcadeFont.header)
    private let detailLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let statusLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let badgeLabel = SKLabelNode(fontNamed: ArcadeFont.body)

    init(item: ShopItem) {
        self.item = item
        self.button = ArcadeButtonNode(text: "", size: CGSize(width: 160, height: 186))
        super.init()

        button.setAccentColor(item.accentColor)
        addChild(button)

        previewContainer.zPosition = 4
        button.addChild(previewContainer)

        titleLabel.fontSize = 14
        titleLabel.fontColor = ArcadeStyle.Color.textPrimary
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode = .center
        titleLabel.zPosition = 5
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byWordWrapping
        button.addChild(titleLabel)

        detailLabel.fontSize = 8
        detailLabel.fontColor = ArcadeStyle.Color.textSecondary
        detailLabel.horizontalAlignmentMode = .center
        detailLabel.verticalAlignmentMode = .center
        detailLabel.zPosition = 5
        detailLabel.numberOfLines = 2
        detailLabel.lineBreakMode = .byWordWrapping
        button.addChild(detailLabel)

        statusLabel.fontSize = 10
        statusLabel.fontColor = ArcadeStyle.Color.accentYellow
        statusLabel.horizontalAlignmentMode = .center
        statusLabel.verticalAlignmentMode = .center
        statusLabel.zPosition = 5
        statusLabel.numberOfLines = 1
        button.addChild(statusLabel)

        badgeLabel.fontSize = 9
        badgeLabel.fontColor = ArcadeStyle.Color.textMuted
        badgeLabel.horizontalAlignmentMode = .center
        badgeLabel.verticalAlignmentMode = .center
        badgeLabel.zPosition = 5
        badgeLabel.numberOfLines = 1
        button.addChild(badgeLabel)

        rebuildPreview()
        refresh()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func applySize(_ size: CGSize) {
        button.size = snapSize(size)
        layoutContent()
        rebuildPreview()
    }

    func refresh() {
        titleLabel.text = item.displayName
        detailLabel.text = item.detail
        statusLabel.text = CosmeticsStore.shared.statusText(for: item)
        if CosmeticsStore.shared.isEquipped(item) {
            statusLabel.fontColor = ArcadeStyle.Color.accentCyan
        } else if CosmeticsStore.shared.isOwned(item) {
            statusLabel.fontColor = ArcadeStyle.Color.textPrimary
        } else if item.rewardLevel != nil {
            statusLabel.fontColor = ArcadeStyle.Color.accentMagenta
        } else {
            statusLabel.fontColor = ArcadeStyle.Color.accentYellow
        }
        badgeLabel.text = badgeText()
        button.setAccentColor(item.accentColor)
        layoutContent()
    }

    func contains(_ scenePoint: CGPoint, in scene: SKScene) -> Bool {
        button.hitTest(scenePoint, in: scene)
    }

    private func badgeText() -> String {
        switch item {
        case let .player(skin):
            return skin.kind == .color ? "PLAYER COLOR" : "PLAYER PATTERN"
        case .trail:
            return "TRAIL + COMBO REACT"
        case .win:
            return "GOAL FINISH FX"
        case .teleporter:
            return "PORTAL LOOK"
        }
    }

    private func layoutContent() {
        let width = button.size.width
        let height = button.size.height
        let topY = height / 2
        badgeLabel.position = snap(CGPoint(x: 0, y: topY - 18))
        previewContainer.position = snap(CGPoint(x: 0, y: topY - 64))
        titleLabel.position = snap(CGPoint(x: 0, y: -6))
        detailLabel.position = snap(CGPoint(x: 0, y: -34))
        statusLabel.position = snap(CGPoint(x: 0, y: -height / 2 + 24))
        titleLabel.preferredMaxLayoutWidth = width * 0.8
        detailLabel.preferredMaxLayoutWidth = width * 0.76
        statusLabel.preferredMaxLayoutWidth = width * 0.8
        badgeLabel.preferredMaxLayoutWidth = width * 0.76
    }

    private func rebuildPreview() {
        previewContainer.removeAllChildren()
        switch item {
        case let .player(skin):
            let sprite = SKSpriteNode(texture: TextureFactory.shared.playerTexture(size: CGSize(width: 42, height: 42)))
            CosmeticRenderer.applyPlayerSkin(skin, to: sprite, displayScale: TextureFactory.shared.displayScale)
            previewContainer.addChild(sprite)
        case let .trail(style):
            let player = SKSpriteNode(texture: TextureFactory.shared.playerTexture(size: CGSize(width: 34, height: 34)))
            CosmeticRenderer.applyPlayerSkin(CosmeticsStore.shared.selectedPlayerSkin, to: player, displayScale: TextureFactory.shared.displayScale)
            player.position = CGPoint(x: 12, y: 0)
            previewContainer.addChild(player)

            for index in 0..<4 {
                let size = CGSize(width: 12, height: 12)
                let particle = SKSpriteNode(texture: TextureFactory.shared.trailParticleTexture(size: size, style: style))
                particle.position = CGPoint(x: -20 - CGFloat(index) * 10, y: CGFloat(index % 2 == 0 ? 4 : -4))
                particle.alpha = 0.85 - CGFloat(index) * 0.12
                particle.blendMode = .add
                previewContainer.addChild(particle)
                particle.run(.repeatForever(.sequence([
                    .group([
                        .fadeAlpha(to: 0.25, duration: 0.55),
                        .moveBy(x: -6, y: 0, duration: 0.55)
                    ]),
                    .group([
                        .fadeAlpha(to: 0.85 - CGFloat(index) * 0.12, duration: 0.0),
                        .moveBy(x: 6, y: 0, duration: 0.0)
                    ])
                ])))
            }

            if style == .orbitTrail {
                for index in 0..<3 {
                    let orbit = SKNode()
                    orbit.zRotation = CGFloat(index) * (.pi * 2 / 3)
                    let dot = SKSpriteNode(texture: TextureFactory.shared.trailParticleTexture(size: CGSize(width: 8, height: 8), style: .orbitTrail))
                    dot.position = CGPoint(x: 22, y: 0)
                    orbit.addChild(dot)
                    orbit.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 1.8 + Double(index) * 0.25)))
                    player.addChild(orbit)
                }
            }
        case let .win(style):
            let goal = SKSpriteNode(texture: TextureFactory.shared.exitTexture(size: CGSize(width: 34, height: 34)))
            goal.position = .zero
            previewContainer.addChild(goal)

            switch style {
            case .neonExplosion:
                for index in 0..<6 {
                    let dot = SKSpriteNode(texture: TextureFactory.shared.trailParticleTexture(size: CGSize(width: 8, height: 8), style: .classicNeon))
                    dot.position = .zero
                    dot.alpha = 0.9
                    previewContainer.addChild(dot)
                    let angle = CGFloat(index) / 6 * .pi * 2
                    dot.run(.repeatForever(.sequence([
                        .group([
                            .moveBy(x: cos(angle) * 20, y: sin(angle) * 20, duration: 0.45),
                            .fadeOut(withDuration: 0.45)
                        ]),
                        .group([
                            .move(to: .zero, duration: 0.0),
                            .fadeAlpha(to: 0.9, duration: 0.0)
                        ])
                    ])))
                }
            case .energyImplosion:
                let ring = SKShapeNode(circleOfRadius: 18)
                ring.strokeColor = item.accentColor
                ring.lineWidth = 2
                ring.glowWidth = 6
                ring.fillColor = .clear
                previewContainer.addChild(ring)
                ring.run(.repeatForever(.sequence([
                    .group([.scale(to: 0.62, duration: 0.38), .fadeAlpha(to: 1.0, duration: 0.38)]),
                    .group([.scale(to: 1.0, duration: 0.28), .fadeAlpha(to: 0.28, duration: 0.28)])
                ])))
            case .pixelShatter:
                for x in -1...1 {
                    for y in -1...1 where !(x == 0 && y == 0) {
                        let block = SKSpriteNode(texture: TextureFactory.shared.trailParticleTexture(size: CGSize(width: 8, height: 8), style: .pixelTrail))
                        block.position = .zero
                        previewContainer.addChild(block)
                        block.run(.repeatForever(.sequence([
                            .group([
                                .moveBy(x: CGFloat(x) * 10, y: CGFloat(y) * 10, duration: 0.42),
                                .fadeOut(withDuration: 0.42)
                            ]),
                            .group([
                                .move(to: .zero, duration: 0.0),
                                .fadeAlpha(to: 1.0, duration: 0.0)
                            ])
                        ])))
                    }
                }
            case .shockwaveRing:
                let ring = SKShapeNode(circleOfRadius: 8)
                ring.strokeColor = item.accentColor
                ring.lineWidth = 2
                ring.glowWidth = 8
                ring.fillColor = .clear
                previewContainer.addChild(ring)
                ring.run(.repeatForever(.sequence([
                    .group([.scale(to: 2.0, duration: 0.55), .fadeOut(withDuration: 0.55)]),
                    .group([.scale(to: 0.4, duration: 0.0), .fadeAlpha(to: 0.95, duration: 0.0)])
                ])))
            case .lightBeamFinish:
                let beam = SKSpriteNode(color: item.accentColor.withAlphaComponent(0.42), size: CGSize(width: 18, height: 48))
                beam.position = CGPoint(x: 0, y: 6)
                beam.zPosition = -1
                beam.blendMode = .add
                previewContainer.addChild(beam)
                beam.run(.repeatForever(.sequence([
                    .group([.fadeAlpha(to: 0.85, duration: 0.35), .scaleY(to: 1.1, duration: 0.35)]),
                    .group([.fadeAlpha(to: 0.3, duration: 0.35), .scaleY(to: 0.9, duration: 0.35)])
                ])))
            }
        case let .teleporter(style):
            let portal = SKSpriteNode(texture: TextureFactory.shared.teleporterTexture(size: CGSize(width: 40, height: 40), style: style, accentColor: item.accentColor))
            CosmeticRenderer.configureTeleporterNode(portal, key: "A", skin: style, tileSize: 34, accentColor: item.accentColor)
            previewContainer.addChild(portal)
        }
    }

    private func snap(_ point: CGPoint) -> CGPoint {
        CGPoint(x: round(point.x), y: round(point.y))
    }

    private func snapSize(_ size: CGSize) -> CGSize {
        CGSize(width: round(size.width), height: round(size.height))
    }
}

final class ChallengeSelectScene: SKScene {
    private let cameraNode = SKCameraNode()
    private let hudNode = SKNode()
    private let topBar = TopBarNode(title: "TIME CHALLENGE")
    private let subtitleLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let footerLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let contentNode = SKNode()
    private let optionNodes = TimeChallengeDuration.allCases.map { ChallengeDurationCardNode(duration: $0) }

    private var menuBackdropNode: MenuBackdropNode?
    private var safeInsets: UIEdgeInsets = .zero
    private var activeButton: ArcadeButtonNode?
    private var touchStartPoint: CGPoint?
    private var isTransitioning = false

    override func didMove(to view: SKView) {
        backgroundColor = .black
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        SoundFX.syncAudioState()
        updateSafeInsets()
        buildScene()
        refreshContent()
        layoutScene()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        updateSafeInsets()
        layoutScene()
    }

    private func buildScene() {
        removeAllChildren()
        camera = cameraNode
        addChild(cameraNode)

        let backdrop = MenuBackdropNode(size: size, titleAnchorY: topBar.position.y - 52)
        menuBackdropNode = backdrop
        cameraNode.addChild(backdrop)

        cameraNode.addChild(hudNode)
        cameraNode.addChild(contentNode)

        topBar.backButton.onTap = { [weak self] in
            self?.presentStartScene()
        }
        hudNode.addChild(topBar)

        subtitleLabel.text = "Pick a clock. Clear as many mazes as you can before time runs out."
        subtitleLabel.fontSize = 12
        subtitleLabel.fontColor = ArcadeStyle.Color.textSecondary
        subtitleLabel.horizontalAlignmentMode = .center
        subtitleLabel.verticalAlignmentMode = .center
        subtitleLabel.zPosition = 10
        contentNode.addChild(subtitleLabel)

        footerLabel.text = "NO COINS · PURE RECORD CHASE · QUICK RESTARTS"
        footerLabel.fontSize = 10
        footerLabel.fontColor = ArcadeStyle.Color.textMuted
        footerLabel.horizontalAlignmentMode = .center
        footerLabel.verticalAlignmentMode = .center
        footerLabel.zPosition = 10
        contentNode.addChild(footerLabel)

        for node in optionNodes {
            node.button.onTap = { [weak self, weak node] in
                guard let self, let node else { return }
                self.openChallenge(duration: node.duration)
            }
            contentNode.addChild(node)
        }
    }

    private func refreshContent() {
        optionNodes.forEach { $0.refresh() }
    }

    private func layoutScene() {
        let safeTop = size.height / 2 - safeInsets.top
        let safeBottom = -size.height / 2 + safeInsets.bottom
        let safeWidth = size.width - safeInsets.left - safeInsets.right
        let topBarHeight = clamp(54, 60, size.height * 0.074)
        let topBarWidth = max(260, safeWidth - 24)
        let topBarY = safeTop - 10 - topBarHeight / 2
        topBar.position = snap(CGPoint(x: 0, y: topBarY))
        topBar.layout(width: topBarWidth, height: topBarHeight)

        subtitleLabel.position = snap(CGPoint(x: 0, y: topBarY - topBarHeight / 2 - 22))
        footerLabel.position = snap(CGPoint(x: 0, y: safeBottom + 18))

        let cardWidth = min(safeWidth - 40, 336)
        let cardHeight: CGFloat = 88
        let spacing: CGFloat = 14
        let totalHeight = CGFloat(optionNodes.count) * cardHeight + CGFloat(optionNodes.count - 1) * spacing
        let centerY = (subtitleLabel.position.y - 28 + footerLabel.position.y + 40) / 2
        let startY = centerY + totalHeight / 2 - cardHeight / 2

        for (index, node) in optionNodes.enumerated() {
            node.applySize(CGSize(width: cardWidth, height: cardHeight))
            node.position = snap(CGPoint(x: 0, y: startY - CGFloat(index) * (cardHeight + spacing)))
        }
        menuBackdropNode?.update(size: size, titleAnchorY: subtitleLabel.position.y + 22)
    }

    private func openChallenge(duration: TimeChallengeDuration) {
        guard let view = view, !isTransitioning else { return }
        isTransitioning = true
        fireHaptic(style: .medium)
        SoundFX.play(.popupOpen, on: self)
        let scene = GameScene(size: size, levelIndex: 0, runMode: .timeChallenge(duration))
        scene.scaleMode = .resizeFill
        view.presentScene(scene, transition: .fade(withDuration: 0.25))
    }

    private func presentStartScene() {
        guard let view = view, !isTransitioning else { return }
        isTransitioning = true
        SoundFX.play(.popupClose, on: self)
        let scene = StartScene(size: size)
        scene.scaleMode = .resizeFill
        view.presentScene(scene, transition: .fade(withDuration: 0.25))
    }

    private func updateSafeInsets() {
        if let windowInsets = view?.window?.safeAreaInsets, windowInsets != .zero {
            safeInsets = windowInsets
        } else {
            safeInsets = view?.safeAreaInsets ?? .zero
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self), let button = buttonAt(point) else { return }
        touchStartPoint = point
        activeButton = button
        button.setPressed(true)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let button = activeButton, let point = touches.first?.location(in: self) else { return }
        button.setPressed(button.hitTest(point, in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let button = activeButton, let point = touches.first?.location(in: self) else {
            activeButton?.setPressed(false)
            activeButton = nil
            touchStartPoint = nil
            return
        }
        let movement = touchStartPoint.map { hypot(point.x - $0.x, point.y - $0.y) } ?? 0
        let shouldTap = button.hitTest(point, in: self) || movement <= 14
        button.setPressed(false)
        activeButton = nil
        touchStartPoint = nil
        if shouldTap {
            button.onTap?()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeButton?.setPressed(false)
        activeButton = nil
        touchStartPoint = nil
    }

    private func buttonAt(_ point: CGPoint) -> ArcadeButtonNode? {
        if topBar.backButton.hitTest(point, in: self) {
            return topBar.backButton
        }
        for node in optionNodes where node.button.hitTest(point, in: self) {
            return node.button
        }
        return nil
    }

    private func fireHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        Haptics.impact(style)
    }

    private func snap(_ point: CGPoint) -> CGPoint {
        CGPoint(x: round(point.x), y: round(point.y))
    }

    private func clamp(_ minValue: CGFloat, _ maxValue: CGFloat, _ value: CGFloat) -> CGFloat {
        min(maxValue, max(minValue, value))
    }
}

fileprivate final class MenuBackdropNode: SKNode {
    private struct Metric {
        static let vignetteAlpha: CGFloat = 0.25
        static let energyFieldAlpha: CGFloat = 0.15
        static let energyAccentAlpha: CGFloat = 0.06
        static let gridAlpha: CGFloat = 0.07
        static let gridSpeed: CGFloat = 8.0
        static let farParticleCount = 26
        static let mediumParticleCount = 12
        static let nearParticleCount = 5
        static let floatingAccentCount = 10
        static let sparkleCount = 8
    }

    private let backgroundNode = SKSpriteNode()
    private let gridNode = SKSpriteNode()
    private let gridNodeSecondary = SKSpriteNode()
    private let energyFieldNode = SKSpriteNode()
    private let depthGradientNode = SKSpriteNode()
    private let ambientGlowLeft = SKSpriteNode(color: ArcadeStyle.Color.accentCyan.withAlphaComponent(0.08), size: .zero)
    private let ambientGlowRight = SKSpriteNode(color: ArcadeStyle.Color.accentMagenta.withAlphaComponent(0.07), size: .zero)
    private let ambientMazeNode = SKNode()
    private let ambientRouteNode = SKNode()
    private let floatingAccentNode = SKNode()
    private let deepParticleNode = SKNode()
    private let accentParticleNode = SKNode()
    private let particleNode = SKNode()
    private let sparkleNode = SKNode()
    private let streakA = SKSpriteNode(color: .white, size: .zero)
    private let streakB = SKSpriteNode(color: .white, size: .zero)
    private let streakC = SKSpriteNode(color: .white, size: .zero)
    private let vignetteNode = SKSpriteNode(color: .black, size: .zero)

    private var backdropSize: CGSize = .zero
    private var titleAnchorY: CGFloat = 0

    init(size: CGSize, titleAnchorY: CGFloat) {
        self.backdropSize = size
        self.titleAnchorY = titleAnchorY
        super.init()
        isUserInteractionEnabled = false
        build()
        update(size: size, titleAnchorY: titleAnchorY)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func update(size: CGSize, titleAnchorY: CGFloat) {
        backdropSize = size
        self.titleAnchorY = titleAnchorY
        refreshTextures()
        layoutPresentation()
    }

    private func build() {
        let nodes: [(SKNode, CGFloat)] = [
            (backgroundNode, -220),
            (gridNode, -210),
            (gridNodeSecondary, -210),
            (ambientMazeNode, -203),
            (ambientRouteNode, -202),
            (floatingAccentNode, -201),
            (deepParticleNode, -200),
            (accentParticleNode, -199),
            (energyFieldNode, -198),
            (depthGradientNode, -197),
            (ambientGlowLeft, -196),
            (ambientGlowRight, -196),
            (sparkleNode, -195),
            (particleNode, -193),
            (streakA, -192),
            (streakB, -191),
            (streakC, -190),
            (vignetteNode, -189)
        ]
        for (node, z) in nodes {
            node.zPosition = z
            addChild(node)
        }

        energyFieldNode.blendMode = .add
        depthGradientNode.blendMode = .add
        ambientGlowLeft.blendMode = .add
        ambientGlowRight.blendMode = .add
        streakA.blendMode = .add
        streakB.blendMode = .add
        streakC.blendMode = .add

        configureMotionNodes()
    }

    private func refreshTextures() {
        backgroundNode.texture = StartScene.makeMenuBaseTexture(
            size: backdropSize,
            top: SKColor(hex: 0x070B14),
            middle: SKColor(hex: 0x090F1C),
            bottom: SKColor(hex: 0x05070D)
        )
        backgroundNode.size = backdropSize
        backgroundNode.position = .zero

        vignetteNode.texture = StartScene.makeVignetteTexture(size: backdropSize, edgeAlpha: Metric.vignetteAlpha)
        vignetteNode.size = backdropSize
        vignetteNode.position = .zero

        let screenScale = resolvedScreenScale()
        let gridSize = snapSize(CGSize(width: backdropSize.width * 1.18, height: backdropSize.height * 1.18))
        let gridTexture = StartScene.makeGridTexture(
            size: gridSize,
            spacing: CGSize(width: 34, height: 34),
            lineWidth: 1.0 / screenScale,
            color: SKColor(hex: 0x00D4FF),
            alpha: Metric.gridAlpha,
            scale: screenScale
        )
        gridNode.texture = gridTexture
        gridNode.size = gridSize
        gridNodeSecondary.texture = gridTexture
        gridNodeSecondary.size = gridSize

        let coreSize = snapSize(CGSize(width: backdropSize.width * 0.58, height: backdropSize.height * 0.22))
        energyFieldNode.texture = StartScene.makeRadialGlowTexture(
            size: coreSize,
            color: SKColor(hex: 0x00D4FF),
            innerAlpha: 0.92,
            outerAlpha: 0.0
        )
        energyFieldNode.size = coreSize
        energyFieldNode.alpha = Metric.energyFieldAlpha

        let accentSize = snapSize(CGSize(width: coreSize.width * 0.74, height: coreSize.height * 0.84))
        depthGradientNode.texture = StartScene.makeRadialGlowTexture(
            size: accentSize,
            color: SKColor(hex: 0xFF2D9A),
            innerAlpha: 0.76,
            outerAlpha: 0.0
        )
        depthGradientNode.size = accentSize
        depthGradientNode.alpha = Metric.energyAccentAlpha

        let sideGlowSize = snapSize(CGSize(width: backdropSize.width * 0.28, height: backdropSize.height * 0.16))
        ambientGlowLeft.texture = StartScene.makeRadialGlowTexture(
            size: sideGlowSize,
            color: SKColor(hex: 0x00D4FF),
            innerAlpha: 0.48,
            outerAlpha: 0.0
        )
        ambientGlowLeft.size = sideGlowSize
        ambientGlowLeft.alpha = 0.08

        ambientGlowRight.texture = StartScene.makeRadialGlowTexture(
            size: sideGlowSize,
            color: SKColor(hex: 0xFF2D9A),
            innerAlpha: 0.44,
            outerAlpha: 0.0
        )
        ambientGlowRight.size = sideGlowSize
        ambientGlowRight.alpha = 0.06

        streakA.texture = StartScene.makeAmbientStreakTexture(
            size: CGSize(width: max(54, backdropSize.width * 0.14), height: backdropSize.height * 0.72),
            tint: SKColor(hex: 0x00D4FF)
        )
        streakA.size = snapSize(CGSize(width: max(54, backdropSize.width * 0.14), height: backdropSize.height * 0.72))

        streakB.texture = StartScene.makeAmbientStreakTexture(
            size: CGSize(width: max(46, backdropSize.width * 0.12), height: backdropSize.height * 0.64),
            tint: SKColor(hex: 0xFF2D9A)
        )
        streakB.size = snapSize(CGSize(width: max(46, backdropSize.width * 0.12), height: backdropSize.height * 0.64))

        streakC.texture = StartScene.makeAmbientStreakTexture(
            size: CGSize(width: max(42, backdropSize.width * 0.10), height: backdropSize.height * 0.56),
            tint: SKColor(hex: 0x00D4FF)
        )
        streakC.size = snapSize(CGSize(width: max(42, backdropSize.width * 0.10), height: backdropSize.height * 0.56))
    }

    private func layoutPresentation() {
        let titleCenter = snap(CGPoint(x: 0, y: titleAnchorY))
        energyFieldNode.position = titleCenter
        depthGradientNode.position = snap(CGPoint(x: 10, y: titleCenter.y - 4))
        ambientGlowLeft.position = snap(CGPoint(x: -backdropSize.width * 0.22, y: titleCenter.y - 12))
        ambientGlowRight.position = snap(CGPoint(x: backdropSize.width * 0.22, y: titleCenter.y - 8))

        let gridHeight = gridNode.size.height
        gridNode.position = .zero
        gridNodeSecondary.position = CGPoint(x: 0, y: gridHeight)

        streakA.position = snap(CGPoint(x: -backdropSize.width * 0.34, y: -backdropSize.height * 0.30))
        streakA.zRotation = -.pi / 6.2
        streakB.position = snap(CGPoint(x: backdropSize.width * 0.30, y: -backdropSize.height * 0.34))
        streakB.zRotation = -.pi / 5.7
        streakC.position = snap(CGPoint(x: 0, y: -backdropSize.height * 0.42))
        streakC.zRotation = -.pi / 6.0
    }

    private func configureMotionNodes() {
        ambientMazeNode.removeAllChildren()
        ambientRouteNode.removeAllChildren()
        floatingAccentNode.removeAllChildren()
        deepParticleNode.removeAllChildren()
        accentParticleNode.removeAllChildren()
        particleNode.removeAllChildren()
        sparkleNode.removeAllChildren()

        configureAmbientMazeWorld()
        configureFloatingAccentLayer()
        for _ in 0..<Metric.farParticleCount { spawnDeepParticle() }
        for _ in 0..<Metric.mediumParticleCount { spawnAccentParticle() }
        for _ in 0..<Metric.nearParticleCount { spawnNearParticle() }
        for _ in 0..<Metric.sparkleCount { spawnSparkle() }

        energyFieldNode.removeAllActions()
        depthGradientNode.removeAllActions()
        ambientGlowLeft.removeAllActions()
        ambientGlowRight.removeAllActions()
        gridNode.removeAllActions()
        gridNodeSecondary.removeAllActions()
        streakA.removeAllActions()
        streakB.removeAllActions()
        streakC.removeAllActions()
        ambientMazeNode.removeAllActions()
        ambientRouteNode.removeAllActions()
        floatingAccentNode.removeAllActions()

        energyFieldNode.run(.repeatForever(.sequence([
            .group([.fadeAlpha(to: Metric.energyFieldAlpha * 1.08, duration: 3.1), .scale(to: 1.06, duration: 3.1)]),
            .group([.fadeAlpha(to: Metric.energyFieldAlpha * 0.92, duration: 3.1), .scale(to: 1.0, duration: 3.1)])
        ])), withKey: "energyPulse")
        depthGradientNode.run(.repeatForever(.sequence([
            .group([.fadeAlpha(to: Metric.energyAccentAlpha * 1.12, duration: 3.4), .scale(to: 1.04, duration: 3.4)]),
            .group([.fadeAlpha(to: Metric.energyAccentAlpha * 0.9, duration: 3.2), .scale(to: 1.0, duration: 3.2)])
        ])), withKey: "accentPulse")
        ambientGlowLeft.run(.repeatForever(.sequence([
            .group([.fadeAlpha(to: 0.11, duration: 4.0), .scale(to: 1.07, duration: 4.0)]),
            .group([.fadeAlpha(to: 0.07, duration: 4.6), .scale(to: 1.0, duration: 4.6)])
        ])), withKey: "sideGlowPulse")
        ambientGlowRight.run(.repeatForever(.sequence([
            .group([.fadeAlpha(to: 0.09, duration: 4.6), .scale(to: 1.05, duration: 4.6)]),
            .group([.fadeAlpha(to: 0.06, duration: 4.8), .scale(to: 1.0, duration: 4.8)])
        ])), withKey: "sideGlowPulse")

        let gridTravel = max(gridNode.size.height, 1)
        let gridDuration = Double(gridTravel / Metric.gridSpeed)
        let gridDrift = SKAction.repeatForever(.sequence([
            .moveBy(x: 0, y: -gridTravel, duration: gridDuration),
            .moveBy(x: 0, y: gridTravel, duration: 0)
        ]))
        gridNode.run(gridDrift, withKey: "gridDrift")
        gridNodeSecondary.run(gridDrift, withKey: "gridDrift")

        configureAmbientDrift(streakA, baseAlpha: 0.052, drift: CGPoint(x: 10, y: -12), duration: 19.0)
        configureAmbientDrift(streakB, baseAlpha: 0.043, drift: CGPoint(x: -8, y: 10), duration: 21.0)
        configureAmbientDrift(streakC, baseAlpha: 0.036, drift: CGPoint(x: 6, y: -8), duration: 24.0)

        ambientMazeNode.run(.repeatForever(.sequence([
            .moveBy(x: 8, y: -10, duration: 10.0),
            .moveBy(x: -8, y: 10, duration: 10.0)
        ])), withKey: "ambientMazeDrift")
        ambientRouteNode.run(.repeatForever(.sequence([
            .moveBy(x: 6, y: -8, duration: 9.0),
            .moveBy(x: -6, y: 8, duration: 9.0)
        ])), withKey: "ambientRouteDrift")
        floatingAccentNode.run(.repeatForever(.sequence([
            .moveBy(x: -5, y: 7, duration: 11.0),
            .moveBy(x: 5, y: -7, duration: 11.0)
        ])), withKey: "floatingAccentDrift")
    }

    private func configureAmbientDrift(_ node: SKSpriteNode, baseAlpha: CGFloat, drift: CGPoint, duration: TimeInterval) {
        node.alpha = baseAlpha
        node.run(.repeatForever(.sequence([
            .group([.moveBy(x: drift.x, y: drift.y, duration: duration), .fadeAlpha(to: baseAlpha * 1.1, duration: duration)]),
            .group([.moveBy(x: -drift.x, y: -drift.y, duration: duration), .fadeAlpha(to: baseAlpha * 0.92, duration: duration)])
        ])), withKey: "ambientDrift")
    }

    private func configureAmbientMazeWorld() {
        let fragments: [(CGRect, SKColor, Double)] = [
            (CGRect(x: -backdropSize.width * 0.44, y: backdropSize.height * 0.14, width: backdropSize.width * 0.24, height: backdropSize.height * 0.12), ArcadeStyle.Color.accentCyan, 0.4),
            (CGRect(x: backdropSize.width * 0.20, y: backdropSize.height * 0.10, width: backdropSize.width * 0.24, height: backdropSize.height * 0.12), ArcadeStyle.Color.accentMagenta, 1.0),
            (CGRect(x: -backdropSize.width * 0.42, y: -backdropSize.height * 0.36, width: backdropSize.width * 0.26, height: backdropSize.height * 0.16), ArcadeStyle.Color.accentCyan, 0.2),
            (CGRect(x: backdropSize.width * 0.16, y: -backdropSize.height * 0.40, width: backdropSize.width * 0.26, height: backdropSize.height * 0.16), ArcadeStyle.Color.accentMagenta, 1.3),
            (CGRect(x: -backdropSize.width * 0.10, y: -backdropSize.height * 0.50, width: backdropSize.width * 0.20, height: backdropSize.height * 0.10), ArcadeStyle.Color.accentYellow, 1.8)
        ]
        for (rect, tint, delay) in fragments {
            addAmbientMazeFragment(in: rect, tint: tint, delay: delay)
        }

        let routeA = [
            CGPoint(x: -backdropSize.width * 0.42, y: backdropSize.height * 0.28),
            CGPoint(x: -backdropSize.width * 0.28, y: backdropSize.height * 0.28),
            CGPoint(x: -backdropSize.width * 0.28, y: backdropSize.height * 0.16),
            CGPoint(x: -backdropSize.width * 0.40, y: backdropSize.height * 0.16)
        ]
        let routeB = [
            CGPoint(x: backdropSize.width * 0.42, y: backdropSize.height * 0.26),
            CGPoint(x: backdropSize.width * 0.30, y: backdropSize.height * 0.26),
            CGPoint(x: backdropSize.width * 0.30, y: backdropSize.height * 0.14),
            CGPoint(x: backdropSize.width * 0.40, y: backdropSize.height * 0.14)
        ]
        let routeC = [
            CGPoint(x: -backdropSize.width * 0.36, y: -backdropSize.height * 0.24),
            CGPoint(x: -backdropSize.width * 0.14, y: -backdropSize.height * 0.24),
            CGPoint(x: -backdropSize.width * 0.14, y: -backdropSize.height * 0.40),
            CGPoint(x: backdropSize.width * 0.10, y: -backdropSize.height * 0.40)
        ]
        let routeD = [
            CGPoint(x: backdropSize.width * 0.34, y: -backdropSize.height * 0.12),
            CGPoint(x: backdropSize.width * 0.34, y: -backdropSize.height * 0.30),
            CGPoint(x: backdropSize.width * 0.20, y: -backdropSize.height * 0.30),
            CGPoint(x: backdropSize.width * 0.20, y: -backdropSize.height * 0.44)
        ]
        addAmbientRunner(path: routeA, tint: ArcadeStyle.Color.accentCyan, delay: 0.6)
        addAmbientRunner(path: routeB, tint: ArcadeStyle.Color.accentMagenta, delay: 1.1)
        addAmbientRunner(path: routeC, tint: ArcadeStyle.Color.accentYellow, delay: 1.6)
        addAmbientRunner(path: routeD, tint: ArcadeStyle.Color.accentCyan, delay: 2.0)
    }

    private func addAmbientMazeFragment(in rect: CGRect, tint: SKColor, delay: Double) {
        let path = makeAmbientMazePath(in: rect)
        let glow = SKShapeNode(path: path)
        glow.strokeColor = tint.withAlphaComponent(0.05)
        glow.lineWidth = 7
        glow.lineCap = .round
        glow.lineJoin = .round
        glow.alpha = 0.7
        ambientMazeNode.addChild(glow)

        let shape = SKShapeNode(path: path)
        shape.strokeColor = tint.withAlphaComponent(0.16)
        shape.lineWidth = 1.6
        shape.lineCap = .round
        shape.lineJoin = .round
        shape.alpha = 0.9
        ambientMazeNode.addChild(shape)

        shape.run(.repeatForever(.sequence([
            .wait(forDuration: delay),
            .fadeAlpha(to: 0.52, duration: 2.8),
            .fadeAlpha(to: 0.92, duration: 3.4)
        ])), withKey: "mazeBreathe")
        glow.run(.repeatForever(.sequence([
            .wait(forDuration: delay * 0.5),
            .fadeAlpha(to: 0.36, duration: 3.2),
            .fadeAlpha(to: 0.72, duration: 3.8)
        ])), withKey: "mazeGlow")

        for point in ambientPulsePoints(in: rect) {
            let pulse = SKSpriteNode(color: tint.withAlphaComponent(0.45), size: CGSize(width: 5, height: 5))
            pulse.position = point
            pulse.alpha = 0
            pulse.blendMode = .add
            ambientMazeNode.addChild(pulse)
            pulse.run(.repeatForever(.sequence([
                .wait(forDuration: delay + Double.random(in: 0.4...1.6)),
                .group([.fadeAlpha(to: 0.42, duration: 0.18), .scale(to: 1.6, duration: 0.18)]),
                .group([.fadeOut(withDuration: 0.5), .scale(to: 0.9, duration: 0.5)])
            ])))
        }
    }

    private func makeAmbientMazePath(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        let x0 = rect.minX
        let x1 = rect.minX + rect.width * 0.34
        let x2 = rect.minX + rect.width * 0.62
        let x3 = rect.maxX
        let y0 = rect.minY
        let y1 = rect.minY + rect.height * 0.32
        let y2 = rect.minY + rect.height * 0.66
        let y3 = rect.maxY

        path.move(to: CGPoint(x: x0, y: y1))
        path.addLine(to: CGPoint(x: x1, y: y1))
        path.addLine(to: CGPoint(x: x1, y: y3))
        path.addLine(to: CGPoint(x: x2, y: y3))
        path.addLine(to: CGPoint(x: x2, y: y2))
        path.addLine(to: CGPoint(x: x3, y: y2))

        path.move(to: CGPoint(x: x0, y: y0))
        path.addLine(to: CGPoint(x: x0, y: y2))
        path.addLine(to: CGPoint(x: x2, y: y2))

        path.move(to: CGPoint(x: x1, y: y0))
        path.addLine(to: CGPoint(x: x1, y: y1))
        path.addLine(to: CGPoint(x: x3, y: y1))
        return path
    }

    private func ambientPulsePoints(in rect: CGRect) -> [CGPoint] {
        [
            CGPoint(x: rect.minX + rect.width * 0.34, y: rect.minY + rect.height * 0.32),
            CGPoint(x: rect.minX + rect.width * 0.62, y: rect.minY + rect.height * 0.66),
            CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.66)
        ]
    }

    private func addAmbientRunner(path points: [CGPoint], tint: SKColor, delay: Double) {
        guard points.count >= 2 else { return }
        let routePath = CGMutablePath()
        routePath.move(to: points[0])
        for point in points.dropFirst() { routePath.addLine(to: point) }

        let routeGlow = SKShapeNode(path: routePath)
        routeGlow.strokeColor = tint.withAlphaComponent(0.05)
        routeGlow.lineWidth = 6
        routeGlow.lineCap = .round
        routeGlow.lineJoin = .round
        routeGlow.alpha = 0.6
        ambientRouteNode.addChild(routeGlow)

        let routeLine = SKShapeNode(path: routePath)
        routeLine.strokeColor = tint.withAlphaComponent(0.12)
        routeLine.lineWidth = 1.5
        routeLine.lineCap = .round
        routeLine.lineJoin = .round
        routeLine.alpha = 0.82
        ambientRouteNode.addChild(routeLine)

        let runner = SKSpriteNode(texture: TextureFactory.shared.playerTexture(size: CGSize(width: 16, height: 16)))
        runner.size = CGSize(width: 16, height: 16)
        runner.color = tint
        runner.colorBlendFactor = 0.28
        runner.alpha = 0.42
        runner.position = points[0]
        ambientRouteNode.addChild(runner)

        let pulse = SKSpriteNode(color: tint.withAlphaComponent(0.55), size: CGSize(width: 6, height: 6))
        pulse.alpha = 0
        pulse.blendMode = .add
        pulse.position = points[0]
        ambientRouteNode.addChild(pulse)

        let durations = zip(points, points.dropFirst()).map { start, end in
            max(0.7, Double(hypot(end.x - start.x, end.y - start.y) / 80.0))
        }

        var runnerActions: [SKAction] = [.wait(forDuration: delay)]
        for (index, point) in points.dropFirst().enumerated() {
            let moveDuration = durations[index]
            runnerActions.append(.group([
                .move(to: point, duration: moveDuration),
                .sequence([.fadeAlpha(to: 0.46, duration: moveDuration * 0.25), .fadeAlpha(to: 0.34, duration: moveDuration * 0.75)])
            ]))
        }
        runnerActions.append(.wait(forDuration: Double.random(in: 0.6...1.2)))
        runnerActions.append(.fadeOut(withDuration: 0.16))
        runnerActions.append(.run {
            runner.position = points[0]
            runner.alpha = 0.42
        })
        runner.run(.repeatForever(.sequence(runnerActions)), withKey: "ambientRunner")

        var pulseActions: [SKAction] = [.wait(forDuration: delay + 0.18)]
        for (index, point) in points.dropFirst().enumerated() {
            let moveDuration = durations[index]
            pulseActions.append(.group([
                .move(to: point, duration: moveDuration),
                .sequence([.fadeAlpha(to: 0.32, duration: moveDuration * 0.2), .fadeOut(withDuration: moveDuration * 0.8)]),
                .sequence([.scale(to: 1.8, duration: moveDuration * 0.22), .scale(to: 0.9, duration: moveDuration * 0.78)])
            ]))
        }
        pulseActions.append(.run {
            pulse.position = points[0]
            pulse.alpha = 0
            pulse.setScale(1.0)
        })
        pulseActions.append(.wait(forDuration: Double.random(in: 0.8...1.4)))
        pulse.run(.repeatForever(.sequence(pulseActions)), withKey: "ambientPulse")
    }

    private func configureFloatingAccentLayer() {
        for index in 0..<Metric.floatingAccentCount {
            let tintOptions = [ArcadeStyle.Color.accentCyan, ArcadeStyle.Color.accentMagenta, ArcadeStyle.Color.accentYellow]
            let tint = tintOptions[index % tintOptions.count]
            let accent: SKNode
            switch index % 4 {
            case 0:
                let sizeValue = CGFloat.random(in: 14...22)
                let frame = SKShapeNode(rectOf: CGSize(width: sizeValue, height: sizeValue), cornerRadius: 3)
                frame.strokeColor = tint.withAlphaComponent(0.24)
                frame.lineWidth = 1.0
                frame.fillColor = .clear
                accent = frame
            case 1:
                let width = CGFloat.random(in: 24...40)
                let height = CGFloat.random(in: 6...10)
                let capsule = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: height * 0.5)
                capsule.strokeColor = tint.withAlphaComponent(0.18)
                capsule.fillColor = tint.withAlphaComponent(0.06)
                capsule.lineWidth = 0.9
                accent = capsule
            case 2:
                let width = CGFloat.random(in: 18...34)
                let line = SKShapeNode(rectOf: CGSize(width: width, height: 2), cornerRadius: 1)
                line.strokeColor = .clear
                line.fillColor = tint.withAlphaComponent(0.16)
                accent = line
            default:
                let width = CGFloat.random(in: 10...16)
                let rect = SKShapeNode(rectOf: CGSize(width: width, height: width * 0.72), cornerRadius: 2)
                rect.strokeColor = tint.withAlphaComponent(0.22)
                rect.fillColor = tint.withAlphaComponent(0.05)
                rect.lineWidth = 0.8
                accent = rect
            }

            accent.alpha = CGFloat.random(in: 0.14...0.24)
            accent.position = floatingAccentSpawnPoint(index: index)
            accent.zRotation = CGFloat.random(in: -0.65...0.65)
            floatingAccentNode.addChild(accent)

            let drift = CGPoint(x: CGFloat.random(in: -22...22), y: CGFloat.random(in: -16...16))
            let duration = Double.random(in: 7.5...12.5)
            let rotateAmount = CGFloat.random(in: -0.18...0.18)
            accent.run(.repeatForever(.sequence([
                .group([.moveBy(x: drift.x, y: drift.y, duration: duration), .rotate(byAngle: rotateAmount, duration: duration), .fadeAlpha(to: max(0.08, accent.alpha * 0.68), duration: duration)]),
                .group([.moveBy(x: -drift.x, y: -drift.y, duration: duration), .rotate(byAngle: -rotateAmount, duration: duration), .fadeAlpha(to: accent.alpha, duration: duration)])
            ])), withKey: "floatingAccent")
        }
    }

    private func floatingAccentSpawnPoint(index: Int) -> CGPoint {
        let columns: [CGFloat] = [-0.42, -0.34, -0.24, 0.24, 0.34, 0.42]
        let rows: [CGFloat] = [0.38, 0.28, 0.18, -0.22, -0.34, -0.46]
        let x = backdropSize.width * columns[index % columns.count]
        let y = backdropSize.height * rows[(index * 2) % rows.count]

        let protectedRect = CGRect(
            x: -backdropSize.width * 0.34,
            y: -backdropSize.height * 0.18,
            width: backdropSize.width * 0.68,
            height: backdropSize.height * 0.42
        )
        let point = CGPoint(x: x, y: y)
        if protectedRect.contains(point) {
            return CGPoint(x: x < 0 ? -backdropSize.width * 0.42 : backdropSize.width * 0.42, y: y - backdropSize.height * 0.18)
        }
        return point
    }

    private func spawnDeepParticle() {
        let sizeValue = CGFloat.random(in: 1.2...2.6)
        let dot = SKSpriteNode(color: randomParticleColor(pinkChance: 0.18), size: CGSize(width: sizeValue, height: sizeValue))
        dot.alpha = CGFloat.random(in: 0.08...0.16)
        dot.blendMode = .add
        dot.position = particleSpawnPoint(avoidCenterBand: true, preferLowerHalf: false)
        deepParticleNode.addChild(dot)

        let speed = CGFloat.random(in: 4...8)
        let verticalTravel = backdropSize.height + 60
        let travelDuration = Double(verticalTravel / speed)
        let drift = SKAction.moveBy(x: CGFloat.random(in: -10...10), y: -verticalTravel, duration: travelDuration)
        let pulse = SKAction.sequence([.fadeAlpha(to: dot.alpha * 1.14, duration: 2.4), .fadeAlpha(to: dot.alpha * 0.78, duration: 2.6)])
        dot.run(.group([.repeatForever(pulse), .sequence([drift, .removeFromParent(), .run { [weak self] in self?.spawnDeepParticle() }])]))
    }

    private func spawnAccentParticle() {
        let sizeValue = CGFloat.random(in: 3.0...4.8)
        let dot = SKSpriteNode(color: randomParticleColor(pinkChance: 0.24), size: CGSize(width: sizeValue, height: sizeValue))
        dot.alpha = CGFloat.random(in: 0.12...0.22)
        dot.blendMode = .add
        dot.position = particleSpawnPoint(avoidCenterBand: true, preferLowerHalf: true)
        accentParticleNode.addChild(dot)

        let speed = CGFloat.random(in: 8...14)
        let verticalTravel = backdropSize.height + 70
        let horizontalTravel = CGFloat.random(in: -70 ... -34) + CGFloat.random(in: 0...1) * 104
        let glideDuration = Double(verticalTravel / speed)
        let glide = SKAction.moveBy(x: horizontalTravel, y: -verticalTravel, duration: glideDuration)
        let shimmer = SKAction.sequence([.fadeAlpha(to: dot.alpha * 1.16, duration: 1.5), .fadeAlpha(to: dot.alpha * 0.74, duration: 1.8)])
        dot.run(.group([.repeatForever(shimmer), .sequence([glide, .removeFromParent(), .run { [weak self] in self?.spawnAccentParticle() }])]))
    }

    private func spawnNearParticle() {
        let particleSize = CGFloat.random(in: 5.4...8.0)
        let particle = SKSpriteNode(color: randomParticleColor(pinkChance: 0.22), size: CGSize(width: particleSize, height: particleSize))
        particle.alpha = CGFloat.random(in: 0.18...0.28)
        particle.blendMode = .add
        particle.position = particleSpawnPoint(avoidCenterBand: true, preferLowerHalf: true)
        particleNode.addChild(particle)

        let speed = CGFloat.random(in: 14...20)
        let verticalTravel = backdropSize.height + 90
        let horizontalTravel = CGFloat.random(in: 46...84) * (Bool.random() ? 1 : -1)
        let travelDuration = Double(verticalTravel / speed)
        let travel = SKAction.moveBy(x: horizontalTravel, y: -verticalTravel, duration: travelDuration)
        let fade = SKAction.sequence([.fadeAlpha(to: particle.alpha * 1.08, duration: travelDuration * 0.24), .fadeOut(withDuration: travelDuration * 0.76)])
        particle.run(.sequence([.group([travel, fade]), .removeFromParent(), .run { [weak self] in self?.spawnNearParticle() }]))
    }

    private func spawnSparkle() {
        let sparkle = SKSpriteNode(color: Bool.random() ? ArcadeStyle.Color.accentYellow : ArcadeStyle.Color.accentCyan, size: CGSize(width: CGFloat.random(in: 8...14), height: 2))
        sparkle.alpha = 0
        sparkle.blendMode = .add
        sparkle.zRotation = CGFloat.random(in: -0.65...0.65)
        let x = Bool.random() ? CGFloat.random(in: -backdropSize.width * 0.46 ... -backdropSize.width * 0.18) : CGFloat.random(in: backdropSize.width * 0.18 ... backdropSize.width * 0.46)
        let y = CGFloat.random(in: -backdropSize.height * 0.40...backdropSize.height * 0.36)
        sparkle.position = CGPoint(x: x, y: y)
        sparkleNode.addChild(sparkle)
        sparkle.run(.sequence([
            .wait(forDuration: Double.random(in: 0.8...4.4)),
            .group([.fadeAlpha(to: CGFloat.random(in: 0.12...0.24), duration: 0.18), .scale(to: 1.18, duration: 0.18)]),
            .group([.fadeOut(withDuration: 0.34), .scale(to: 0.74, duration: 0.34), .moveBy(x: CGFloat.random(in: -6...6), y: CGFloat.random(in: 10...22), duration: 0.34)]),
            .removeFromParent(),
            .run { [weak self] in self?.spawnSparkle() }
        ]))
    }

    private func particleSpawnPoint(avoidCenterBand: Bool, preferLowerHalf: Bool) -> CGPoint {
        let xRange = (-backdropSize.width / 2 - 20)...(backdropSize.width / 2 + 20)
        let yRange: ClosedRange<CGFloat> = preferLowerHalf
            ? (-backdropSize.height / 2 - 30)...(backdropSize.height * 0.10)
            : (-backdropSize.height / 2 - 20)...(backdropSize.height / 2 + 20)
        var point = CGPoint(x: CGFloat.random(in: xRange), y: CGFloat.random(in: yRange))
        guard avoidCenterBand else { return point }
        let protectedRect = CGRect(
            x: -backdropSize.width * 0.28,
            y: titleAnchorY - 56,
            width: backdropSize.width * 0.56,
            height: 84
        ).union(CGRect(
            x: -backdropSize.width * 0.34,
            y: -backdropSize.height * 0.18,
            width: backdropSize.width * 0.68,
            height: backdropSize.height * 0.42
        ))
        if protectedRect.contains(point) {
            point.y = min(protectedRect.minY - CGFloat.random(in: 40...120), backdropSize.height / 2 + 20)
        }
        return point
    }

    private func randomParticleColor(pinkChance: CGFloat) -> SKColor {
        CGFloat.random(in: 0...1) < pinkChance ? SKColor(hex: 0xFF2D9A) : SKColor(hex: 0x00D4FF)
    }

    private func resolvedScreenScale() -> CGFloat {
        if let screenScale = scene?.view?.window?.windowScene?.screen.scale {
            return screenScale
        }
        if let contentScale = scene?.view?.contentScaleFactor, contentScale > 0 {
            return contentScale
        }
        return 2.0
    }

    private func snap(_ point: CGPoint) -> CGPoint {
        CGPoint(x: round(point.x), y: round(point.y))
    }

    private func snapSize(_ size: CGSize) -> CGSize {
        CGSize(width: round(size.width), height: round(size.height))
    }
}

private final class DailyBotCardNode: SKNode {
    let difficulty: BotDifficulty
    let button: ArcadeButtonNode

    private let completedAccent = SKColor(red: 0.38, green: 1.0, blue: 0.56, alpha: 1.0)
    private let completedAccentStrong = SKColor(red: 0.18, green: 0.98, blue: 0.42, alpha: 1.0)
    private let completionTintNode = SKSpriteNode(color: .clear, size: .zero)
    private let titleLabel = SKLabelNode(fontNamed: ArcadeFont.header)
    private let rewardLabel = SKLabelNode(fontNamed: ArcadeFont.digits)
    private let statusLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let detailLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let checkLabel = SKLabelNode(fontNamed: ArcadeFont.header)
    private var showsCompletedState = false

    init(difficulty: BotDifficulty) {
        self.difficulty = difficulty
        self.button = ArcadeButtonNode(text: "", size: CGSize(width: 280, height: 96))
        super.init()

        button.setAccentColor(difficulty == .hard ? ArcadeStyle.Color.accentMagenta : ArcadeStyle.Color.accentYellow)
        addChild(button)

        completionTintNode.zPosition = 1.15
        completionTintNode.alpha = 0
        button.addChild(completionTintNode)

        titleLabel.fontSize = 20
        titleLabel.fontColor = ArcadeStyle.Color.textPrimary
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.verticalAlignmentMode = .center
        titleLabel.zPosition = 4
        button.addChild(titleLabel)

        rewardLabel.fontSize = 16
        rewardLabel.fontColor = ArcadeStyle.Color.accentYellow
        rewardLabel.horizontalAlignmentMode = .right
        rewardLabel.verticalAlignmentMode = .center
        rewardLabel.zPosition = 4
        button.addChild(rewardLabel)

        detailLabel.fontSize = 10
        detailLabel.fontColor = ArcadeStyle.Color.textSecondary
        detailLabel.horizontalAlignmentMode = .left
        detailLabel.verticalAlignmentMode = .center
        detailLabel.zPosition = 4
        button.addChild(detailLabel)

        statusLabel.fontSize = 10
        statusLabel.fontColor = ArcadeStyle.Color.textMuted
        statusLabel.horizontalAlignmentMode = .right
        statusLabel.verticalAlignmentMode = .center
        statusLabel.zPosition = 4
        button.addChild(statusLabel)

        checkLabel.text = "✓"
        checkLabel.fontSize = 18
        checkLabel.fontColor = completedAccentStrong
        checkLabel.horizontalAlignmentMode = .center
        checkLabel.verticalAlignmentMode = .center
        checkLabel.zPosition = 4.2
        checkLabel.alpha = 0
        button.addChild(checkLabel)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func applySize(_ size: CGSize) {
        button.size = snapSize(size)
        layoutContent()
    }

    func refresh(descriptor: DailyChallengeDescriptor, animateCompletion: Bool = false) {
        titleLabel.text = difficulty == .hard ? "HARD BOT" : "EASY BOT"
        let rewardAmount = DailyChallengeStore.shared.rewardAmount(for: difficulty, descriptor: descriptor)
        rewardLabel.text = "+\(rewardAmount)"
        detailLabel.text = difficulty == .hard ? "OPTIMAL PATHING · BIGGER PAYOUT" : "WALL FOLLOWER · DAILY ENTRY REWARD"
        let claimed = DailyChallengeStore.shared.isRewardClaimed(difficulty, for: descriptor)
        showsCompletedState = claimed
        button.removeAction(forKey: "dailyCompleteBounce")
        removeAction(forKey: "dailyCompleteBounce")
        checkLabel.removeAllActions()
        completionTintNode.removeAllActions()

        if claimed {
            button.setAccentColor(completedAccent)
            rewardLabel.fontColor = completedAccentStrong
            statusLabel.text = "COMPLETE"
            statusLabel.fontColor = completedAccent
            detailLabel.fontColor = ArcadeStyle.Color.textSecondary
            if animateCompletion {
                completionTintNode.alpha = 0.02
                checkLabel.alpha = 0
                checkLabel.setScale(0.55)
                runCompletionRevealAnimation()
            } else {
                completionTintNode.alpha = 0.18
                checkLabel.alpha = 1
                checkLabel.setScale(1.0)
            }
        } else {
            button.setAccentColor(difficulty == .hard ? ArcadeStyle.Color.accentMagenta : ArcadeStyle.Color.accentYellow)
            rewardLabel.fontColor = ArcadeStyle.Color.accentYellow
            statusLabel.text = "READY"
            statusLabel.fontColor = ArcadeStyle.Color.accentCyan
            detailLabel.fontColor = ArcadeStyle.Color.textSecondary
            completionTintNode.alpha = 0
            checkLabel.alpha = 0
            checkLabel.setScale(1.0)
        }
        layoutContent()
    }

    private func layoutContent() {
        let width = button.size.width
        completionTintNode.size = CGSize(width: max(0, width - 10), height: max(0, button.size.height - 10))
        titleLabel.position = snap(CGPoint(x: -width / 2 + 18, y: 12))
        rewardLabel.position = snap(CGPoint(x: width / 2 - 18, y: 12))
        detailLabel.position = snap(CGPoint(x: -width / 2 + 18, y: -14))
        if showsCompletedState {
            statusLabel.position = snap(CGPoint(x: width / 2 - 44, y: -14))
            checkLabel.position = snap(CGPoint(x: width / 2 - 18, y: -14))
        } else {
            statusLabel.position = snap(CGPoint(x: width / 2 - 18, y: -14))
            checkLabel.position = snap(CGPoint(x: width / 2 - 18, y: -14))
        }
    }

    private func runCompletionRevealAnimation() {
        let grow = SKAction.scale(to: 1.045, duration: 0.16)
        grow.timingMode = .easeOut
        let settle = SKAction.scale(to: 1.0, duration: 0.18)
        settle.timingMode = .easeInEaseOut
        let bounce = SKAction.sequence([grow, settle])
        run(bounce, withKey: "dailyCompleteBounce")

        let tintIn = SKAction.fadeAlpha(to: 0.18, duration: 0.18)
        tintIn.timingMode = .easeOut
        completionTintNode.run(tintIn)

        let revealDelay = SKAction.wait(forDuration: 0.14)
        let reveal = SKAction.group([
            SKAction.fadeAlpha(to: 1.0, duration: 0.16),
            SKAction.scale(to: 1.12, duration: 0.16)
        ])
        reveal.timingMode = .easeOut
        let settleCheck = SKAction.scale(to: 1.0, duration: 0.14)
        settleCheck.timingMode = .easeInEaseOut
        checkLabel.run(.sequence([revealDelay, reveal, settleCheck]))
    }

    private func snap(_ point: CGPoint) -> CGPoint {
        CGPoint(x: round(point.x), y: round(point.y))
    }

    private func snapSize(_ size: CGSize) -> CGSize {
        CGSize(width: round(size.width), height: round(size.height))
    }
}

final class DailyChallengeScene: SKScene {
    private let cameraNode = SKCameraNode()
    private let hudNode = SKNode()
    private let topBar = TopBarNode(title: "DAILY CHALLENGE")
    private let subtitleLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let dayLabel = SKLabelNode(fontNamed: ArcadeFont.header)
    private let bestLabel = SKLabelNode(fontNamed: ArcadeFont.digits)
    private let footerLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let contentNode = SKNode()
    private let easyNode = DailyBotCardNode(difficulty: .easy)
    private let hardNode = DailyBotCardNode(difficulty: .hard)

    private var menuBackdropNode: MenuBackdropNode?
    private var safeInsets: UIEdgeInsets = .zero
    private var activeButton: ArcadeButtonNode?
    private var touchStartPoint: CGPoint?
    private var isTransitioning = false

    override func didMove(to view: SKView) {
        backgroundColor = .black
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        SoundFX.syncAudioState()
        updateSafeInsets()
        buildScene()
        refreshContent()
        layoutScene()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        updateSafeInsets()
        layoutScene()
    }

    private func buildScene() {
        removeAllChildren()
        camera = cameraNode
        addChild(cameraNode)

        let backdrop = MenuBackdropNode(size: size, titleAnchorY: topBar.position.y - 52)
        menuBackdropNode = backdrop
        cameraNode.addChild(backdrop)

        cameraNode.addChild(hudNode)
        cameraNode.addChild(contentNode)

        topBar.backButton.onTap = { [weak self] in
            self?.presentStartScene()
        }
        hudNode.addChild(topBar)

        subtitleLabel.text = "One fixed maze today. Beat the bot for coins, then come back tomorrow for a new seed."
        subtitleLabel.fontSize = 12
        subtitleLabel.fontColor = ArcadeStyle.Color.textSecondary
        subtitleLabel.horizontalAlignmentMode = .center
        subtitleLabel.verticalAlignmentMode = .center
        subtitleLabel.zPosition = 10
        subtitleLabel.numberOfLines = 2
        subtitleLabel.preferredMaxLayoutWidth = 300
        contentNode.addChild(subtitleLabel)

        dayLabel.fontSize = 20
        dayLabel.fontColor = ArcadeStyle.Color.textPrimary
        dayLabel.horizontalAlignmentMode = .center
        dayLabel.verticalAlignmentMode = .center
        dayLabel.zPosition = 10
        contentNode.addChild(dayLabel)

        bestLabel.fontSize = 14
        bestLabel.fontColor = ArcadeStyle.Color.accentCyan
        bestLabel.horizontalAlignmentMode = .center
        bestLabel.verticalAlignmentMode = .center
        bestLabel.zPosition = 10
        contentNode.addChild(bestLabel)

        footerLabel.text = "SAME MAZE ALL DAY · EASY + COINS · HARD + MORE COINS"
        footerLabel.fontSize = 10
        footerLabel.fontColor = ArcadeStyle.Color.textMuted
        footerLabel.horizontalAlignmentMode = .center
        footerLabel.verticalAlignmentMode = .center
        footerLabel.zPosition = 10
        contentNode.addChild(footerLabel)

        easyNode.button.onTap = { [weak self] in
            self?.openDaily(with: .easy)
        }
        hardNode.button.onTap = { [weak self] in
            self?.openDaily(with: .hard)
        }
        contentNode.addChild(easyNode)
        contentNode.addChild(hardNode)
    }

    private func refreshContent() {
        let descriptor = DailyChallengeStore.shared.currentDescriptor()
        dayLabel.text = "TODAY · \(descriptor.displayDate)"
        if let bestTime = DailyChallengeStore.shared.bestTime(for: descriptor) {
            bestLabel.text = "BEST  \(formattedClockTime(bestTime))"
        } else {
            bestLabel.text = "BEST  --:--.--"
        }
        let animateEasy = DailyChallengeStore.shared.shouldAnimateCompletionReveal(.easy, for: descriptor)
        let animateHard = DailyChallengeStore.shared.shouldAnimateCompletionReveal(.hard, for: descriptor)
        easyNode.refresh(descriptor: descriptor, animateCompletion: animateEasy)
        hardNode.refresh(descriptor: descriptor, animateCompletion: animateHard)
        if animateEasy {
            DailyChallengeStore.shared.markCompletionRevealShown(.easy, for: descriptor)
        }
        if animateHard {
            DailyChallengeStore.shared.markCompletionRevealShown(.hard, for: descriptor)
        }
        MazeCache.shared.prefetch(levelIndex: descriptor.cacheLevelIndex, config: descriptor.config)
    }

    private func layoutScene() {
        let safeTop = size.height / 2 - safeInsets.top
        let safeBottom = -size.height / 2 + safeInsets.bottom
        let safeWidth = size.width - safeInsets.left - safeInsets.right
        let topBarHeight = clamp(54, 60, size.height * 0.074)
        let topBarWidth = max(260, safeWidth - 24)
        let topBarY = safeTop - 10 - topBarHeight / 2
        topBar.position = snap(CGPoint(x: 0, y: topBarY))
        topBar.layout(width: topBarWidth, height: topBarHeight)

        subtitleLabel.position = snap(CGPoint(x: 0, y: topBarY - topBarHeight / 2 - 28))
        dayLabel.position = snap(CGPoint(x: 0, y: subtitleLabel.position.y - 40))
        bestLabel.position = snap(CGPoint(x: 0, y: dayLabel.position.y - 24))
        footerLabel.position = snap(CGPoint(x: 0, y: safeBottom + 18))

        let cardWidth = min(safeWidth - 40, 336)
        let cardHeight: CGFloat = 92
        let spacing: CGFloat = 16
        easyNode.applySize(CGSize(width: cardWidth, height: cardHeight))
        hardNode.applySize(CGSize(width: cardWidth, height: cardHeight))

        let centerY = (bestLabel.position.y - 24 + footerLabel.position.y + 44) / 2
        easyNode.position = snap(CGPoint(x: 0, y: centerY + (cardHeight + spacing) / 2))
        hardNode.position = snap(CGPoint(x: 0, y: centerY - (cardHeight + spacing) / 2))
        menuBackdropNode?.update(size: size, titleAnchorY: dayLabel.position.y + 10)
    }

    private func openDaily(with difficulty: BotDifficulty) {
        guard let view = view, !isTransitioning else { return }
        isTransitioning = true
        fireHaptic(style: difficulty == .hard ? .medium : .light)
        SoundFX.play(.popupOpen, on: self)
        let scene = GameScene(size: size, levelIndex: 0, runMode: .dailyChallenge(difficulty))
        scene.scaleMode = .resizeFill
        view.presentScene(scene, transition: .fade(withDuration: 0.25))
    }

    private func presentStartScene() {
        guard let view = view, !isTransitioning else { return }
        isTransitioning = true
        SoundFX.play(.popupClose, on: self)
        let scene = StartScene(size: size)
        scene.scaleMode = .resizeFill
        view.presentScene(scene, transition: .fade(withDuration: 0.25))
    }

    private func updateSafeInsets() {
        if let windowInsets = view?.window?.safeAreaInsets, windowInsets != .zero {
            safeInsets = windowInsets
        } else {
            safeInsets = view?.safeAreaInsets ?? .zero
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self), let button = buttonAt(point) else { return }
        touchStartPoint = point
        activeButton = button
        button.setPressed(true)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let button = activeButton, let point = touches.first?.location(in: self) else { return }
        button.setPressed(button.hitTest(point, in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let button = activeButton, let point = touches.first?.location(in: self) else {
            activeButton?.setPressed(false)
            activeButton = nil
            touchStartPoint = nil
            return
        }
        let movement = touchStartPoint.map { hypot(point.x - $0.x, point.y - $0.y) } ?? 0
        let shouldTap = button.hitTest(point, in: self) || movement <= 14
        button.setPressed(false)
        activeButton = nil
        touchStartPoint = nil
        if shouldTap {
            button.onTap?()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeButton?.setPressed(false)
        activeButton = nil
        touchStartPoint = nil
    }

    private func buttonAt(_ point: CGPoint) -> ArcadeButtonNode? {
        if topBar.backButton.hitTest(point, in: self) {
            return topBar.backButton
        }
        if easyNode.button.hitTest(point, in: self) {
            return easyNode.button
        }
        if hardNode.button.hitTest(point, in: self) {
            return hardNode.button
        }
        return nil
    }

    private func fireHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        Haptics.impact(style)
    }

    private func formattedClockTime(_ time: TimeInterval) -> String {
        let clamped = max(0, time)
        let minutes = Int(clamped / 60)
        let seconds = clamped - Double(minutes * 60)
        return String(format: "%02d:%05.2f", minutes, seconds)
    }

    private func snap(_ point: CGPoint) -> CGPoint {
        CGPoint(x: round(point.x), y: round(point.y))
    }

    private func clamp(_ minValue: CGFloat, _ maxValue: CGFloat, _ value: CGFloat) -> CGFloat {
        min(maxValue, max(minValue, value))
    }
}

final class ShopScene: SKScene {
    private let cameraNode = SKCameraNode()
    private let hudNode = SKNode()
    private let topBar = TopBarNode(title: "SHOP")
    private let scrollContainer = ScrollContainerNode()
    private let subtitleLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let coinCard = SKSpriteNode()
    private let coinLabel = SKLabelNode(fontNamed: ArcadeFont.digits)
    private let infoLabel = SKLabelNode(fontNamed: ArcadeFont.body)
    private let contentNode = SKNode()

    private var activeTab: ShopTab = .playerColors
    private var tabButtons: [ShopTab: ArcadeButtonNode] = [:]
    private var itemCards: [ShopItemCardNode] = []

    private var backgroundNode: SKSpriteNode?
    private var safeInsets: UIEdgeInsets = .zero
    private var activeButton: ArcadeButtonNode?
    private var activeCard: ShopItemCardNode?
    private var touchStartPoint: CGPoint?
    private var dragStartPoint: CGPoint = .zero
    private var scrollStartOffset: CGFloat = 0
    private var lastDragPoint: CGPoint = .zero
    private var lastDragTimestamp: TimeInterval = 0
    private var dragVelocity: CGFloat = 0
    private var isDragging = false
    private var isTrackingScroll = false
    private var isTransitioning = false

    override func didMove(to view: SKView) {
        backgroundColor = .black
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        SoundFX.syncAudioState()
        updateSafeInsets()
        buildScene()
        refreshContent(message: tabSummary(for: activeTab))
        layoutScene()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        updateSafeInsets()
        layoutScene()
    }

    override func update(_ currentTime: TimeInterval) {
        scrollContainer.update(currentTime: currentTime)
    }

    private func buildScene() {
        removeAllChildren()
        camera = cameraNode
        addChild(cameraNode)

        let background = NeonFactory.backgroundNode(size: size)
        background.zPosition = -20
        backgroundNode = background
        cameraNode.addChild(background)

        cameraNode.addChild(hudNode)
        cameraNode.addChild(contentNode)
        cameraNode.addChild(scrollContainer)

        topBar.backButton.onTap = { [weak self] in
            self?.presentStartScene()
        }
        hudNode.addChild(topBar)

        subtitleLabel.text = "Gameplay coins only. Earn them in Story levels. No real-money purchases."
        subtitleLabel.fontSize = 12
        subtitleLabel.fontColor = ArcadeStyle.Color.textSecondary
        subtitleLabel.horizontalAlignmentMode = .center
        subtitleLabel.verticalAlignmentMode = .center
        subtitleLabel.zPosition = 10
        contentNode.addChild(subtitleLabel)

        coinCard.zPosition = 9
        contentNode.addChild(coinCard)

        coinLabel.fontSize = 18
        coinLabel.fontColor = ArcadeStyle.Color.textPrimary
        coinLabel.horizontalAlignmentMode = .center
        coinLabel.verticalAlignmentMode = .center
        coinLabel.zPosition = 11
        contentNode.addChild(coinLabel)

        infoLabel.fontSize = 11
        infoLabel.fontColor = ArcadeStyle.Color.textMuted
        infoLabel.horizontalAlignmentMode = .center
        infoLabel.verticalAlignmentMode = .center
        infoLabel.zPosition = 10
        contentNode.addChild(infoLabel)

        for tab in ShopTab.allCases {
            let button = ArcadeButtonNode(text: tab.title, size: CGSize(width: 118, height: 42))
            button.label.fontSize = 12
            button.onTap = { [weak self] in
                self?.select(tab: tab)
            }
            tabButtons[tab] = button
            hudNode.addChild(button)
        }

        rebuildCards()
    }

    private func refreshContent(message: String? = nil) {
        backgroundNode?.texture = NeonFactory.backgroundNode(size: size, theme: ThemeUnlocker.theme(for: ProgressStore.shared.nextPlayableLevelId)).texture
        coinLabel.text = "COINS · \(CoinStore.shared.totalCoins)"
        infoLabel.text = message ?? tabSummary(for: activeTab)
        itemCards.forEach { $0.refresh() }
        for (tab, button) in tabButtons {
            button.setAccentColor(tab == activeTab ? ArcadeStyle.Color.accentCyan : ArcadeStyle.Color.accentMagenta)
            button.label.fontColor = tab == activeTab ? ArcadeStyle.Color.textPrimary : ArcadeStyle.Color.textSecondary
        }
    }

    private func layoutScene() {
        backgroundNode?.size = size
        backgroundNode?.position = .zero

        let safeTop = size.height / 2 - safeInsets.top
        let safeBottom = -size.height / 2 + safeInsets.bottom
        let safeWidth = size.width - safeInsets.left - safeInsets.right
        let topBarHeight = clamp(54, 60, size.height * 0.074)
        let topBarWidth = max(260, safeWidth - 24)
        let topBarY = safeTop - 10 - topBarHeight / 2
        topBar.position = snap(CGPoint(x: 0, y: topBarY))
        topBar.layout(width: topBarWidth, height: topBarHeight)

        subtitleLabel.position = snap(CGPoint(x: 0, y: topBarY - topBarHeight / 2 - 22))

        let coinCardSize = snapSize(CGSize(width: min(safeWidth - 40, 220), height: 40))
        coinCard.texture = TextureFactory.shared.cardTexture(size: coinCardSize, style: .badge)
        coinCard.size = coinCardSize
        coinCard.position = snap(CGPoint(x: 0, y: subtitleLabel.position.y - 34))
        coinLabel.position = coinCard.position

        let tabWidth = min((safeWidth - 36) / 3, 110)
        let tabHeight: CGFloat = 40
        let tabSpacing: CGFloat = 10
        let tabRows: [[ShopTab]] = [
            [.playerColors, .playerPatterns, .trails],
            [.winAnimations, .teleporters]
        ]
        let firstRowY = coinCard.position.y - 42
        for (rowIndex, rowTabs) in tabRows.enumerated() {
            let totalWidth = CGFloat(rowTabs.count) * tabWidth + CGFloat(max(0, rowTabs.count - 1)) * tabSpacing
            var currentX = -totalWidth / 2 + tabWidth / 2
            let rowY = firstRowY - CGFloat(rowIndex) * (tabHeight + 10)
            for tab in rowTabs {
                guard let button = tabButtons[tab] else { continue }
                button.size = snapSize(CGSize(width: tabWidth, height: tabHeight))
                button.position = snap(CGPoint(x: currentX, y: rowY))
                currentX += tabWidth + tabSpacing
            }
        }

        let tabBottomY = firstRowY - (tabHeight + 10) - tabHeight / 2
        let gridTopY = tabBottomY - 14
        let gridBottomY = safeBottom + 56
        let gridHeight = max(0, gridTopY - gridBottomY)
        scrollContainer.position = snap(CGPoint(x: 0, y: (gridTopY + gridBottomY) / 2))
        scrollContainer.update(size: CGSize(width: safeWidth, height: gridHeight))

        let gridWidth = min(safeWidth - 12, 352)
        let columnSpacing: CGFloat = 12
        let rowSpacing: CGFloat = 18
        let cardWidth = (gridWidth - columnSpacing) / 2
        let cardHeight: CGFloat = 186
        let columns = 2
        let rows = Int(ceil(Double(itemCards.count) / Double(columns)))
        let contentHeight = CGFloat(rows) * cardHeight + CGFloat(max(0, rows - 1)) * rowSpacing
        scrollContainer.setContentHeight(contentHeight)

        for (index, card) in itemCards.enumerated() {
            card.applySize(CGSize(width: cardWidth, height: cardHeight))
            let row = index / columns
            let col = index % columns
            let x = (safeWidth - gridWidth) / 2 + cardWidth / 2 + CGFloat(col) * (cardWidth + columnSpacing)
            let y = -(cardHeight / 2 + CGFloat(row) * (cardHeight + rowSpacing))
            card.position = snap(CGPoint(x: x, y: y))
        }

        infoLabel.position = snap(CGPoint(x: 0, y: safeBottom + 24))
        infoLabel.preferredMaxLayoutWidth = safeWidth - 40
    }

    private func rebuildCards() {
        itemCards.forEach { $0.removeFromParent() }
        itemCards.removeAll()
        for item in CosmeticsStore.shared.items(for: activeTab) {
            let card = ShopItemCardNode(item: item)
            card.button.onTap = { [weak self, weak card] in
                guard let self, let card else { return }
                self.handlePurchase(for: card.item)
            }
            itemCards.append(card)
            scrollContainer.contentNode.addChild(card)
        }
    }

    private func select(tab: ShopTab) {
        guard tab != activeTab else { return }
        activeTab = tab
        fireHaptic(style: .light)
        SoundFX.play(.cursor1, on: self)
        scrollContainer.scrollTo(0)
        rebuildCards()
        refreshContent(message: tabSummary(for: tab))
        layoutScene()
    }

    private func handlePurchase(for item: ShopItem) {
        let result = CosmeticsStore.shared.purchaseOrEquip(item)
        switch result {
        case .purchased:
            fireHaptic(style: .medium)
            SoundFX.play(.select2, on: self)
            refreshContent(message: "\(item.displayName) unlocked and equipped.")
        case .selected:
            fireHaptic(style: .light)
            SoundFX.play(.select1, on: self)
            refreshContent(message: "\(item.displayName) equipped.")
        case .alreadySelected:
            SoundFX.play(.cursor1, on: self)
            refreshContent(message: "\(item.displayName) is already active.")
        case .insufficientCoins:
            refreshContent(message: "Not enough coins. Clear normal levels and collect more.")
        case .rewardOnly:
            SoundFX.play(.popupOpen, on: self)
            if let rewardLevel = item.rewardLevel {
                refreshContent(message: "\(item.displayName) unlocks automatically after Story Level \(rewardLevel).")
            } else {
                refreshContent(message: "\(item.displayName) unlocks through story rewards.")
            }
        }
    }

    private func tabSummary(for tab: ShopTab) -> String {
        switch tab {
        case .playerColors:
            return "Starter colors are cheap. Buy early, build style fast."
        case .playerPatterns:
            return "Patterns cost more and add premium motion inside the player."
        case .trails:
            return "Trails react during movement and punch harder on combo events."
        case .winAnimations:
            return "Win FX upgrade the finish moment without slowing the run."
        case .teleporters:
            return "Portal skins keep readability while making teleports feel richer."
        }
    }

    private func presentStartScene() {
        guard let view = view, !isTransitioning else { return }
        isTransitioning = true
        SoundFX.play(.popupClose, on: self)
        let scene = StartScene(size: size)
        scene.scaleMode = .resizeFill
        view.presentScene(scene, transition: .fade(withDuration: 0.25))
    }

    private func updateSafeInsets() {
        if let windowInsets = view?.window?.safeAreaInsets, windowInsets != .zero {
            safeInsets = windowInsets
        } else {
            safeInsets = view?.safeAreaInsets ?? .zero
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        handlePressBegan(at: touch.location(in: self), time: touch.timestamp)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        handlePressMoved(to: touch.location(in: self), time: touch.timestamp)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }
        handlePressEnded(at: location)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        handlePressCancelled()
    }

    private func buttonAt(_ point: CGPoint) -> ArcadeButtonNode? {
        if topBar.backButton.hitTest(point, in: self) {
            return topBar.backButton
        }
        for button in tabButtons.values where button.hitTest(point, in: self) {
            return button
        }
        for card in itemCards where card.button.hitTest(point, in: self) {
            return card.button
        }
        return nil
    }

    private func itemCard(at point: CGPoint) -> ShopItemCardNode? {
        for card in itemCards where card.contains(point, in: self) {
            return card
        }
        return nil
    }

    private func handlePressBegan(at location: CGPoint, time: TimeInterval) {
        if let button = buttonAt(location) {
            activeButton = button
            touchStartPoint = location
            button.setPressed(true)
            return
        }

        guard scrollContainer.contains(point: location, in: self) else { return }
        scrollContainer.beginInteraction()
        isTrackingScroll = true
        dragStartPoint = location
        lastDragPoint = location
        lastDragTimestamp = time
        scrollStartOffset = scrollContainer.offset
        dragVelocity = 0
        isDragging = false
        touchStartPoint = location

        if let card = itemCard(at: location) {
            activeCard = card
            card.button.setPressed(true)
        }
    }

    private func handlePressMoved(to location: CGPoint, time: TimeInterval) {
        if let button = activeButton {
            button.setPressed(button.hitTest(location, in: self))
            return
        }

        guard isTrackingScroll else { return }
        let deltaY = location.y - dragStartPoint.y
        let deltaTime = max(0.001, time - lastDragTimestamp)
        dragVelocity = (location.y - lastDragPoint.y) / CGFloat(deltaTime)
        lastDragPoint = location
        lastDragTimestamp = time

        if !isDragging && abs(deltaY) > 8 {
            isDragging = true
            activeCard?.button.setPressed(false)
            activeCard = nil
            SoundFX.playSwipe(on: self)
        }

        if isDragging {
            scrollContainer.scrollTo(scrollStartOffset + deltaY)
        }
    }

    private func handlePressEnded(at location: CGPoint) {
        if let button = activeButton {
            let movement = touchStartPoint.map { hypot(location.x - $0.x, location.y - $0.y) } ?? 0
            let shouldTap = button.hitTest(location, in: self) || movement <= 14
            button.setPressed(false)
            activeButton = nil
            touchStartPoint = nil
            if shouldTap {
                button.onTap?()
            }
            return
        }

        if isDragging {
            activeCard?.button.setPressed(false)
            activeCard = nil
            isDragging = false
            isTrackingScroll = false
            scrollContainer.endInteraction(with: dragVelocity)
            touchStartPoint = nil
            return
        }

        if let card = activeCard {
            let shouldTap = card.contains(location, in: self)
            card.button.setPressed(false)
            activeCard = nil
            isTrackingScroll = false
            touchStartPoint = nil
            if shouldTap {
                card.button.onTap?()
            }
            return
        }

        isTrackingScroll = false
        touchStartPoint = nil
    }

    private func handlePressCancelled() {
        activeButton?.setPressed(false)
        activeButton = nil
        activeCard?.button.setPressed(false)
        activeCard = nil
        isDragging = false
        isTrackingScroll = false
        dragVelocity = 0
        touchStartPoint = nil
    }

    private func fireHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        Haptics.impact(style)
    }

    private func snap(_ point: CGPoint) -> CGPoint {
        CGPoint(x: round(point.x), y: round(point.y))
    }

    private func snapSize(_ size: CGSize) -> CGSize {
        CGSize(width: round(size.width), height: round(size.height))
    }

    private func clamp(_ minValue: CGFloat, _ maxValue: CGFloat, _ value: CGFloat) -> CGFloat {
        min(maxValue, max(minValue, value))
    }
}

#endif
