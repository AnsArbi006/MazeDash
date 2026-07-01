import SpriteKit
#if os(iOS)
import UIKit
#endif

final class LevelSelectScene: SKScene {
    private struct SafeInsets {
        let top: CGFloat
        let left: CGFloat
        let bottom: CGFloat
        let right: CGFloat

        static let zero = SafeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

    private let cameraNode = SKCameraNode()
    private let hudNode = SKNode()
    private let scrollContainer = ScrollContainerNode()

    private var safeAreaInsets: SafeInsets = .zero
    private var backgroundNode: SKSpriteNode?
    private var topBarNode: TopBarNode?
    private var statChips: [SKSpriteNode] = []
    private var statPrimaryShadows: [SKLabelNode] = []
    private var statPrimaryLabels: [SKLabelNode] = []
    private var statSecondaryShadows: [SKLabelNode] = []
    private var statSecondaryLabels: [SKLabelNode] = []
    private var botToggleButton: ArcadeButtonNode?
    private var levelCards: [LevelCardNode] = []
    private var activeButton: ArcadeButtonNode?
    private var activeCard: LevelCardNode?

    private var isDragging = false
    private var isTrackingScroll = false
    private var dragStartPoint: CGPoint = .zero
    private var scrollStartOffset: CGFloat = 0
    private var lastDragPoint: CGPoint = .zero
    private var lastDragTimestamp: TimeInterval = 0
    private var dragVelocity: CGFloat = 0
    private var hasPlayedSwipeFeedback = false
    private var isPresentingLevel = false

    private var topBarDebugNode: SKShapeNode?
    private var gridDebugNode: SKShapeNode?

    private let dragThreshold: CGFloat = 6

    override func didMove(to view: SKView) {
        SoundFX.syncAudioState()
        MazeCache.shared.prewarmNormalLevels()
        let currentLevelId = ProgressStore.shared.continueLevelId
        MazeCache.shared.prefetch(levelIndex: currentLevelId - 1, config: makeLevelConfig(levelIndex: currentLevelId))
        let nextPlayableLevelId = ProgressStore.shared.nextPlayableLevelId
        MazeCache.shared.prefetch(levelIndex: nextPlayableLevelId - 1, config: makeLevelConfig(levelIndex: nextPlayableLevelId))
        setupScene()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        updateSafeAreaInsets()
        layoutScene()
    }

    override func update(_ currentTime: TimeInterval) {
        scrollContainer.update(currentTime: currentTime)
    }

    private func setupScene() {
        backgroundColor = .black
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        removeAllChildren()
        updateSafeAreaInsets()

        let background = NeonFactory.backgroundNode(size: size)
        background.zPosition = LevelSelectStyle.ZPosition.background
        backgroundNode = background
        addChild(background)

        cameraNode.position = .zero
        camera = cameraNode
        addChild(cameraNode)

        hudNode.zPosition = LevelSelectStyle.ZPosition.topBar
        cameraNode.addChild(hudNode)

        scrollContainer.zPosition = LevelSelectStyle.ZPosition.grid
        cameraNode.addChild(scrollContainer)

        let topBar = TopBarNode(title: "SELECT LEVEL")
        topBar.backButton.onTap = { [weak self] in
            self?.presentMainMenu()
        }
        topBarNode = topBar
        hudNode.addChild(topBar)

        buildStatChips()
        buildBotToggleButton()
        buildCards()
        layoutScene()
    }

    private func buildStatChips() {
        statChips.forEach { $0.removeFromParent() }
        statChips.removeAll()
        statPrimaryShadows.removeAll()
        statPrimaryLabels.removeAll()
        statSecondaryShadows.removeAll()
        statSecondaryLabels.removeAll()

        for _ in 0..<3 {
            let chip = SKSpriteNode(texture: TextureFactory.shared.cardTexture(size: CGSize(width: 120, height: 48), style: .hud))
            chip.zPosition = LevelSelectStyle.ZPosition.topBar - 1
            hudNode.addChild(chip)
            statChips.append(chip)

            let primaryShadow = SKLabelNode(fontNamed: ArcadeFont.digits)
            primaryShadow.fontSize = 17
            primaryShadow.fontColor = SKColor(white: 0.0, alpha: 0.78)
            primaryShadow.horizontalAlignmentMode = .center
            primaryShadow.verticalAlignmentMode = .center
            primaryShadow.zPosition = 3
            chip.addChild(primaryShadow)
            statPrimaryShadows.append(primaryShadow)

            let primary = SKLabelNode(fontNamed: ArcadeFont.digits)
            primary.fontSize = 17
            primary.fontColor = ArcadeStyle.Color.textPrimary
            primary.horizontalAlignmentMode = .center
            primary.verticalAlignmentMode = .center
            primary.zPosition = 4
            chip.addChild(primary)
            statPrimaryLabels.append(primary)

            let secondaryShadow = SKLabelNode(fontNamed: ArcadeFont.body)
            secondaryShadow.fontSize = 10
            secondaryShadow.fontColor = SKColor(white: 0.0, alpha: 0.66)
            secondaryShadow.horizontalAlignmentMode = .center
            secondaryShadow.verticalAlignmentMode = .center
            secondaryShadow.zPosition = 3
            chip.addChild(secondaryShadow)
            statSecondaryShadows.append(secondaryShadow)

            let secondary = SKLabelNode(fontNamed: ArcadeFont.body)
            secondary.fontSize = 10
            secondary.fontColor = ArcadeStyle.Color.textPrimary.withAlphaComponent(0.76)
            secondary.horizontalAlignmentMode = .center
            secondary.verticalAlignmentMode = .center
            secondary.zPosition = 4
            chip.addChild(secondary)
            statSecondaryLabels.append(secondary)
        }
    }

    private func buildBotToggleButton() {
        botToggleButton?.removeFromParent()

        let button = ArcadeButtonNode(text: BotSettingsStore.shared.difficulty.buttonTitle, size: CGSize(width: 120, height: 48))
        button.zPosition = LevelSelectStyle.ZPosition.topBar - 1
        button.label.fontName = ArcadeFont.button
        button.label.fontSize = 13
        button.onTap = { [weak self] in
            self?.cycleBotDifficulty()
        }
        botToggleButton = button
        hudNode.addChild(button)
        refreshBotToggleButton()
    }

    private func buildCards() {
        levelCards.forEach { $0.removeFromParent() }
        levelCards.removeAll()

        let nextPlayableLevelId = ProgressStore.shared.nextPlayableLevelId
        for level in LevelStore.levels {
            let progress = ProgressStore.shared.progress(for: level.id)
            let card = LevelCardNode(level: level, progress: progress, size: CGSize(width: 160, height: 100))
            let isLocked = !isLevelUnlocked(levelId: level.id)
            let isCompleted = progress.bestTime != nil || progress.stars > 0
            let isCurrent = !isLocked && level.id == nextPlayableLevelId
            card.setVisualState(isLocked: isLocked, isCurrent: isCurrent, isCompleted: isCompleted)
            card.setTheme(ThemeUnlocker.theme(for: level.id))
            levelCards.append(card)
            scrollContainer.contentNode.addChild(card)
        }
    }

    private func layoutScene() {
        updateBackground()
        guard let topBar = topBarNode else { return }

        let safeTop = size.height / 2 - safeAreaInsets.top
        let safeBottom = -size.height / 2 + safeAreaInsets.bottom
        let safeCenterX = (safeAreaInsets.left - safeAreaInsets.right) / 2
        let safeWidth = size.width - safeAreaInsets.left - safeAreaInsets.right

        let topBarHeight = clamp(54.0, 60.0, size.height * 0.072)
        let topBarWidth = max(CGFloat(260), safeWidth - 24)
        let topBarTopInset: CGFloat = 10
        let topBarY = safeTop - topBarTopInset - topBarHeight / 2

        topBar.position = snap(CGPoint(x: safeCenterX, y: topBarY))
        topBar.layout(width: topBarWidth, height: topBarHeight)

        let topBarBottom = topBarY - topBarHeight / 2
        let chipSpacing: CGFloat = 12
        let chipWidth = (safeWidth - chipSpacing * 3) / 4
        let chipHeight: CGFloat = 48
        let chipY = topBarBottom - 12 - chipHeight / 2
        layoutStatChips(centerX: safeCenterX, width: chipWidth, height: chipHeight, y: chipY, spacing: chipSpacing)

        let gridTopY = chipY - chipHeight / 2 - 16
        let gridBottomY = safeBottom + 10
        let gridHeight = max(0, gridTopY - gridBottomY)

        scrollContainer.position = snap(CGPoint(x: safeCenterX, y: (gridTopY + gridBottomY) / 2))
        scrollContainer.update(size: CGSize(width: safeWidth, height: gridHeight))

        layoutCards(in: CGSize(width: safeWidth, height: gridHeight))
        updateDebugBounds(topBarWidth: topBarWidth, topBarHeight: topBarHeight, topBarY: topBarY, gridSize: CGSize(width: safeWidth, height: gridHeight), gridCenterY: (gridTopY + gridBottomY) / 2, safeCenterX: safeCenterX)
    }

    private func layoutStatChips(centerX: CGFloat, width: CGFloat, height: CGFloat, y: CGFloat, spacing: CGFloat) {
        let nextLevel = ProgressStore.shared.nextPlayableLevelId
        let cleared = ProgressStore.shared.completedLevelCount
        let chapterCode = storyChapterShortCode(for: nextLevel)

        let items: [(String, String)] = [
            ("L\(nextLevel)", "NEXT"),
            ("\(cleared)", "CLEARED"),
            (chapterCode, "SECTOR")
        ]

        let totalWidth = width * 4 + spacing * 3
        var x = centerX - totalWidth / 2 + width / 2

        for index in 0..<min(statChips.count, items.count) {
            let chip = statChips[index]
            let chipSize = snapSize(CGSize(width: width, height: height))
            chip.texture = TextureFactory.shared.cardTexture(size: chipSize, style: .hud)
            chip.size = chipSize
            switch index {
            case 0:
                chip.color = ArcadeStyle.Color.accentYellow.withAlphaComponent(0.34)
                chip.colorBlendFactor = 0.18
                statPrimaryLabels[index].fontColor = ArcadeStyle.Color.accentYellow
                statSecondaryLabels[index].fontColor = ArcadeStyle.Color.textPrimary.withAlphaComponent(0.88)
            case 1:
                chip.color = ArcadeStyle.Color.accentCyan.withAlphaComponent(0.18)
                chip.colorBlendFactor = 0.12
                statPrimaryLabels[index].fontColor = ArcadeStyle.Color.textPrimary
                statSecondaryLabels[index].fontColor = ArcadeStyle.Color.textPrimary.withAlphaComponent(0.76)
            default:
                chip.color = ArcadeStyle.Color.accentMagenta.withAlphaComponent(0.16)
                chip.colorBlendFactor = 0.12
                statPrimaryLabels[index].fontColor = ArcadeStyle.Color.textPrimary
                statSecondaryLabels[index].fontColor = ArcadeStyle.Color.textPrimary.withAlphaComponent(0.76)
            }
            chip.position = snap(CGPoint(x: x, y: y))

            let primaryShadow = statPrimaryShadows[index]
            primaryShadow.text = items[index].0
            primaryShadow.position = snap(CGPoint(x: 1, y: 5))

            let primary = statPrimaryLabels[index]
            primary.text = items[index].0
            primary.position = snap(CGPoint(x: 0, y: 6))

            let secondaryShadow = statSecondaryShadows[index]
            secondaryShadow.text = items[index].1
            secondaryShadow.position = snap(CGPoint(x: 1, y: -11))

            let secondary = statSecondaryLabels[index]
            secondary.text = items[index].1
            secondary.position = snap(CGPoint(x: 0, y: -10))

            x += width + spacing
        }

        if let button = botToggleButton {
            button.size = snapSize(CGSize(width: width, height: height))
            button.position = snap(CGPoint(x: x, y: y))
            button.label.fontSize = 13
            refreshBotToggleButton()
        }
    }

    private func layoutCards(in viewportSize: CGSize) {
        guard !levelCards.isEmpty else { return }

        let availableWidth = viewportSize.width - LevelSelectStyle.Metric.sidePadding * 2
        let cardWidth = (availableWidth - LevelSelectStyle.Metric.columnSpacing) / 2
        let cardHeight = cardWidth * LevelSelectStyle.Metric.cardHeightFactor
        let columns = 2
        let rows = Int(ceil(Double(levelCards.count) / Double(columns)))
        let contentHeight = CGFloat(rows) * cardHeight + CGFloat(max(0, rows - 1)) * LevelSelectStyle.Metric.rowSpacing

        scrollContainer.setContentHeight(contentHeight)

        for (index, card) in levelCards.enumerated() {
            let row = index / columns
            let col = index % columns
            let x = LevelSelectStyle.Metric.sidePadding + cardWidth / 2 + CGFloat(col) * (cardWidth + LevelSelectStyle.Metric.columnSpacing)
            let y = -(cardHeight / 2 + CGFloat(row) * (cardHeight + LevelSelectStyle.Metric.rowSpacing))
            card.applySize(CGSize(width: cardWidth, height: cardHeight))
            card.position = snap(CGPoint(x: x, y: y))
        }
    }

    private func updateBackground() {
        if let background = backgroundNode {
            background.texture = NeonFactory.gradientTexture(size: size, colors: [NeonPalette.backgroundBottom, NeonPalette.backgroundTop])
            background.size = size
            background.position = .zero
        } else {
            let background = NeonFactory.backgroundNode(size: size)
            background.zPosition = LevelSelectStyle.ZPosition.background
            backgroundNode = background
            addChild(background)
        }
    }

    private func updateDebugBounds(topBarWidth: CGFloat, topBarHeight: CGFloat, topBarY: CGFloat, gridSize: CGSize, gridCenterY: CGFloat, safeCenterX: CGFloat) {
        guard LevelSelectStyle.Debug.showLayoutBounds else {
            topBarDebugNode?.removeFromParent()
            gridDebugNode?.removeFromParent()
            topBarDebugNode = nil
            gridDebugNode = nil
            return
        }

        let topBarRect = CGRect(x: -topBarWidth / 2, y: -topBarHeight / 2, width: topBarWidth, height: topBarHeight)
        if topBarDebugNode == nil {
            let node = SKShapeNode()
            node.strokeColor = LevelSelectStyle.Color.debugBounds
            node.lineWidth = 1
            node.zPosition = 5
            topBarDebugNode = node
            hudNode.addChild(node)
        }
        topBarDebugNode?.path = CGPath(rect: topBarRect, transform: nil)
        topBarDebugNode?.position = snap(CGPoint(x: safeCenterX, y: topBarY))

        let gridRect = CGRect(x: -gridSize.width / 2, y: -gridSize.height / 2, width: gridSize.width, height: gridSize.height)
        if gridDebugNode == nil {
            let node = SKShapeNode()
            node.strokeColor = LevelSelectStyle.Color.debugBounds
            node.lineWidth = 1
            node.zPosition = 5
            gridDebugNode = node
            hudNode.addChild(node)
        }
        gridDebugNode?.path = CGPath(rect: gridRect, transform: nil)
        gridDebugNode?.position = snap(CGPoint(x: safeCenterX, y: gridCenterY))
    }

    private func isLevelUnlocked(levelId: Int) -> Bool {
        if levelId <= 1 { return true }
        let previous = ProgressStore.shared.progress(for: levelId - 1)
        return previous.stars > 0 || previous.bestTime != nil
    }

    private func presentMainMenu() {
        guard let view = view else { return }
        SoundFX.play(.cancel1, on: self)
        let scene = StartScene(size: size)
        scene.scaleMode = .resizeFill
        view.presentScene(scene, transition: SKTransition.fade(withDuration: 0.3))
    }

    private func selectLevel(using card: LevelCardNode) {
        guard !card.isLocked, !isPresentingLevel else { return }
        isPresentingLevel = true
        playLevelSelectionHaptic()
        SoundFX.playButtonTap(on: self)
        card.playSelectionPulse()

        let levelId = card.level.id
        run(.sequence([
            .wait(forDuration: 0.05),
            .run { [weak self] in
                self?.presentGame(levelId: levelId)
            }
        ]), withKey: "levelLaunch")
    }

    private func presentGame(levelId: Int) {
        guard let view = view else {
            isPresentingLevel = false
            return
        }
        let scene = GameScene(size: size, levelIndex: levelId - 1)
        scene.scaleMode = .resizeFill
        view.presentScene(scene, transition: SKTransition.fade(withDuration: 0.3))
    }

    private func playLevelSelectionHaptic() {
        #if os(iOS)
        Haptics.impact(.light)
        #endif
    }

    private func cycleBotDifficulty() {
        let newDifficulty = BotSettingsStore.shared.cycleDifficulty()
        refreshBotToggleButton()
        #if os(iOS)
        Haptics.impact(.soft)
        #endif
        switch newDifficulty {
        case .off:
            SoundFX.play(.cancel1, on: self)
        case .easy:
            SoundFX.play(.select2, on: self)
        case .hard:
            SoundFX.play(.cursor1, on: self)
        }
    }

    private func refreshBotToggleButton() {
        guard let button = botToggleButton else { return }
        let difficulty = BotSettingsStore.shared.difficulty
        button.label.text = difficulty.buttonTitle
        switch difficulty {
        case .off:
            button.setAccentColor(SKColor(white: 0.7, alpha: 1.0))
        case .easy:
            button.setAccentColor(ArcadeStyle.Color.accentCyan)
        case .hard:
            button.setAccentColor(ArcadeStyle.Color.accentMagenta)
        }
        button.label.fontColor = ArcadeStyle.Color.textPrimary.withAlphaComponent(difficulty == .off ? 0.76 : 0.9)
    }

    private func updateSafeAreaInsets() {
        #if os(iOS) || os(tvOS)
        if let insets = view?.safeAreaInsets {
            safeAreaInsets = SafeInsets(top: insets.top, left: insets.left, bottom: insets.bottom, right: insets.right)
        } else {
            safeAreaInsets = .zero
        }
        #else
        safeAreaInsets = .zero
        #endif
    }

    private func levelCard(at point: CGPoint) -> LevelCardNode? {
        guard scrollContainer.contains(point: point, in: self) else { return nil }
        for node in nodes(at: point) {
            if let card = node as? LevelCardNode, !card.isLocked {
                return card
            }
            if let card = node.parent as? LevelCardNode, !card.isLocked {
                return card
            }
        }
        return nil
    }

    private func hudButton(at scenePoint: CGPoint) -> ArcadeButtonNode? {
        guard let cameraNode = camera else { return nil }
        let cameraPoint = cameraNode.convert(scenePoint, from: self)
        for node in cameraNode.nodes(at: cameraPoint) {
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

    private func isBackButtonTouch(_ scenePoint: CGPoint) -> Bool {
        hudButton(at: scenePoint) === topBarNode?.backButton
    }

    private func handlePressBegan(at location: CGPoint, time: TimeInterval) {
        if let button = hudButton(at: location) {
            activeButton = button
            button.setPressed(true)
            return
        }

        guard scrollContainer.contains(point: location, in: self) else { return }
        scrollContainer.beginInteraction()
        isTrackingScroll = true
        dragStartPoint = location
        lastDragPoint = location
        lastDragTimestamp = time
        dragVelocity = 0
        scrollStartOffset = scrollContainer.offset
        isDragging = false
        hasPlayedSwipeFeedback = false

        if let card = levelCard(at: location) {
            activeCard = card
            card.setPressed(true)
        } else {
            activeCard = nil
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
        let pointDeltaY = location.y - lastDragPoint.y
        dragVelocity = pointDeltaY / CGFloat(deltaTime)
        lastDragPoint = location
        lastDragTimestamp = time
        if !isDragging && abs(deltaY) > dragThreshold {
            isDragging = true
            activeCard?.setPressed(false)
            activeCard = nil
            if !hasPlayedSwipeFeedback {
                SoundFX.playSwipe(on: self)
                hasPlayedSwipeFeedback = true
            }
        }
        if isDragging {
            scrollContainer.scrollTo(scrollStartOffset + deltaY)
        }
    }

    private func handlePressEnded(at location: CGPoint) {
        if let button = activeButton {
            let shouldTap = button.hitTest(location, in: self) && button.isEnabled
            button.setPressed(false)
            activeButton = nil
            isTrackingScroll = false
            isDragging = false
            if shouldTap {
                button.onTap?()
            }
            return
        }

        if isDragging {
            activeCard?.setPressed(false)
            activeCard = nil
            scrollContainer.endInteraction(with: dragVelocity)
            isDragging = false
            isTrackingScroll = false
            hasPlayedSwipeFeedback = false
            return
        }

        if let card = activeCard {
            let localPoint = card.convert(location, from: self)
            let shouldTap = card.contains(localPoint)
            card.setPressed(false)
            activeCard = nil
            isTrackingScroll = false
            if shouldTap {
                selectLevel(using: card)
            }
            return
        }

        isTrackingScroll = false
    }

    private func handlePressCancelled() {
        activeButton?.setPressed(false)
        activeButton = nil
        activeCard?.setPressed(false)
        activeCard = nil
        isDragging = false
        isTrackingScroll = false
        hasPlayedSwipeFeedback = false
        dragVelocity = 0
        scrollContainer.beginInteraction()
    }

    private func clamp(_ minValue: CGFloat, _ maxValue: CGFloat, _ value: CGFloat) -> CGFloat {
        min(maxValue, max(minValue, value))
    }

    private func snap(_ point: CGPoint) -> CGPoint {
        CGPoint(x: round(point.x), y: round(point.y))
    }

    private func snapSize(_ size: CGSize) -> CGSize {
        CGSize(width: round(size.width), height: round(size.height))
    }

    #if os(iOS) || os(tvOS)
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
    #endif

    #if os(OSX)
    override func mouseDown(with event: NSEvent) {
        handlePressBegan(at: event.location(in: self), time: ProcessInfo.processInfo.systemUptime)
    }

    override func mouseDragged(with event: NSEvent) {
        handlePressMoved(to: event.location(in: self), time: ProcessInfo.processInfo.systemUptime)
    }

    override func mouseUp(with event: NSEvent) {
        handlePressEnded(at: event.location(in: self))
    }
    #endif
}
