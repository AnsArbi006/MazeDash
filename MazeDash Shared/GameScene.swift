import SpriteKit
import QuartzCore
#if os(iOS) || os(tvOS)
import UIKit
#endif

final class GameScene: SKScene {
    private static let swipeHintSeenKey = "MazeDash.didShowSwipeHint"

    private struct SafeInsets {
        let top: CGFloat
        let left: CGFloat
        let bottom: CGFloat
        let right: CGFloat

        static let zero = SafeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

    private struct Tuning {
        static let baseTileSize: CGFloat = 44
        static let targetTilesYNormal: CGFloat = 16
        static let targetTilesYLarge: CGFloat = 14
        static let largeMazeThreshold: Int = 35
        static let minTilePx: CGFloat = 30
        static let maxTilePx: CGFloat = 50
        static let hudTopBandPx: CGFloat = 110
        static let hudBottomBandExtra: CGFloat = 20
        static let topDeadzoneExtra: CGFloat = 12
        static let minimapWidthRatio: CGFloat = 0.36
        static let minimapHeightRatio: CGFloat = 0.30
        static let minimapBottomMargin: CGFloat = 8
        static let minimapOpacity: CGFloat = 0.85
        static let hudTopMargin: CGFloat = 12
        static let cameraFollowBiasTiles: CGFloat = 0.6
        static let feedbackHorizontalMargin: CGFloat = 12
        static let feedbackTopMargin: CGFloat = 8
        static let feedbackBottomMargin: CGFloat = 8
        static let feedbackAbovePlayerTiles: CGFloat = 2.0
        static let flowBarWidthRatio: CGFloat = 0.48
        static let flowBarHeight: CGFloat = 60
        static let flowTrackHeight: CGFloat = 8
        static let flowBarSpacing: CGFloat = 10
        static let hudStackMinScale: CGFloat = 0.78
        static let comboDisplayThreshold: Int = 2
        static let enableCameraPulseOnPerfect = false
        static let enableFlowShards = false
        static let enableFlowFloatingLabel = false
        static let explorationRefreshInterval: TimeInterval = 0.10
        static let miniMapPositionUpdateThreshold: CGFloat = 0.35
        static let comboScreenShakeBase: CGFloat = 0.9
        static let comboHudShakeBase: CGFloat = 0.65
        static let comboDisplayShakeBase: CGFloat = 1.5
        static let comboRotationBase: CGFloat = 0.0045
        static let comboBackgroundPulseScale: CGFloat = 1.003
    }

    private enum TurnRating: String {
        case perfect = "PERFECT"
        case good = "GOOD"
        case ok = "OK"

        var comboIncrement: Int {
            switch self {
            case .perfect:
                return 2
            case .good:
                return 1
            case .ok:
                return 0
            }
        }

        var color: SKColor {
            switch self {
            case .perfect:
                return ArcadeStyle.Color.accentCyan
            case .good:
                return ArcadeStyle.Color.accentYellow
            case .ok:
                return ArcadeStyle.Color.textMuted
            }
        }
    }

    private enum GameState {
        case idle
        case playing
        case levelCompleted
        case paused
    }

    private enum RaceWinner {
        case player
        case bot
    }

    private struct BotPathState: Hashable {
        let point: GridPoint
        let hasKey: Bool
        let switchActive: Bool
    }

    private let runMode: GameRunMode
    private var levelIndex: Int
    private var levelDefinition: LevelDefinition
    private var levelConfig: LevelConfig
    private let botDifficulty: BotDifficulty

    private let cameraNode = SKCameraNode()
    private var backgroundNode: SKSpriteNode?
    private let worldNode = SKNode()
    private let hudNode = SKNode()
    private var safeAreaInsets: SafeInsets = .zero

    private var playerNode: SKSpriteNode?
    private var playerGrid = GridPoint(row: 0, col: 0)
    private var botNode: SKSpriteNode?
    private var botGrid = GridPoint(row: 0, col: 0)
    private let trailNode = SKNode()
    private var trailOrbitNode: SKNode?
    private var tileSize: CGFloat = 32
    private var gridOrigin = CGPoint.zero
    private var tileMapNode: SKTileMapNode?
    private var currentMaze: MazeData?
    private var currentStarBenchmarks: LevelBenchmarkData?

    private var orbNodes: [GridPoint: SKSpriteNode] = [:]
    private var keyNodes: [GridPoint: SKSpriteNode] = [:]
    private var switchNodes: [GridPoint: SKNode] = [:]
    private var doorNodes: [GridPoint: SKSpriteNode] = [:]
    private var gateNodes: [GridPoint: SKSpriteNode] = [:]
    private var gateTiles: Set<GridPoint> = []
    private var oneWayDirections: [GridPoint: MoveDirection] = [:]
    private var teleporterMap: [GridPoint: GridPoint] = [:]
    private var teleporterNodes: [GridPoint: SKSpriteNode] = [:]

    private var timerCard: SKSpriteNode?
    private var timerLabel = SKLabelNode()
    private var timerShadowLabel = SKLabelNode()
    private var lastRenderedTimerText = ""
    private var timerTextBasePosition = CGPoint.zero
    private var timerTextMaxWidth: CGFloat = 0
    private var starsCard: SKSpriteNode?
    private var topHudBar: SKSpriteNode?
    private var centerHudPanel: SKSpriteNode?
    private var modePrimaryLabel = SKLabelNode()
    private var modePrimaryShadowLabel = SKLabelNode()
    private var modeSecondaryLabel = SKLabelNode()
    private var modeSecondaryShadowLabel = SKLabelNode()
    private var starNodes: [SKSpriteNode] = []
    private var leftMetricLabel = SKLabelNode()
    private var leftMetricShadowLabel = SKLabelNode()
    private var coinChipNode: SKSpriteNode?
    private var coinLabel = SKLabelNode()
    private var coinShadowLabel = SKLabelNode()
    private var coinIconNode: SKSpriteNode?
    private var pauseButton: ArcadeButtonNode?
    private let debugHudFrames = false
    private let debugHudInfo = false
    private let mechanicBadgeNode = SKNode()
    private var mechanicBadges: [SKNode] = []

    private let comboBadge = SKNode()
    private var comboCard: SKSpriteNode?
    private var comboLabel = SKLabelNode()
    private var perfectLabel = SKLabelNode()

    private let flowSystem = FlowSystem()
    private var flowCard: SKSpriteNode?
    private var flowTrack: SKSpriteNode?
    private var flowFill: SKSpriteNode?
    private var flowIcon: SKSpriteNode?
    private var flowStatusLabel = SKLabelNode()
    private var flowValueCard: SKSpriteNode?
    private var flowHeadNode: SKSpriteNode?
    private var flowLabel = SKLabelNode()
    private var flowValueLabel = SKLabelNode()

    private var pauseOverlay: PauseOverlayNode?
    private var resultOverlay: ResultOverlayNode?
    private var challengeResultOverlay: ChallengeResultOverlayNode?
    private var tutorialOverlay: MechanicTutorialOverlayNode?
    private var rewardUnlockOverlay: RewardUnlockOverlayNode?
    private var loadingLabel: SKLabelNode?
    private var loadingIndicatorWorkItem: DispatchWorkItem?
    private var overviewOverlay: SKNode?
    private var overviewMapNode: MiniMapNode?
    private var overviewCloseButton: ArcadeButtonNode?

    private var currentGameState: GameState = .idle
    private var isMoving = false
    private var isLoadingMaze = false
    private var isInOverviewMode = false
    private var cameraFollowsPlayer = false
    private var baseCameraScale: CGFloat = 1.0
    private var gameplayCameraScale: CGFloat = 1.0
    private var forcedDirection: MoveDirection?
    private var keyCount: Int = 0
    private var switchActivated = false
    private var gateIsOpen: Bool = true

    private var elapsedTime: TimeInterval = 0
    private var lastTimerUpdate: TimeInterval?
    private var runStartTime: TimeInterval?
    private var accumulatedPausedTime: TimeInterval = 0
    private var pauseStartTime: TimeInterval?
    private let overviewPenaltySeconds: TimeInterval = 0.20
    private var addedOverviewPenalty: TimeInterval = 0

    private var score = 0
    private let comboSystem = ComboSystem()

    private var currentDirection: MoveDirection?
    private var queuedDirection: MoveDirection?
    private var queuedTimestamp: TimeInterval?
    private var botCurrentDirection: MoveDirection?
    private var botForcedDirection: MoveDirection?
    private var easyBotLoopTracker = MazeSolvability.EasyBotLoopTracker()
    private var botIsMoving = false
    private var botHasStarted = false
    private var botFinishTime: TimeInterval?
    private let perfectWindow: TimeInterval = 0.12
    private let goodWindow: TimeInterval = 0.25
    private let stepDuration: TimeInterval = MazeTiming.stepDuration

    private var swipeStart: CGPoint?
    private var activeButton: ArcadeButtonNode?
    private var isMiniMapTouch = false
    private var miniMapNode: MiniMapNode?
    private var miniMapTexture: SKTexture?
    private var miniMapSetupPending = false
    private var miniMapSetupDeadline: TimeInterval = 0
    private var mazeBounds: CGRect = .zero

    private var doorsAreUnlocked: Bool {
        keyCount > 0 || switchActivated
    }
    private var fogNode: SKNode?
    private var fogTileMapNode: SKTileMapNode?
    private var playerLightNode: SKSpriteNode?
    private var exploredTiles: Set<GridPoint> = []
    private var cameraScaleLabel: SKLabelNode?
    private var displayScale: CGFloat = 2.0
    private var currentTheme: MazeTheme = .defaultTheme
    private var isTransitioning: Bool = false
    private var mazeLoadGeneration: Int = 0
    private let dailyDescriptor: DailyChallengeDescriptor?
    private var challengeDuration: TimeChallengeDuration?
    private var challengeMazeNumber: Int = 1
    private var challengeCompletedMazes: Int = 0
    private var challengeRunSeedSalt: Int = 0
    private var prefetchedChallengeMaze: MazeData?
    private var prefetchedChallengeMazeNumber: Int?
    private var challengePrefetchToken: Int = 0
    private var hardBotDirectionCache: [BotPathState: MoveDirection] = [:]
    private var needsExplorationRefresh = false
    private var lastExplorationRefreshTime: TimeInterval = -10
    private var lastMiniMapPlayerWorldPosition: CGPoint?
    private var lifecycleObservers: [NSObjectProtocol] = []
    private var autoPausedForLifecycle = false
    private var hardBotCacheWorkItem: DispatchWorkItem?
    private var ratingLabelPool: [SKLabelNode] = []
    private var milestoneLabelPool: [SKLabelNode] = []
    private var flowLabelPool: [SKLabelNode] = []
    private var flowShardPool: [SKSpriteNode] = []
    private var swipeHintLabel: SKLabelNode?
    #if os(iOS)
    private let comboHapticGenerator = UIImpactFeedbackGenerator(style: .light)
    #endif

    init(size: CGSize, levelIndex: Int, runMode: GameRunMode = .normal) {
        let safeIndex = max(0, min(levelIndex, LevelStore.levels.count - 1))
        self.runMode = runMode
        self.levelIndex = safeIndex
        self.levelDefinition = LevelStore.levels[safeIndex]
        self.levelConfig = makeLevelConfig(levelIndex: self.levelDefinition.id)
        self.dailyDescriptor = {
            if case .dailyChallenge = runMode {
                return DailyChallengeStore.shared.currentDescriptor()
            }
            return nil
        }()
        self.botDifficulty = {
            switch runMode {
            case .normal:
                return BotSettingsStore.shared.difficulty
            case let .dailyChallenge(difficulty):
                return difficulty
            case .timeChallenge:
                return .off
            }
        }()
        if case let .timeChallenge(duration) = runMode {
            self.challengeDuration = duration
            self.levelConfig = makeChallengeLevelConfig(mazeNumber: 1)
            self.challengeRunSeedSalt = Int.random(in: 1...Int.max / 4)
        } else if let dailyDescriptor = self.dailyDescriptor {
            self.levelIndex = max(0, min(LevelStore.levels.count - 1, dailyDescriptor.referenceLevelId - 1))
            self.levelDefinition = LevelStore.levels[self.levelIndex]
            self.levelConfig = dailyDescriptor.config
        }
        super.init(size: size)
        scaleMode = .resizeFill
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    override func didMove(to view: SKView) {
        backgroundColor = .black
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        removeAllChildren()
        SoundFX.syncAudioState()
        #if os(iOS)
        comboHapticGenerator.prepare()
        #endif
        if case .normal = runMode {
            ProgressStore.shared.markLastPlayed(levelId: levelDefinition.id)
        }

        updateSafeAreaInsets()
        #if os(iOS) || os(tvOS)
        displayScale = view.traitCollection.displayScale
        #elseif os(macOS)
        displayScale = view.window?.screen?.backingScaleFactor ?? 2.0
        #endif
        TextureFactory.shared.displayScale = displayScale

        cameraNode.position = snap(.zero)
        addChild(cameraNode)
        camera = cameraNode

        updateBackground()

        addChild(worldNode)
        cameraNode.addChild(hudNode)
        // HUD stays in screen space as a child of the camera.
        worldNode.zPosition = 0
        hudNode.zPosition = 5000
        registerLifecycleObserversIfNeeded()
        resetGameAndReloadLevel()
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)
        teardownLifecycleObservers()
        hardBotCacheWorkItem?.cancel()
        hardBotCacheWorkItem = nil
    }

    deinit {
        teardownLifecycleObservers()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        updateSafeAreaInsets()
        updateBackground()
        layoutWorldPosition()
        updateCameraPosition(animated: false)
        setupHUD()
        updateDebugHudLabel()
        updateFogMask()
        if let overlay = pauseOverlay {
            let safeTop = size.height / 2 - safeAreaInsets.top
            let safeBottom = -size.height / 2 + safeAreaInsets.bottom
            if overlay.parent == nil {
                hudNode.addChild(overlay)
            }
            overlay.layout(in: size, safeTop: safeTop, safeBottom: safeBottom)
            overlay.setScale(1.0)
        }
        if let overlay = resultOverlay {
            let safeTop = size.height / 2 - safeAreaInsets.top
            let safeBottom = -size.height / 2 + safeAreaInsets.bottom
            if overlay.parent == nil {
                hudNode.addChild(overlay)
            }
            overlay.layout(in: size, safeTop: safeTop, safeBottom: safeBottom)
            overlay.setScale(1.0)
        }
        if let overlay = challengeResultOverlay {
            let safeTop = size.height / 2 - safeAreaInsets.top
            let safeBottom = -size.height / 2 + safeAreaInsets.bottom
            if overlay.parent == nil {
                hudNode.addChild(overlay)
            }
            overlay.layout(in: size, safeTop: safeTop, safeBottom: safeBottom)
            overlay.setScale(1.0)
        }
        if let overlay = tutorialOverlay {
            let safeTop = size.height / 2 - safeAreaInsets.top
            let safeBottom = -size.height / 2 + safeAreaInsets.bottom
            if overlay.parent == nil {
                hudNode.addChild(overlay)
            }
            overlay.layout(in: size, safeTop: safeTop, safeBottom: safeBottom)
            overlay.setScale(1.0)
        }
        if let overlay = rewardUnlockOverlay {
            let safeTop = size.height / 2 - safeAreaInsets.top
            let safeBottom = -size.height / 2 + safeAreaInsets.bottom
            if overlay.parent == nil {
                hudNode.addChild(overlay)
            }
            overlay.layout(in: size, safeTop: safeTop, safeBottom: safeBottom)
            overlay.setScale(1.0)
        }
    }

    private func registerLifecycleObserversIfNeeded() {
        guard lifecycleObservers.isEmpty else { return }
        let center = NotificationCenter.default
        lifecycleObservers = [
            center.addObserver(
                forName: .mazeDashApplicationWillResignActive,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleApplicationWillResignActive()
            },
            center.addObserver(
                forName: .mazeDashApplicationDidEnterBackground,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleApplicationDidEnterBackground()
            },
            center.addObserver(
                forName: .mazeDashApplicationDidBecomeActive,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleApplicationDidBecomeActive()
            }
        ]
    }

    private func teardownLifecycleObservers() {
        let center = NotificationCenter.default
        lifecycleObservers.forEach(center.removeObserver)
        lifecycleObservers.removeAll()
    }

    private func handleApplicationWillResignActive() {
        guard currentGameState == .playing else { return }
        autoPausedForLifecycle = true
        pauseGame()
    }

    private func handleApplicationDidEnterBackground() {
        guard currentGameState == .playing else { return }
        autoPausedForLifecycle = true
        pauseGame()
    }

    private func handleApplicationDidBecomeActive() {
        guard autoPausedForLifecycle else { return }
        autoPausedForLifecycle = false
        guard currentGameState == .paused else { return }
        if pauseOverlay?.parent == nil {
            showPauseOverlay()
        }
        updateTimerLabel()
    }

    private func setupWorld(with maze: MazeData) {
        currentTheme = ThemeUnlocker.theme(for: activeThemeLevelId)
        TextureFactory.shared.setTheme(currentTheme)
        updateBackground()
        worldNode.removeAllChildren()
        trailNode.removeAllChildren()
        trailNode.removeAllActions()
        trailOrbitNode?.removeFromParent()
        trailOrbitNode = nil
        trailNode.zPosition = 18
        worldNode.addChild(trailNode)
        orbNodes.removeAll()
        tileMapNode?.removeFromParent()
        tileMapNode = nil
        botNode = nil
        botGrid = maze.start
        botCurrentDirection = nil
        botForcedDirection = nil
        easyBotLoopTracker.seed(at: maze.start, facing: nil)
        botIsMoving = false
        botHasStarted = false
        botFinishTime = nil
        hardBotDirectionCache.removeAll(keepingCapacity: true)
        needsExplorationRefresh = false
        lastExplorationRefreshTime = -10
        lastMiniMapPlayerWorldPosition = nil

        let gridWidth = CGFloat(maze.cols)
        let gridHeight = CGFloat(maze.rows)

        // Keep tile art size stable and let the camera be the only zoom controller.
        tileSize = max(24, round(Tuning.baseTileSize))
        gridOrigin = snap(CGPoint(x: -gridWidth * tileSize / 2 + tileSize / 2, y: gridHeight * tileSize / 2 - tileSize / 2))
        layoutWorldPosition()

        let tileSizeValue = snapSize(CGSize(width: tileSize, height: tileSize))
        let floorGroups = (0..<TextureFactory.shared.tileVariantCount(for: .floor)).map { variant -> SKTileGroup in
            let texture = TextureFactory.shared.tileTexture(size: tileSizeValue, style: .floor, variant: variant)
            let definition = SKTileDefinition(texture: texture, size: tileSizeValue)
            return SKTileGroup(tileDefinition: definition)
        }
        let wallGroups = (0..<TextureFactory.shared.tileVariantCount(for: .wall)).map { variant -> SKTileGroup in
            let texture = TextureFactory.shared.tileTexture(size: tileSizeValue, style: .wall, variant: variant)
            let definition = SKTileDefinition(texture: texture, size: tileSizeValue)
            return SKTileGroup(tileDefinition: definition)
        }
        let tileSet = SKTileSet(tileGroups: floorGroups + wallGroups, tileSetType: .grid)
        let tileMap = SKTileMapNode(tileSet: tileSet, columns: maze.cols, rows: maze.rows, tileSize: tileSizeValue)
        tileMap.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        tileMap.position = snap(.zero)
        tileMap.zPosition = 0
        worldNode.addChild(tileMap)
        tileMapNode = tileMap

        for row in 0..<maze.rows {
            for col in 0..<maze.cols {
                let point = GridPoint(row: row, col: col)
                guard let tile = maze.tile(at: point) else { continue }
                let mapRow = (maze.rows - 1) - row
                if tile == "#" {
                    let variant = tileVariantIndex(for: point, in: maze, style: .wall)
                    tileMap.setTileGroup(wallGroups[variant], forColumn: col, row: mapRow)
                } else {
                    let variant = tileVariantIndex(for: point, in: maze, style: .floor)
                    tileMap.setTileGroup(floorGroups[variant], forColumn: col, row: mapRow)
                }
            }
        }

        populateAmbientFloorAccents(for: maze)
        configureMechanics(for: maze)

        let startTexture = TextureFactory.shared.startTexture(size: snapSize(CGSize(width: tileSize * 0.8, height: tileSize * 0.8)))
        let exitTexture = TextureFactory.shared.exitTexture(size: snapSize(CGSize(width: tileSize * 0.86, height: tileSize * 0.86)))
        let orbTexture = TextureFactory.shared.orbTexture(size: snapSize(CGSize(width: tileSize * 0.36, height: tileSize * 0.36)))
        let playerTexture = TextureFactory.shared.playerTexture(size: snapSize(CGSize(width: tileSize * 0.62, height: tileSize * 0.62)))

        let startMarker = SKSpriteNode(texture: startTexture)
        startMarker.position = positionFor(maze.start)
        startMarker.zPosition = 6
        let startShadow = makeGroundShadow(size: CGSize(width: tileSize * 0.42, height: tileSize * 0.16), alpha: 0.22)
        startShadow.position = CGPoint(x: 0, y: -tileSize * 0.18)
        startShadow.zPosition = -2
        startMarker.addChild(startShadow)
        let startGlow = makeGlowHalo(radius: tileSize * 0.18, color: currentTheme.palette.accentCyan, alpha: 0.32, glowWidth: 10)
        startGlow.zPosition = -1
        startMarker.addChild(startGlow)
        worldNode.addChild(startMarker)

        let exitMarker = SKSpriteNode(texture: exitTexture)
        exitMarker.position = positionFor(maze.exit)
        exitMarker.zPosition = 6
        let exitShadow = makeGroundShadow(size: CGSize(width: tileSize * 0.46, height: tileSize * 0.18), alpha: 0.24)
        exitShadow.position = CGPoint(x: 0, y: -tileSize * 0.18)
        exitShadow.zPosition = -2
        exitMarker.addChild(exitShadow)
        let exitGlow = makeGlowHalo(radius: tileSize * 0.24, color: currentTheme.palette.accentPink, alpha: 0.58, glowWidth: 14)
        exitGlow.zPosition = -1
        exitGlow.run(.repeatForever(.sequence([
            .group([
                .fadeAlpha(to: 0.82, duration: 0.4),
                .scale(to: 1.08, duration: 0.4)
            ]),
            .group([
                .fadeAlpha(to: 0.52, duration: 0.4),
                .scale(to: 1.0, duration: 0.4)
            ])
        ])))
        exitMarker.addChild(exitGlow)
        worldNode.addChild(exitMarker)

        for orbPoint in maze.orbs {
            let orb = SKSpriteNode(texture: orbTexture)
            orb.position = positionFor(orbPoint)
            orb.zPosition = 12
            worldNode.addChild(orb)
            orbNodes[orbPoint] = orb
        }

        playerGrid = maze.start
        let player = SKSpriteNode(texture: playerTexture)
        applySelectedSkin(to: player)
        player.position = positionFor(playerGrid)
        player.zPosition = 20
        let playerShadow = makeGroundShadow(size: CGSize(width: tileSize * 0.34, height: tileSize * 0.14), alpha: 0.28)
        playerShadow.position = CGPoint(x: 0, y: -tileSize * 0.16)
        playerShadow.zPosition = -2
        player.addChild(playerShadow)
        let playerGlow = makeGlowHalo(radius: tileSize * 0.22, color: currentTheme.palette.accentPink, alpha: 0.62, glowWidth: 12)
        playerGlow.name = "playerAmbientGlow"
        playerGlow.zPosition = -1
        playerGlow.run(.repeatForever(.sequence([
            .group([
                .fadeAlpha(to: 0.84, duration: 0.6),
                .scale(to: 1.05, duration: 0.6)
            ]),
            .group([
                .fadeAlpha(to: 0.58, duration: 0.6),
                .scale(to: 1.0, duration: 0.6)
            ])
        ])))
        player.addChild(playerGlow)
        worldNode.addChild(player)
        playerNode = player
        refreshTrailOrbit()
        setupBotIfNeeded(texture: playerTexture, start: maze.start)

        let mazeWidth = CGFloat(maze.cols) * tileSize
        let mazeHeight = CGFloat(maze.rows) * tileSize
        mazeBounds = CGRect(x: -mazeWidth / 2, y: -mazeHeight / 2, width: mazeWidth, height: mazeHeight)
        miniMapTexture = nil

        updateCameraScale(for: maze)
        updateCameraPosition(animated: true)
        setupFog()
        scheduleHardBotDirectionCachePriming()
    }

    private func loadMaze() {
        mazeLoadGeneration += 1
        let generation = mazeLoadGeneration
        loadingIndicatorWorkItem?.cancel()
        loadingIndicatorWorkItem = nil
        isLoadingMaze = true
        if isChallengeMode,
           prefetchedChallengeMazeNumber == challengeMazeNumber,
           let maze = prefetchedChallengeMaze {
            prefetchedChallengeMaze = nil
            prefetchedChallengeMazeNumber = nil
            applyLoadedMaze(maze, generation: generation)
            return
        }
        if !isChallengeMode,
           let cached = MazeCache.shared.cachedMaze(levelIndex: cacheLevelIndex, config: levelConfig) {
            applyLoadedMaze(cached, generation: generation)
            return
        }

        scheduleLoadingIndicator(for: generation)
        let completion: (MazeData) -> Void = { [weak self] maze in
            self?.applyLoadedMaze(maze, generation: generation)
        }
        if isChallengeMode {
            if let duration = challengeDuration {
                MazeCache.shared.generateFreshChallenge(
                    mazeNumber: challengeMazeNumber,
                    duration: duration,
                    config: levelConfig,
                    seedSalt: challengeSeedSalt(for: challengeMazeNumber),
                    completion: completion
                )
            }
        } else {
            MazeCache.shared.loadOrGenerate(levelIndex: cacheLevelIndex, config: levelConfig, completion: completion)
        }
    }

    private func prefetchUpcomingChallengeMaze() {
        guard isChallengeMode, let duration = challengeDuration else { return }
        let nextMazeNumber = challengeMazeNumber + 1
        guard prefetchedChallengeMazeNumber != nextMazeNumber else { return }

        challengePrefetchToken += 1
        let token = challengePrefetchToken
        let nextConfig = makeChallengeLevelConfig(mazeNumber: nextMazeNumber)
        MazeCache.shared.generateFreshChallenge(
            mazeNumber: nextMazeNumber,
            duration: duration,
            config: nextConfig,
            seedSalt: challengeSeedSalt(for: nextMazeNumber)
        ) { [weak self] maze in
            guard let self = self else { return }
            guard self.challengePrefetchToken == token else { return }
            guard self.isChallengeMode else { return }
            guard self.challengeMazeNumber < nextMazeNumber else { return }
            self.prefetchedChallengeMazeNumber = nextMazeNumber
            self.prefetchedChallengeMaze = maze
        }
    }

    private func prefetchNearbyNormalMazes() {
        guard !isChallengeMode else { return }
        let candidateIndices = [levelIndex + 1, levelIndex + 2]
        for candidateIndex in candidateIndices where LevelStore.levels.indices.contains(candidateIndex) {
            let level = LevelStore.levels[candidateIndex]
            MazeCache.shared.prefetch(levelIndex: candidateIndex, config: makeLevelConfig(levelIndex: level.id))
        }
    }

    private func scheduleHardBotDirectionCachePriming() {
        hardBotCacheWorkItem?.cancel()
        hardBotCacheWorkItem = nil
        guard botDifficulty == .hard else { return }

        let generation = mazeLoadGeneration
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.mazeLoadGeneration == generation else { return }
            guard self.botDifficulty == .hard else { return }
            self.primeHardBotDirectionCache()
        }
        hardBotCacheWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: workItem)
    }

    private func scheduleLoadingIndicator(for generation: Int) {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            guard self.mazeLoadGeneration == generation, self.isLoadingMaze else { return }
            self.showLoadingIndicator()
        }
        loadingIndicatorWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
    }

    private func applyLoadedMaze(_ maze: MazeData, generation: Int) {
        guard mazeLoadGeneration == generation else { return }
        loadingIndicatorWorkItem?.cancel()
        loadingIndicatorWorkItem = nil
        isLoadingMaze = false
        hideLoadingIndicator()
        currentMaze = maze
        if !isChallengeMode {
            currentStarBenchmarks = MazeBenchmarkStore.shared.cachedBenchmarks(levelId: levelDefinition.id, maze: maze)
            MazeBenchmarkStore.shared.prefetch(levelId: levelDefinition.id, maze: maze)
        } else {
            currentStarBenchmarks = nil
        }
        setupWorld(with: maze)
        setupHUD()
        if let mechanic = pendingTutorialMechanic() {
            setGameState(.idle)
            showTutorialOverlay(for: mechanic)
        } else if isChallengeMode, runStartTime != nil {
            setGameState(.playing)
        } else {
            setGameState(.idle)
        }
        if isChallengeMode {
            prefetchUpcomingChallengeMaze()
        } else {
            prefetchNearbyNormalMazes()
        }
    }

    private func showLoadingIndicator() {
        loadingLabel?.removeFromParent()
        let label = SKLabelNode(fontNamed: ArcadeFont.body)
        label.text = "GENERATING..."
        label.fontSize = 16
        label.fontColor = ArcadeStyle.Color.textPrimary
        label.position = snap(CGPoint(x: 0, y: 0))
        label.zPosition = 6000
        hudNode.addChild(label)
        loadingLabel = label
    }

    private func hideLoadingIndicator() {
        loadingLabel?.removeFromParent()
        loadingLabel = nil
    }

    private func setupHUD() {
        hudNode.removeAllChildren()
        comboBadge.removeAllChildren()
        mechanicBadgeNode.removeAllChildren()
        mechanicBadges.removeAll()
        topHudBar = nil
        centerHudPanel = nil
        timerCard = nil
        starsCard = nil
        pauseButton = nil
        loadingLabel = nil

        let margin = Tuning.hudTopMargin
        let safeLeft = -size.width / 2 + safeAreaInsets.left
        let safeRight = size.width / 2 - safeAreaInsets.right
        let safeTop = size.height / 2 - safeAreaInsets.top
        let barHeight = ArcadeStyle.Metric.hudHeight + 8
        let barY = safeTop - margin - barHeight / 2
        let barWidth = max(300, safeRight - safeLeft - margin * 2)
        let barSize = snapSize(CGSize(width: barWidth, height: barHeight))
        let panelPadding: CGFloat = 12
        let pauseButtonSize = snapSize(CGSize(width: 40, height: 40))

        let bar = SKSpriteNode(texture: TextureFactory.shared.cardTexture(size: barSize, style: .hud))
        bar.position = snap(CGPoint(x: 0, y: barY))
        bar.zPosition = 100
        bar.alpha = 0.98
        hudNode.addChild(bar)
        topHudBar = bar

        let barBreath = SKAction.sequence([
            .fadeAlpha(to: 0.99, duration: 2.6),
            .fadeAlpha(to: 0.965, duration: 3.2)
        ])
        bar.run(.repeatForever(barBreath), withKey: "hudBreath")

        let pauseWidth: CGFloat = 64
        var timerWidth = min(156, max(132, barWidth * 0.35))
        var centerWidth = min(104, max(82, barWidth * 0.18))
        var starsWidth = barWidth - pauseWidth - timerWidth - centerWidth
        if starsWidth < 112 {
            let deficit = 112 - starsWidth
            let timerReduction = min(deficit * 0.7, timerWidth - 112)
            timerWidth -= timerReduction
            centerWidth -= min(deficit - timerReduction, centerWidth - 76)
            starsWidth = barWidth - pauseWidth - timerWidth - centerWidth
        }

        let starsPanelX = -barWidth / 2 + starsWidth / 2
        let centerPanelX = -barWidth / 2 + starsWidth + centerWidth / 2
        let timerPanelX = -barWidth / 2 + starsWidth + centerWidth + timerWidth / 2
        let pausePanelX = barWidth / 2 - pauseWidth / 2

        func makeSegment(width: CGFloat, x: CGFloat) -> SKSpriteNode {
            let node = SKSpriteNode(color: .clear, size: snapSize(CGSize(width: width, height: barHeight - 10)))
            node.position = snap(CGPoint(x: x, y: 0))
            node.zPosition = 1
            bar.addChild(node)
            return node
        }

        func makeSeparator(at x: CGFloat) {
            let separator = SKShapeNode(rectOf: CGSize(width: 1, height: barHeight - 28))
            separator.position = snap(CGPoint(x: x, y: 0))
            separator.strokeColor = ArcadeStyle.Color.panelBorder.withAlphaComponent(0.16)
            separator.lineWidth = 1
            separator.glowWidth = 1.5
            separator.alpha = 0.6
            separator.zPosition = 2
            bar.addChild(separator)
        }

        let starsPanel = makeSegment(width: starsWidth, x: starsPanelX)
        let centerPanel = makeSegment(width: centerWidth, x: centerPanelX)
        let timerPanel = makeSegment(width: timerWidth, x: timerPanelX)
        let pausePanel = makeSegment(width: pauseWidth, x: pausePanelX)
        starsCard = starsPanel
        centerHudPanel = centerPanel
        timerCard = timerPanel

        let boundary1 = -barWidth / 2 + starsWidth
        let boundary2 = boundary1 + centerWidth
        makeSeparator(at: boundary1)
        makeSeparator(at: boundary2)

        starNodes.removeAll()
        leftMetricLabel.removeFromParent()
        leftMetricShadowLabel.removeFromParent()
        coinChipNode?.removeFromParent()
        coinChipNode = nil
        coinIconNode = nil

        if isChallengeMode {
            leftMetricShadowLabel = SKLabelNode(fontNamed: ArcadeFont.digits)
            leftMetricShadowLabel.fontSize = 26
            leftMetricShadowLabel.fontColor = SKColor(white: 0.0, alpha: 0.78)
            leftMetricShadowLabel.verticalAlignmentMode = .center
            leftMetricShadowLabel.horizontalAlignmentMode = .center
            leftMetricShadowLabel.position = snap(CGPoint(x: 1, y: 0))
            leftMetricShadowLabel.zPosition = 2
            starsPanel.addChild(leftMetricShadowLabel)

            leftMetricLabel = SKLabelNode(fontNamed: ArcadeFont.digits)
            leftMetricLabel.fontSize = 26
            leftMetricLabel.fontColor = ArcadeStyle.Color.textPrimary
            leftMetricLabel.verticalAlignmentMode = .center
            leftMetricLabel.horizontalAlignmentMode = .center
            leftMetricLabel.position = snap(CGPoint(x: 0, y: 1))
            leftMetricLabel.zPosition = 3
            starsPanel.addChild(leftMetricLabel)
        } else {
            let starSize = min(22, ArcadeStyle.Metric.hudStarSize)
            let starSpacing = starSize + 6
            let starTexture = TextureFactory.shared.starOutlineTexture(size: CGSize(width: starSize, height: starSize))
            let starsRowWidth = starSize + starSpacing * 2
            let starStartX = -starsRowWidth / 2 + starSize / 2
            for index in 0..<3 {
                let star = SKSpriteNode(texture: starTexture)
                star.position = snap(CGPoint(x: starStartX + CGFloat(index) * starSpacing, y: 1))
                star.zPosition = 3
                starsPanel.addChild(star)
                starNodes.append(star)
            }

            let coinChipWidth = min(88, max(68, size.width * 0.18))
            let chipSize = snapSize(CGSize(width: coinChipWidth, height: 24))
            let coinChip = SKSpriteNode(texture: TextureFactory.shared.cardTexture(size: chipSize, style: .badge))
            let safeBottom = -size.height / 2 + safeAreaInsets.bottom
            let safeRight = size.width / 2 - safeAreaInsets.right
            coinChip.position = snap(CGPoint(x: safeRight - margin - coinChipWidth / 2, y: safeBottom + 14 + chipSize.height / 2))
            coinChip.zPosition = 3
            hudNode.addChild(coinChip)
            coinChipNode = coinChip

            let coinIcon = SKSpriteNode(texture: TextureFactory.shared.orbTexture(size: CGSize(width: 12, height: 12)))
            coinIcon.position = snap(CGPoint(x: -chipSize.width / 2 + 14, y: 0))
            coinIcon.zPosition = 4
            coinIcon.alpha = 0.92
            coinChip.addChild(coinIcon)
            coinIconNode = coinIcon

            coinShadowLabel = SKLabelNode(fontNamed: ArcadeFont.digits)
            coinShadowLabel.fontSize = 12
            coinShadowLabel.fontColor = SKColor(white: 0.0, alpha: 0.72)
            coinShadowLabel.verticalAlignmentMode = .center
            coinShadowLabel.horizontalAlignmentMode = .left
            coinShadowLabel.position = snap(CGPoint(x: -chipSize.width / 2 + 24, y: -1))
            coinShadowLabel.zPosition = 4
            coinChip.addChild(coinShadowLabel)

            coinLabel = SKLabelNode(fontNamed: ArcadeFont.digits)
            coinLabel.fontSize = 12
            coinLabel.fontColor = ArcadeStyle.Color.textSecondary
            coinLabel.verticalAlignmentMode = .center
            coinLabel.horizontalAlignmentMode = .left
            coinLabel.position = snap(CGPoint(x: -chipSize.width / 2 + 23, y: 0))
            coinLabel.zPosition = 5
            coinChip.addChild(coinLabel)
        }

        modePrimaryShadowLabel = SKLabelNode(fontNamed: ArcadeFont.header)
        modePrimaryShadowLabel.fontSize = 16
        modePrimaryShadowLabel.fontColor = SKColor(white: 0.0, alpha: 0.76)
        modePrimaryShadowLabel.verticalAlignmentMode = .center
        modePrimaryShadowLabel.horizontalAlignmentMode = .center
        modePrimaryShadowLabel.position = snap(CGPoint(x: 1, y: 6))
        modePrimaryShadowLabel.zPosition = 2
        centerPanel.addChild(modePrimaryShadowLabel)

        modePrimaryLabel = SKLabelNode(fontNamed: ArcadeFont.header)
        modePrimaryLabel.fontSize = 16
        modePrimaryLabel.fontColor = ArcadeStyle.Color.textSecondary
        modePrimaryLabel.verticalAlignmentMode = .center
        modePrimaryLabel.horizontalAlignmentMode = .center
        modePrimaryLabel.position = snap(CGPoint(x: 0, y: 7))
        modePrimaryLabel.zPosition = 3
        centerPanel.addChild(modePrimaryLabel)

        modeSecondaryShadowLabel = SKLabelNode(fontNamed: ArcadeFont.body)
        modeSecondaryShadowLabel.fontSize = 9
        modeSecondaryShadowLabel.fontColor = SKColor(white: 0.0, alpha: 0.72)
        modeSecondaryShadowLabel.verticalAlignmentMode = .center
        modeSecondaryShadowLabel.horizontalAlignmentMode = .center
        modeSecondaryShadowLabel.position = snap(CGPoint(x: 1, y: -9))
        modeSecondaryShadowLabel.zPosition = 2
        centerPanel.addChild(modeSecondaryShadowLabel)

        modeSecondaryLabel = SKLabelNode(fontNamed: ArcadeFont.body)
        modeSecondaryLabel.fontSize = 9
        modeSecondaryLabel.fontColor = ArcadeStyle.Color.textMuted
        modeSecondaryLabel.verticalAlignmentMode = .center
        modeSecondaryLabel.horizontalAlignmentMode = .center
        modeSecondaryLabel.position = snap(CGPoint(x: 0, y: -8))
        modeSecondaryLabel.zPosition = 3
        centerPanel.addChild(modeSecondaryLabel)

        let iconRadius: CGFloat = max(5, barHeight * 0.14)
        let icon = SKShapeNode(circleOfRadius: iconRadius)
        icon.strokeColor = ArcadeStyle.Color.textSecondary
        icon.fillColor = .clear
        icon.lineWidth = 2
        icon.isAntialiased = false
        icon.position = snap(CGPoint(x: -timerWidth / 2 + panelPadding + iconRadius, y: 0))
        let handPath = CGMutablePath()
        handPath.move(to: .zero)
        handPath.addLine(to: CGPoint(x: 0, y: iconRadius * 0.55))
        let hand = SKShapeNode(path: handPath)
        hand.strokeColor = ArcadeStyle.Color.textSecondary
        hand.lineWidth = 2
        hand.isAntialiased = false
        icon.addChild(hand)
        timerPanel.addChild(icon)

        timerLabel = SKLabelNode(fontNamed: ArcadeFont.digits)
        timerLabel.fontSize = 24
        timerLabel.fontColor = ArcadeStyle.Color.textPrimary
        timerLabel.verticalAlignmentMode = .center
        timerLabel.horizontalAlignmentMode = .left
        timerLabel.text = formattedClockTime(displayedElapsedTime())
        timerLabel.alpha = 1.0
        timerLabel.blendMode = .alpha
        timerLabel.zPosition = 4
        let labelX = -timerWidth / 2 + panelPadding + iconRadius * 2 + 8
        timerTextBasePosition = snap(CGPoint(x: labelX, y: 0))
        timerTextMaxWidth = timerWidth - (panelPadding * 2 + iconRadius * 2 + 22)
        timerLabel.position = timerTextBasePosition
        timerPanel.addChild(timerLabel)

        timerShadowLabel = SKLabelNode(fontNamed: ArcadeFont.digits)
        timerShadowLabel.fontSize = timerLabel.fontSize
        timerShadowLabel.fontColor = SKColor(white: 0.0, alpha: 0.7)
        timerShadowLabel.verticalAlignmentMode = .center
        timerShadowLabel.horizontalAlignmentMode = .left
        timerShadowLabel.text = timerLabel.text
        timerShadowLabel.alpha = 0.7
        timerShadowLabel.zPosition = 3
        timerShadowLabel.position = snap(CGPoint(x: timerTextBasePosition.x + 1, y: timerTextBasePosition.y - 1))
        timerPanel.addChild(timerShadowLabel)
        lastRenderedTimerText = timerLabel.text ?? ""
        layoutTimerLabelIfNeeded()

        let pause = ArcadeButtonNode(text: "", size: pauseButtonSize)
        pause.setAccentColor(ArcadeStyle.Color.accentMagenta.withAlphaComponent(0.92))
        pause.label.text = ""
        pause.label.alpha = 0
        let pauseIcon = makePauseHudIcon()
        pauseIcon.position = snap(CGPoint(x: 0, y: 0))
        pause.addChild(pauseIcon)
        pause.position = snap(CGPoint(x: 0, y: 0))
        pause.onTap = { [weak self] in
            self?.handlePausePressed()
        }
        pauseButton = pause
        pausePanel.addChild(pause)

        comboCard = nil

        flowCard = nil
        flowTrack = nil
        flowFill = nil
        flowIcon = nil
        flowValueCard = nil
        flowHeadNode = nil

        updateModeHud()
        updateLeftHudState()
        updateCoinHud()
        updateSwipeHintIfNeeded()

        if debugHudFrames {
            let panels: [(SKSpriteNode, SKColor)] = [
                (starsPanel, .red),
                (centerPanel, .yellow),
                (timerPanel, .green),
                (pausePanel, .magenta)
            ]
            for (panel, color) in panels {
                let frame = SKShapeNode(rectOf: panel.size)
                frame.strokeColor = color
                frame.lineWidth = 1
                frame.alpha = 0.25
                panel.addChild(frame)
            }
        }

        scheduleMiniMapSetup()
        updateDebugHudLabel()
        if let maze = currentMaze {
            updateCameraScale(for: maze)
            updateCameraPosition(animated: false)
        }
    }

    private func scheduleMiniMapSetup() {
        miniMapNode?.removeFromParent()
        miniMapNode = nil
        miniMapSetupPending = true
        miniMapSetupDeadline = CACurrentMediaTime() + 0.16
    }

    private func updateFlowBar() {
        guard flowCard != nil else { return }
    }

    private func updateLeftHudState() {
        if isChallengeMode {
            let text = "\(challengeCompletedMazes)"
            leftMetricLabel.text = text
            leftMetricShadowLabel.text = text
        } else {
            for (index, star) in starNodes.enumerated() {
                let filled = index < starsForCurrentRun()
                let size = CGSize(width: ArcadeStyle.Metric.hudStarSize + 4, height: ArcadeStyle.Metric.hudStarSize + 4)
                star.texture = filled
                    ? TextureFactory.shared.starFilledTexture(size: size)
                    : TextureFactory.shared.starOutlineTexture(size: size)
            }
        }
    }

    private func updateCoinHud() {
        guard !isChallengeMode else { return }
        let text = "\(CoinStore.shared.totalCoins)"
        coinLabel.text = text
        coinShadowLabel.text = text
    }

    private var shouldShowSwipeHint: Bool {
        guard !isChallengeMode, !isDailyMode else { return false }
        guard levelDefinition.id == 1 else { return false }
        return !UserDefaults.standard.bool(forKey: Self.swipeHintSeenKey)
    }

    private func updateSwipeHintIfNeeded() {
        guard shouldShowSwipeHint else {
            swipeHintLabel?.removeFromParent()
            swipeHintLabel = nil
            return
        }

        if swipeHintLabel == nil {
            let label = SKLabelNode(fontNamed: ArcadeFont.body)
            label.fontSize = 14
            label.fontColor = ArcadeStyle.Color.textPrimary.withAlphaComponent(0.86)
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.text = "SWIPE TO MOVE"
            label.zPosition = 120
            label.alpha = 0
            hudNode.addChild(label)
            label.run(.fadeAlpha(to: 0.92, duration: 0.18))
            swipeHintLabel = label
        }

        let safeBottom = -size.height / 2 + safeAreaInsets.bottom
        swipeHintLabel?.position = snap(CGPoint(x: 0, y: safeBottom + 34))
    }

    private func dismissSwipeHintIfNeeded(markShown: Bool) {
        guard swipeHintLabel != nil || shouldShowSwipeHint else { return }
        if markShown {
            UserDefaults.standard.set(true, forKey: Self.swipeHintSeenKey)
        }
        swipeHintLabel?.removeAllActions()
        swipeHintLabel?.removeFromParent()
        swipeHintLabel = nil
    }

    private func updateModeHud() {
        let primaryText: String
        let secondaryText: String

        if let duration = challengeDuration {
            primaryText = "\(duration.rawValue) MIN"
            secondaryText = "RUN \(max(1, challengeMazeNumber))"
        } else if isDailyMode {
            primaryText = "DAILY"
            secondaryText = botDifficulty == .hard ? "BOT HARD" : "BOT EASY"
        } else {
            primaryText = "L\(levelDefinition.id)"
            switch botDifficulty {
            case .off:
                secondaryText = "NORMAL"
            case .easy:
                secondaryText = "BOT EASY"
            case .hard:
                secondaryText = "BOT HARD"
            }
        }

        modePrimaryLabel.text = primaryText
        modePrimaryShadowLabel.text = primaryText
        modeSecondaryLabel.text = secondaryText
        modeSecondaryShadowLabel.text = secondaryText
    }

    private func starsForCurrentRun() -> Int {
        guard !isChallengeMode else { return 0 }
        if runStartTime == nil {
            return ProgressStore.shared.progress(for: levelDefinition.id).stars
        }
        guard currentMaze != nil else { return 0 }
        return starsForTime(displayedElapsedTime())
    }

    private func setupMiniMap() {
        miniMapNode?.removeFromParent()
        miniMapNode = nil
        miniMapSetupPending = false
        guard let maze = currentMaze else { return }

        let cardSize = minimapCardSize()
        let explored = fogIsEnabled ? exploredTiles : nil
        let texture = miniMapTexture ?? MiniMapNode.makeMapTexture(maze: maze, displayScale: displayScale, exploredTiles: explored)
        let miniMap = MiniMapNode(maze: maze, size: cardSize, mapTexture: texture, cardStyle: .hud, displayScale: displayScale, exploredTiles: explored)
        miniMapTexture = miniMap.mapTexture
        let safeBottom = -size.height / 2 + safeAreaInsets.bottom
        miniMap.position = snap(CGPoint(x: 0, y: safeBottom + Tuning.minimapBottomMargin + cardSize.height / 2))
        miniMap.zPosition = 140
        miniMap.alpha = Tuning.minimapOpacity
        miniMap.updatePlayerPosition(playerGrid)
        hudNode.addChild(miniMap)
        miniMapNode = miniMap
    }

    private func flushPendingMiniMapSetupIfNeeded(now: TimeInterval) {
        guard miniMapSetupPending else { return }
        guard now >= miniMapSetupDeadline else { return }
        guard currentMaze != nil else { return }
        setupMiniMap()
    }

    private func buildMechanicBadges(panelY: CGFloat, panelHeight: CGFloat, availableWidth: CGFloat) -> CGFloat {
        let mechanics = levelConfig.enabledMechanics
        guard !mechanics.isEmpty else { return 0 }

        let ordered: [(Mechanic, String)] = [
            (.oneWay, "→"),
            (.keysDoors, "KEY"),
            (.teleporters, "TP"),
            (.timingGates, "GATE"),
            (.fog, "FOG")
        ]
        let badges = ordered.filter { mechanics.contains($0.0) }.map { $0.1 }
        guard !badges.isEmpty else { return 0 }

        let badgeHeight: CGFloat = 24
        let badgeSpacing: CGFloat = 8
        let padding: CGFloat = 10

        var badgeSizes: [CGSize] = []
        var labels: [SKLabelNode] = []
        var totalWidth: CGFloat = 0

        for text in badges {
            let label = SKLabelNode(fontNamed: ArcadeFont.body)
            label.text = text
            label.fontSize = 12
            label.fontColor = ArcadeStyle.Color.textPrimary
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            let width = max(32, label.frame.width + padding * 2)
            badgeSizes.append(CGSize(width: width, height: badgeHeight))
            labels.append(label)
            totalWidth += width
        }
        totalWidth += badgeSpacing * CGFloat(max(0, badges.count - 1))

        let maxWidth = max(120, availableWidth - 16)
        let scale = min(1.0, maxWidth / max(totalWidth, 1))

        let badgeY = panelY - panelHeight / 2 - badgeHeight / 2 - 8
        var x = -((totalWidth * scale) / 2)

        for (index, size) in badgeSizes.enumerated() {
            let scaledSize = CGSize(width: round(size.width * scale), height: round(size.height * scale))
            let badgeNode = SKSpriteNode(texture: TextureFactory.shared.cardTexture(size: scaledSize, style: .badge))
            badgeNode.position = snap(CGPoint(x: x + scaledSize.width / 2, y: badgeY))
            badgeNode.zPosition = 120
            let label = labels[index]
            label.fontSize = max(10, label.fontSize * scale)
            label.position = .zero
            badgeNode.addChild(label)
            mechanicBadgeNode.addChild(badgeNode)
            mechanicBadges.append(badgeNode)
            x += scaledSize.width + badgeSpacing * scale
        }

        return badgeHeight * scale
    }

    private func positionFor(_ point: GridPoint) -> CGPoint {
        snap(CGPoint(x: gridOrigin.x + CGFloat(point.col) * tileSize, y: gridOrigin.y - CGFloat(point.row) * tileSize))
    }

    private func makeGlowHalo(radius: CGFloat, color: SKColor, alpha: CGFloat, glowWidth: CGFloat) -> SKShapeNode {
        let glow = SKShapeNode(circleOfRadius: radius)
        glow.fillColor = color.withAlphaComponent(alpha)
        glow.strokeColor = color.withAlphaComponent(alpha)
        glow.lineWidth = 1
        glow.glowWidth = glowWidth
        glow.alpha = alpha
        return glow
    }

    private func makeGroundShadow(size: CGSize, alpha: CGFloat) -> SKShapeNode {
        let shadow = SKShapeNode(ellipseOf: size)
        shadow.fillColor = SKColor(white: 0.0, alpha: alpha)
        shadow.strokeColor = .clear
        shadow.glowWidth = max(4, size.height * 0.45)
        return shadow
    }

    private func stableTileHash(for point: GridPoint, salt: Int) -> Int {
        let mixed = (point.row &* 73_856_093) ^ (point.col &* 19_349_663) ^ salt
        return Int(UInt(bitPattern: mixed) % UInt(Int.max))
    }

    private func tileVariantIndex(for point: GridPoint, in maze: MazeData, style: TileStyle) -> Int {
        let count = max(1, TextureFactory.shared.tileVariantCount(for: style))
        let connectedNeighbors = MoveDirection.allCases.reduce(0) { partial, direction in
            let neighbor = point.moved(by: direction)
            guard let tile = maze.tile(at: neighbor) else { return partial }
            let matchesStyle: Bool
            switch style {
            case .wall:
                matchesStyle = tile == "#"
            case .floor:
                matchesStyle = tile != "#"
            }
            return partial + (matchesStyle ? 1 : 0)
        }
        let salt = (style == .wall ? 0x9e37 : 0x85eb) ^ (connectedNeighbors &* 97)
        return stableTileHash(for: point, salt: salt) % count
    }

    private func populateAmbientFloorAccents(for maze: MazeData) {
        let walkableArea = maze.rows * maze.cols
        let targetCount = min(18, max(6, walkableArea / 110))
        guard targetCount > 0 else { return }

        var candidates: [(point: GridPoint, hash: Int)] = []
        for row in 0..<maze.rows {
            for col in 0..<maze.cols {
                let point = GridPoint(row: row, col: col)
                guard maze.tile(at: point) == "." else { continue }
                let hash = stableTileHash(for: point, salt: 0x1f2d)
                if hash % 3 == 0 {
                    candidates.append((point, hash))
                }
            }
        }

        guard !candidates.isEmpty else { return }
        candidates.sort { $0.hash < $1.hash }

        let accentSize = snapSize(CGSize(width: tileSize * 0.76, height: tileSize * 0.76))
        for candidate in candidates.prefix(targetCount) {
            let baseAlpha = 0.08 + CGFloat(candidate.hash % 5) * 0.018
            let pulseAlpha = min(0.28, baseAlpha + 0.14)
            let duration = 1.6 + Double(candidate.hash % 5) * 0.18
            let delay = Double(candidate.hash % 9) * 0.16
            let variant = candidate.hash % 3

            let accent = SKSpriteNode(texture: TextureFactory.shared.activeFloorPulseTexture(size: accentSize, variant: variant))
            accent.position = positionFor(candidate.point)
            accent.zPosition = 1.5
            accent.alpha = baseAlpha
            accent.blendMode = .add
            worldNode.addChild(accent)

            let pulse = SKAction.sequence([
                .fadeAlpha(to: pulseAlpha, duration: duration * 0.46),
                .fadeAlpha(to: baseAlpha, duration: duration * 0.54)
            ])
            let scalePulse = SKAction.sequence([
                .scale(to: 1.02, duration: duration * 0.46),
                .scale(to: 0.98, duration: duration * 0.54)
            ])
            accent.run(.sequence([
                .wait(forDuration: delay),
                .repeatForever(.group([pulse, scalePulse]))
            ]))
        }
    }

    private func botPositionFor(_ point: GridPoint) -> CGPoint {
        let base = positionFor(point)
        return snap(CGPoint(x: base.x + tileSize * 0.16, y: base.y + tileSize * 0.16))
    }

    private func setupBotIfNeeded(texture: SKTexture, start: GridPoint) {
        guard botRaceEnabled else { return }
        let bot = SKSpriteNode(texture: texture)
        bot.size = snapSize(CGSize(width: tileSize * 0.54, height: tileSize * 0.54))
        bot.color = botDifficulty == .hard ? ArcadeStyle.Color.accentMagenta : ArcadeStyle.Color.accentYellow
        bot.colorBlendFactor = 0.78
        bot.alpha = 0.96
        bot.position = botPositionFor(start)
        bot.zPosition = 19
        let botShadow = makeGroundShadow(size: CGSize(width: tileSize * 0.3, height: tileSize * 0.12), alpha: 0.24)
        botShadow.position = CGPoint(x: 0, y: -tileSize * 0.14)
        botShadow.zPosition = -2
        bot.addChild(botShadow)
        let botGlowColor = botDifficulty == .hard ? ArcadeStyle.Color.accentMagenta : ArcadeStyle.Color.accentYellow
        let botGlow = makeGlowHalo(radius: tileSize * 0.18, color: botGlowColor, alpha: 0.42, glowWidth: 10)
        botGlow.zPosition = -1
        bot.addChild(botGlow)
        worldNode.addChild(bot)
        botNode = bot
    }

    private func startBotRaceIfNeeded() {
        guard botRaceEnabled, !botHasStarted, currentGameState == .playing else { return }
        botHasStarted = true
        botIsMoving = true
        botCurrentDirection = nextBotDirection(at: botGrid)
        stepBotForward()
    }

    private func stepBotForward() {
        guard botRaceEnabled, currentGameState == .playing, let bot = botNode else { return }
        let directionToUse: MoveDirection
        if let forced = botForcedDirection {
            directionToUse = forced
            botCurrentDirection = forced
            botForcedDirection = nil
        } else if let direction = nextBotDirection(at: botGrid) {
            directionToUse = direction
            botCurrentDirection = direction
        } else {
            botIsMoving = false
            return
        }

        let next = botGrid.moved(by: directionToUse)
        guard let tile = tileAt(next) else {
            botIsMoving = false
            return
        }
        if tile == "G", !gateIsOpen {
            bot.removeAllActions()
            bot.run(.sequence([
                .wait(forDuration: 0.05),
                .run { [weak self] in self?.stepBotForward() }
            ]), withKey: "botWait")
            return
        }
        guard botCanEnter(next, hasKey: keyCount > 0, switchActive: switchActivated, allowClosedGate: false) else {
            botIsMoving = false
            return
        }

        let destination = botPositionFor(next)
        let moveAction = SKAction.move(to: destination, duration: stepDuration)
        moveAction.timingMode = .linear
        bot.run(.sequence([
            moveAction,
            .run { [weak self] in
                self?.handleBotArrival(at: next)
            }
        ]), withKey: "botStep")
    }

    private func handleBotArrival(at point: GridPoint) {
        let previousPoint = botGrid
        let landing = processBotLanding(at: point)
        guard currentGameState == .playing else { return }
        botGrid = landing.point
        botForcedDirection = landing.forcedDirection
        if botDifficulty == .easy {
            easyBotLoopTracker.recordMove(from: previousPoint, to: landing.point, facing: botCurrentDirection)
        }
        if landing.reachedExit {
            return
        }
        stepBotForward()
    }

    private func nextBotDirection(at point: GridPoint) -> MoveDirection? {
        let hasKey = keyCount > 0
        let switchActive = switchActivated
        if let forced = forcedBotDirection(at: point, hasKey: hasKey, switchActive: switchActive, allowClosedGate: true) {
            return forced
        }

        let forward = botCurrentDirection.map { point.moved(by: $0) }
        if botDifficulty != .easy,
           let current = botCurrentDirection,
           let forward,
           botCanEnter(forward, hasKey: hasKey, switchActive: switchActive, allowClosedGate: true),
           !isIntersectionOrCorner(point.row, point.col) {
            return current
        }

        switch botDifficulty {
        case .off:
            return nil
        case .easy:
            return nextEasyBotDirection(at: point, facing: botCurrentDirection, hasKey: hasKey, switchActive: switchActive)
        case .hard:
            return nextHardBotDirection(at: point, hasKey: hasKey, switchActive: switchActive)
        }
    }

    private func nextEasyBotDirection(at point: GridPoint, facing: MoveDirection?, hasKey: Bool, switchActive: Bool) -> MoveDirection? {
        let candidates: [MoveDirection]
        if let facing {
            candidates = [leftTurn(from: facing), facing, rightTurn(from: facing), opposite(of: facing)]
        } else {
            candidates = [.left, .up, .right, .down]
        }
        let legal = candidates.filter { direction in
            botCanEnter(point.moved(by: direction), hasKey: hasKey, switchActive: switchActive, allowClosedGate: true)
        }
        return easyBotLoopTracker.chooseDirection(from: point, facing: facing, candidates: legal)
    }

    private func nextHardBotDirection(at point: GridPoint, hasKey: Bool, switchActive: Bool) -> MoveDirection? {
        let normalizedState = BotPathState(
            point: point,
            hasKey: hasKey || tileAt(point) == "K",
            switchActive: switchActive || tileAt(point) == "T"
        )
        if let cached = hardBotDirectionCache[normalizedState] {
            return cached
        }
        let direction = nextHardBotDirectionUncached(at: point, hasKey: hasKey, switchActive: switchActive)
        if let direction {
            hardBotDirectionCache[normalizedState] = direction
        }
        return direction
    }

    private func nextHardBotDirectionUncached(at point: GridPoint, hasKey: Bool, switchActive: Bool) -> MoveDirection? {
        guard let maze = currentMaze else { return nil }
        let startState = BotPathState(
            point: point,
            hasKey: hasKey || tileAt(point) == "K",
            switchActive: switchActive || tileAt(point) == "T"
        )
        if startState.point == maze.exit {
            return nil
        }

        let initialDirections = availableBotDirections(
            from: point,
            hasKey: startState.hasKey,
            switchActive: startState.switchActive,
            allowClosedGate: true
        )
        var queue: [(BotPathState, MoveDirection)] = []
        var visited = Set<BotPathState>([startState])
        var index = 0

        for direction in initialDirections {
            guard let nextState = botAdvanceState(from: startState, direction: direction, allowClosedGate: true) else { continue }
            if visited.insert(nextState).inserted {
                queue.append((nextState, direction))
            }
        }

        while index < queue.count {
            let (state, firstMove) = queue[index]
            index += 1
            if state.point == maze.exit {
                return firstMove
            }

            let directions = availableBotDirections(
                from: state.point,
                hasKey: state.hasKey,
                switchActive: state.switchActive,
                allowClosedGate: true
            )
            for direction in directions {
                guard let nextState = botAdvanceState(from: state, direction: direction, allowClosedGate: true) else { continue }
                if visited.insert(nextState).inserted {
                    queue.append((nextState, firstMove))
                }
            }
        }

        return nextEasyBotDirection(at: point, facing: botCurrentDirection, hasKey: hasKey, switchActive: switchActive)
    }

    private func primeHardBotDirectionCache() {
        guard botDifficulty == .hard, let maze = currentMaze else { return }
        hardBotDirectionCache.removeAll(keepingCapacity: true)
        for row in 0..<maze.rows {
            for col in 0..<maze.cols {
                let point = GridPoint(row: row, col: col)
                for hasKey in [false, true] {
                    for switchActive in [false, true] {
                        let normalizedState = BotPathState(
                            point: point,
                            hasKey: hasKey || tileAt(point) == "K",
                            switchActive: switchActive || tileAt(point) == "T"
                        )
                        guard hardBotDirectionCache[normalizedState] == nil else { continue }
                        guard botCanEnter(point, hasKey: normalizedState.hasKey, switchActive: normalizedState.switchActive, allowClosedGate: true) else { continue }
                        if let direction = nextHardBotDirectionUncached(at: point, hasKey: normalizedState.hasKey, switchActive: normalizedState.switchActive) {
                            hardBotDirectionCache[normalizedState] = direction
                        }
                    }
                }
            }
        }
    }

    private func botAdvanceState(from state: BotPathState, direction: MoveDirection, allowClosedGate: Bool) -> BotPathState? {
        let next = state.point.moved(by: direction)
        guard botCanEnter(next, hasKey: state.hasKey, switchActive: state.switchActive, allowClosedGate: allowClosedGate) else { return nil }
        var destination = next
        var nextHasKey = state.hasKey || tileAt(next) == "K"
        var nextSwitchActive = state.switchActive || tileAt(next) == "T"
        if let teleported = teleporterMap[next] {
            destination = teleported
            nextHasKey = nextHasKey || tileAt(teleported) == "K"
            nextSwitchActive = nextSwitchActive || tileAt(teleported) == "T"
        }
        return BotPathState(point: destination, hasKey: nextHasKey, switchActive: nextSwitchActive)
    }

    private func availableBotDirections(from point: GridPoint, hasKey: Bool, switchActive: Bool, allowClosedGate: Bool) -> [MoveDirection] {
        if let forced = forcedBotDirection(at: point, hasKey: hasKey, switchActive: switchActive, allowClosedGate: allowClosedGate) {
            return [forced]
        }
        return MoveDirection.allCases.filter { direction in
            botCanEnter(point.moved(by: direction), hasKey: hasKey, switchActive: switchActive, allowClosedGate: allowClosedGate)
        }
    }

    private func forcedBotDirection(at point: GridPoint, hasKey: Bool, switchActive: Bool, allowClosedGate: Bool) -> MoveDirection? {
        guard let forced = oneWayDirections[point] else { return nil }
        return botCanEnter(point.moved(by: forced), hasKey: hasKey, switchActive: switchActive, allowClosedGate: allowClosedGate) ? forced : nil
    }

    private func botCanEnter(_ point: GridPoint, hasKey: Bool, switchActive: Bool, allowClosedGate: Bool) -> Bool {
        guard let tile = tileAt(point) else { return false }
        if tile == "#" { return false }
        if tile == "D", !(hasKey || switchActive) { return false }
        if tile == "G", !allowClosedGate, !gateIsOpen { return false }
        return true
    }

    private func leftTurn(from direction: MoveDirection) -> MoveDirection {
        switch direction {
        case .up: return .left
        case .down: return .right
        case .left: return .down
        case .right: return .up
        }
    }

    private func rightTurn(from direction: MoveDirection) -> MoveDirection {
        switch direction {
        case .up: return .right
        case .down: return .left
        case .left: return .up
        case .right: return .down
        }
    }

    private func opposite(of direction: MoveDirection) -> MoveDirection {
        switch direction {
        case .up: return .down
        case .down: return .up
        case .left: return .right
        case .right: return .left
        }
    }

    private func configureMechanics(for maze: MazeData) {
        oneWayDirections.removeAll()
        teleporterMap.removeAll()
        keyNodes.values.forEach { $0.removeFromParent() }
        switchNodes.values.forEach { $0.removeFromParent() }
        doorNodes.values.forEach { $0.removeFromParent() }
        gateNodes.values.forEach { $0.removeFromParent() }
        teleporterNodes.values.forEach { $0.removeFromParent() }
        keyNodes.removeAll()
        switchNodes.removeAll()
        doorNodes.removeAll()
        gateNodes.removeAll()
        gateTiles.removeAll()
        teleporterNodes.removeAll()
        forcedDirection = nil
        keyCount = 0
        switchActivated = false
        gateIsOpen = true

        var teleporterBuckets: [Character: [GridPoint]] = [:]
        let keyTexture = TextureFactory.shared.orbTexture(size: snapSize(CGSize(width: tileSize * 0.34, height: tileSize * 0.34)))
        let switchTexture = TextureFactory.shared.tileTexture(size: snapSize(CGSize(width: tileSize * 0.7, height: tileSize * 0.7)), style: .floor)
        let doorTexture = TextureFactory.shared.tileTexture(size: snapSize(CGSize(width: tileSize * 0.86, height: tileSize * 0.86)), style: .wall)
        let gateTexture = TextureFactory.shared.tileTexture(size: snapSize(CGSize(width: tileSize * 0.86, height: tileSize * 0.86)), style: .floor)
        let teleporterSkin = CosmeticsStore.shared.selectedTeleporterSkin

        for row in 0..<maze.rows {
            for col in 0..<maze.cols {
                let point = GridPoint(row: row, col: col)
                guard let tile = maze.tile(at: point) else { continue }
                switch tile {
                case "^", "v", "<", ">":
                    if let direction = directionForArrow(tile) {
                        oneWayDirections[point] = direction
                        let arrow = SKLabelNode(fontNamed: ArcadeFont.header)
                        arrow.text = String(tile)
                        arrow.fontSize = max(12, tileSize * 0.5)
                        arrow.fontColor = ArcadeStyle.Color.accentCyan
                        arrow.position = positionFor(point)
                        arrow.zPosition = 8
                        worldNode.addChild(arrow)
                    }
                case "K":
                    let key = SKSpriteNode(texture: keyTexture)
                    key.position = positionFor(point)
                    key.zPosition = 11
                    key.color = ArcadeStyle.Color.accentYellow
                    key.colorBlendFactor = 0.4
                    worldNode.addChild(key)
                    keyNodes[point] = key
                case "T":
                    let trigger = SKNode()
                    trigger.position = positionFor(point)
                    trigger.zPosition = 11

                    let plate = SKSpriteNode(texture: switchTexture)
                    plate.color = ArcadeStyle.Color.accentMagenta
                    plate.colorBlendFactor = 0.5
                    plate.zPosition = 0
                    trigger.addChild(plate)

                    let glyph = SKLabelNode(fontNamed: ArcadeFont.body)
                    glyph.text = "SW"
                    glyph.fontSize = max(8, tileSize * 0.18)
                    glyph.fontColor = ArcadeStyle.Color.textPrimary
                    glyph.verticalAlignmentMode = .center
                    glyph.horizontalAlignmentMode = .center
                    glyph.position = snap(.zero)
                    glyph.zPosition = 1
                    trigger.addChild(glyph)

                    worldNode.addChild(trigger)
                    switchNodes[point] = trigger
                case "D":
                    let door = SKSpriteNode(texture: doorTexture)
                    door.position = positionFor(point)
                    door.zPosition = 9
                    door.color = SKColor(red: 1.0, green: 0.35, blue: 0.35, alpha: 1.0)
                    door.colorBlendFactor = 0.45
                    worldNode.addChild(door)
                    doorNodes[point] = door
                case "G":
                    let gate = SKSpriteNode(texture: gateTexture)
                    gate.position = positionFor(point)
                    gate.zPosition = 9
                    gate.colorBlendFactor = 0.5
                    worldNode.addChild(gate)
                    gateNodes[point] = gate
                    gateTiles.insert(point)
                default:
                    if tile.isLetter {
                        let upper = Character(String(tile).uppercased())
                        if !["S", "E", "O", "K", "T", "D", "G"].contains(upper) {
                            teleporterBuckets[upper, default: []].append(point)
                        }
                    }
                }
            }
        }

        let colors: [SKColor] = [
            ArcadeStyle.Color.accentCyan,
            ArcadeStyle.Color.accentMagenta,
            ArcadeStyle.Color.accentYellow,
            SKColor(red: 0.4, green: 1.0, blue: 0.6, alpha: 1.0),
            SKColor(red: 1.0, green: 0.6, blue: 0.3, alpha: 1.0)
        ]

        let sortedKeys = teleporterBuckets.keys.sorted()
        for (index, key) in sortedKeys.enumerated() {
            guard let points = teleporterBuckets[key], points.count >= 2 else { continue }
            let first = points[0]
            let second = points[1]
            teleporterMap[first] = second
            teleporterMap[second] = first

            let color = colors[index % colors.count]
            for point in [first, second] {
                let teleporterTexture = TextureFactory.shared.teleporterTexture(
                    size: snapSize(CGSize(width: tileSize * 0.5, height: tileSize * 0.5)),
                    style: teleporterSkin,
                    accentColor: color
                )
                let node = SKSpriteNode(texture: teleporterTexture)
                node.position = positionFor(point)
                node.zPosition = 10
                CosmeticRenderer.configureTeleporterNode(node, key: key, skin: teleporterSkin, tileSize: tileSize, accentColor: color)
                worldNode.addChild(node)
                teleporterNodes[point] = node
            }
        }

        updateGateVisuals()
        updateDoorVisuals()
    }

    private func setupFog() {
        fogNode?.removeFromParent()
        fogNode = nil
        fogTileMapNode = nil
        playerLightNode = nil
        exploredTiles.removeAll()
        guard fogIsEnabled, let maze = currentMaze else { return }

        let container = SKNode()
        container.zPosition = 80

        let fogTileSize = snapSize(CGSize(width: tileSize, height: tileSize))
        let fogTexture = solidColorTexture(size: fogTileSize, color: .black, scale: displayScale)
        let fogTile = SKTileDefinition(texture: fogTexture, size: fogTileSize)
        let fogGroup = SKTileGroup(tileDefinition: fogTile)
        let fogSet = SKTileSet(tileGroups: [fogGroup], tileSetType: .grid)
        let fogTileMap = SKTileMapNode(tileSet: fogSet, columns: maze.cols, rows: maze.rows, tileSize: fogTileSize)
        fogTileMap.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        fogTileMap.position = snap(.zero)
        fogTileMap.zPosition = 1
        for row in 0..<maze.rows {
            for col in 0..<maze.cols {
                fogTileMap.setTileGroup(fogGroup, forColumn: col, row: row)
            }
        }
        container.addChild(fogTileMap)

        let lightDiameter = tileSize * CGFloat(max(4, fogRevealRadius * 2 + 1))
        let lightSize = snapSize(CGSize(width: lightDiameter, height: lightDiameter))
        let lightTexture = radialLightTexture(size: lightSize, scale: displayScale)
        let playerLight = SKSpriteNode(texture: lightTexture)
        playerLight.size = lightSize
        playerLight.position = playerNode?.position ?? positionFor(playerGrid)
        playerLight.zPosition = 0
        playerLight.alpha = 0.68
        playerLight.color = ArcadeStyle.Color.accentCyan
        playerLight.colorBlendFactor = 1.0
        playerLight.blendMode = .add
        container.addChild(playerLight)

        worldNode.addChild(container)

        fogNode = container
        fogTileMapNode = fogTileMap
        playerLightNode = playerLight

        _ = revealTiles(around: playerGrid, radius: fogRevealRadius, markDirty: false, playSound: false)
        updateFogMask()
    }

    private func updateFogMask() {
        guard fogIsEnabled else { return }
        updatePlayerLightPosition()
    }

    private var fogIsEnabled: Bool {
        levelConfig.enabledMechanics.contains(.fog)
    }

    private var fogRevealRadius: Int {
        max(1, levelConfig.fogRadius)
    }

    private func updatePlayerLightPosition() {
        guard let player = playerNode, let light = playerLightNode else { return }
        light.position = player.position
    }

    private func revealTile(_ point: GridPoint) -> Bool {
        guard fogIsEnabled, let maze = currentMaze else { return false }
        guard point.row >= 0, point.row < maze.rows, point.col >= 0, point.col < maze.cols else { return false }
        let inserted = exploredTiles.insert(point).inserted
        guard inserted else { return false }
        let mapRow = (maze.rows - 1) - point.row
        fogTileMapNode?.setTileGroup(nil, forColumn: point.col, row: mapRow)
        return true
    }

    @discardableResult
    private func revealTiles(around center: GridPoint, radius: Int, markDirty: Bool = true, playSound: Bool = true) -> Bool {
        guard fogIsEnabled, let maze = currentMaze else { return false }
        let clampedRadius = max(0, radius)
        var changed = false

        for row in max(0, center.row - clampedRadius)...min(maze.rows - 1, center.row + clampedRadius) {
            for col in max(0, center.col - clampedRadius)...min(maze.cols - 1, center.col + clampedRadius) {
                let dr = row - center.row
                let dc = col - center.col
                if dr * dr + dc * dc > clampedRadius * clampedRadius {
                    continue
                }
                if revealTile(GridPoint(row: row, col: col)) {
                    changed = true
                }
            }
        }

        if changed {
            if playSound {
                SoundFX.playFogReveal(on: self)
            }
            if markDirty {
                markExplorationPresentationDirty()
            }
        }
        return changed
    }

    private func refreshExplorationPresentation() {
        guard let maze = currentMaze else { return }
        let explored = fogIsEnabled ? exploredTiles : nil
        miniMapTexture = MiniMapNode.makeMapTexture(maze: maze, displayScale: displayScale, exploredTiles: explored)
        miniMapNode?.updateExplored(explored)
        overviewMapNode?.updateExplored(explored)
        miniMapNode?.updatePlayerPosition(playerGrid)
        overviewMapNode?.updatePlayerPosition(playerGrid)
    }

    private func markExplorationPresentationDirty() {
        needsExplorationRefresh = true
    }

    private func solidColorTexture(size: CGSize, color: SKColor, scale: CGFloat) -> SKTexture {
        let width = max(1, Int(size.width * scale))
        let height = max(1, Int(size.height * scale))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return SKTexture()
        }

        context.scaleBy(x: scale, y: scale)
        #if os(macOS)
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        #endif

        context.setFillColor(color.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        guard let image = context.makeImage() else { return SKTexture() }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        return texture
    }

    private func radialLightTexture(size: CGSize, scale: CGFloat) -> SKTexture {
        let width = max(1, Int(size.width * scale))
        let height = max(1, Int(size.height * scale))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return SKTexture()
        }

        context.scaleBy(x: scale, y: scale)
        #if os(macOS)
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        #endif

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) / 2
        let colors = [
            SKColor(white: 1.0, alpha: 0.55).cgColor,
            SKColor(white: 1.0, alpha: 0.18).cgColor,
            SKColor(white: 1.0, alpha: 0.0).cgColor
        ] as CFArray
        let locations: [CGFloat] = [0.0, 0.55, 1.0]
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else {
            return solidColorTexture(size: size, color: .clear, scale: scale)
        }

        context.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: radius,
            options: [.drawsAfterEndLocation]
        )

        guard let image = context.makeImage() else { return SKTexture() }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .linear
        return texture
    }

    private func updateGateVisuals() {
        let color = gateIsOpen ? SKColor(red: 0.35, green: 1.0, blue: 0.5, alpha: 1.0) : SKColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
        for node in gateNodes.values {
            node.color = color
        }
    }

    private func updateGateState(now: TimeInterval) {
        guard levelConfig.enabledMechanics.contains(.timingGates), !gateTiles.isEmpty else { return }
        let period = max(0.6, levelConfig.gatePeriod)
        guard period > 0 else { return }
        let cycle = period * 2
        let phase = now.truncatingRemainder(dividingBy: cycle)
        let open = phase < period
        if open != gateIsOpen {
            gateIsOpen = open
            updateGateVisuals()
        }
    }

    private func updateDoorVisuals() {
        let unlocked = doorsAreUnlocked
        let color = unlocked ? SKColor(red: 0.4, green: 1.0, blue: 0.6, alpha: 1.0) : SKColor(red: 1.0, green: 0.35, blue: 0.35, alpha: 1.0)
        for node in doorNodes.values {
            node.color = color
        }
    }

    private func activateSwitchIfNeeded(at point: GridPoint) {
        guard !switchActivated, switchNodes[point] != nil else { return }
        switchActivated = true
        SoundFX.playUnlock(on: self)
        for node in switchNodes.values {
            node.run(.group([
                .fadeAlpha(to: 0.35, duration: 0.12),
                .scale(to: 0.9, duration: 0.12)
            ]))
        }
        updateDoorVisuals()
        if botDifficulty == .hard {
            primeHardBotDirectionCache()
        }
    }

    private func directionForArrow(_ char: Character) -> MoveDirection? {
        switch char {
        case "^":
            return .up
        case "v":
            return .down
        case "<":
            return .left
        case ">":
            return .right
        default:
            return nil
        }
    }

    private func snap(_ point: CGPoint) -> CGPoint {
        CGPoint(x: round(point.x), y: round(point.y))
    }

    private func snapSize(_ size: CGSize) -> CGSize {
        CGSize(width: round(size.width), height: round(size.height))
    }

    private func minimapCardSize() -> CGSize {
        let safeWidth = size.width - safeAreaInsets.left - safeAreaInsets.right
        let cardWidth = safeWidth * Tuning.minimapWidthRatio
        let cardHeight = cardWidth * Tuning.minimapHeightRatio
        return snapSize(CGSize(width: cardWidth, height: cardHeight))
    }

    private func hudReservedHeight() -> CGFloat {
        ArcadeStyle.Metric.hudHeight
        + Tuning.hudTopMargin
    }

    private func playableScreenRect() -> CGRect {
        let safeLeft = -size.width / 2 + safeAreaInsets.left
        let safeRight = size.width / 2 - safeAreaInsets.right
        let screenBottom = -size.height / 2
        let screenTop = size.height / 2

        let hudTopHeight = max(Tuning.hudTopBandPx, hudReservedHeight())
        let topDeadzoneHeight = safeAreaInsets.top + Tuning.topDeadzoneExtra + hudTopHeight
        let bottomReserved = safeAreaInsets.bottom + minimapCardSize().height + Tuning.minimapBottomMargin + Tuning.hudBottomBandExtra

        let minY = screenBottom + bottomReserved
        let maxY = screenTop - topDeadzoneHeight
        let width = max(40, safeRight - safeLeft)
        let height = max(40, maxY - minY)

        if maxY <= minY + 10 {
            return CGRect(x: safeLeft, y: screenBottom + 10, width: width, height: max(40, screenTop - screenBottom - 20))
        }

        return CGRect(x: safeLeft, y: minY, width: width, height: height)
    }

    private func applyWorldOffsetForDeadzone() {
        let playable = playableScreenRect()
        worldNode.position = snap(CGPoint(x: playable.midX, y: playable.midY))
    }

    private func updateDebugHudLabel() {
        guard debugHudInfo else {
            cameraScaleLabel?.removeFromParent()
            cameraScaleLabel = nil
            return
        }
        if cameraScaleLabel == nil {
            let label = SKLabelNode(fontNamed: ArcadeFont.body)
            label.fontSize = 10
            label.fontColor = ArcadeStyle.Color.textMuted
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .top
            label.zPosition = 6000
            hudNode.addChild(label)
            cameraScaleLabel = label
        }

        guard let label = cameraScaleLabel else { return }
        let x = -size.width / 2 + safeAreaInsets.left + 8
        let y = size.height / 2 - safeAreaInsets.top - 6
        label.position = snap(CGPoint(x: x, y: y))
        label.text = String(
            format: "safe(%.0f %.0f %.0f %.0f) cam:%.2f hud:(%.0f %.0f)",
            safeAreaInsets.top,
            safeAreaInsets.left,
            safeAreaInsets.bottom,
            safeAreaInsets.right,
            cameraNode.xScale,
            hudNode.position.x,
            hudNode.position.y
        )
    }

    private func resultOverlayScaleFactor() -> CGFloat {
        let safeWidth = size.width - safeAreaInsets.left - safeAreaInsets.right
        let safeHeight = size.height - safeAreaInsets.top - safeAreaInsets.bottom
        let cardSize = ArcadeStyle.Metric.overlayCardSize
        let maxWidth = max(120, safeWidth - 24)
        let maxHeight = max(120, safeHeight - 120)
        let scale = min(1.0, maxWidth / cardSize.width, maxHeight / cardSize.height)
        return max(0.7, scale)
    }

    private func feedbackSafeRect() -> CGRect {
        let safeWidth = size.width - safeAreaInsets.left - safeAreaInsets.right
        let safeCenterX = (safeAreaInsets.left - safeAreaInsets.right) / 2
        let safeTop = size.height / 2 - safeAreaInsets.top
        let safeBottom = -size.height / 2 + safeAreaInsets.bottom
        let hudReserved = hudReservedHeight()
        let minimapReserved = minimapCardSize().height + Tuning.minimapBottomMargin

        let minY = safeBottom + minimapReserved + Tuning.feedbackBottomMargin
        let maxY = safeTop - hudReserved - Tuning.feedbackTopMargin
        let width = max(40, safeWidth - Tuning.feedbackHorizontalMargin * 2)
        let x = safeCenterX - width / 2

        if maxY <= minY + 4 {
            let fallbackHeight = max(40, safeTop - safeBottom - 16)
            return CGRect(x: safeCenterX - width / 2, y: safeBottom + 8, width: width, height: fallbackHeight)
        }

        return CGRect(x: x, y: minY, width: width, height: maxY - minY)
    }

    private func clampPoint(_ point: CGPoint, to rect: CGRect) -> CGPoint {
        let clampedX = min(max(point.x, rect.minX), rect.maxX)
        let clampedY = min(max(point.y, rect.minY), rect.maxY)
        return CGPoint(x: clampedX, y: clampedY)
    }

    private func clampValue(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
        min(maxValue, max(minValue, value))
    }

    private func makePauseHudIcon() -> SKNode {
        let root = SKNode()

        let glow = makeTintedHudIcon(
            assetName: "HudIconPause",
            size: CGSize(width: 17, height: 17),
            tint: ArcadeStyle.Color.accentMagenta
        )
        glow.alpha = 0.34
        glow.position = CGPoint(x: 0, y: 0.5)
        glow.zPosition = 1
        root.addChild(glow)

        let icon = makeTintedHudIcon(
            assetName: "HudIconPause",
            size: CGSize(width: 15, height: 15),
            tint: ArcadeStyle.Color.textPrimary
        )
        icon.position = CGPoint(x: 0, y: 0.5)
        root.addChild(icon)

        return root
    }

    private func makeTintedHudIcon(assetName: String, size: CGSize, tint: SKColor) -> SKSpriteNode {
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

    private func formattedClockTime(_ time: TimeInterval) -> String {
        let clamped = max(0, time)
        let minutes = Int(clamped / 60)
        let seconds = clamped - Double(minutes * 60)
        return String(format: "%02d:%05.2f", minutes, seconds)
    }

    private var isChallengeMode: Bool {
        if case .timeChallenge = runMode {
            return true
        }
        return false
    }

    private var isDailyMode: Bool {
        if case .dailyChallenge = runMode {
            return true
        }
        return false
    }

    private var botRaceEnabled: Bool {
        !isChallengeMode && botDifficulty != .off
    }

    private var activeThemeLevelId: Int {
        if isChallengeMode {
            return max(1, challengeMazeNumber)
        }
        return dailyDescriptor?.referenceLevelId ?? levelDefinition.id
    }

    private var cacheLevelIndex: Int {
        if let duration = challengeDuration {
            return 10_000 + duration.rawValue * 100 + challengeMazeNumber
        }
        if let dailyDescriptor {
            return dailyDescriptor.cacheLevelIndex
        }
        return levelIndex
    }

    private func challengeSeedSalt(for mazeNumber: Int) -> Int {
        challengeRunSeedSalt &+ mazeNumber &* 7_919
    }

    private func applySelectedSkin(to sprite: SKSpriteNode) {
        CosmeticRenderer.applyPlayerSkin(PlayerSkinStore.shared.selectedSkin, to: sprite, displayScale: displayScale)
    }

    private func displayedElapsedTime() -> TimeInterval {
        elapsedTime + addedOverviewPenalty
    }

    private func updateTimerLabel() {
        let text: String
        if let challengeDuration {
            let remaining = max(0, challengeDuration.seconds - displayedElapsedTime())
            text = formattedClockTime(remaining)
        } else {
            text = formattedClockTime(displayedElapsedTime())
        }
        guard text != lastRenderedTimerText else { return }
        lastRenderedTimerText = text
        timerLabel.text = text
        timerLabel.alpha = 1.0
        timerShadowLabel.text = text
        timerShadowLabel.alpha = 0.65
        layoutTimerLabelIfNeeded()
        updateLeftHudState()
    }

    private func layoutTimerLabelIfNeeded() {
        guard timerTextMaxWidth > 0 else { return }
        timerLabel.setScale(1.0)
        timerShadowLabel.setScale(1.0)
        timerLabel.position = timerTextBasePosition
        timerShadowLabel.position = snap(CGPoint(x: timerTextBasePosition.x + 1, y: timerTextBasePosition.y - 1))

        let measuredWidth = max(timerLabel.frame.width, timerShadowLabel.frame.width)
        guard measuredWidth > timerTextMaxWidth else { return }

        let scale = max(0.78, timerTextMaxWidth / measuredWidth)
        timerLabel.setScale(scale)
        timerShadowLabel.setScale(scale)
        timerLabel.position = timerTextBasePosition
        timerShadowLabel.position = snap(CGPoint(x: timerTextBasePosition.x + 1, y: timerTextBasePosition.y - 1))
    }

    private func openOverview() {
        guard overviewOverlay == nil, let maze = currentMaze else { return }
        isInOverviewMode = true
        queuedDirection = nil
        queuedTimestamp = nil
        forcedDirection = nil

        if currentGameState == .playing, runStartTime != nil {
            addedOverviewPenalty += overviewPenaltySeconds
            showOverviewPenalty()
            updateTimerLabel()
        }

        let overlay = SKNode()
        overlay.position = snap(.zero)
        overlay.zPosition = 9000
        overlay.setScale(1.0 / cameraNode.xScale)

        let dim = SKSpriteNode(color: ArcadeStyle.Color.overlayDim, size: size)
        dim.position = .zero
        dim.zPosition = 0
        overlay.addChild(dim)

        let safeTop = size.height / 2 - safeAreaInsets.top
        let safeBottom = -size.height / 2 + safeAreaInsets.bottom
        let safeHeight = max(100, safeTop - safeBottom)
        let maxWidth = min(size.width * 0.88, size.width - 80)
        let maxHeight = min(size.height * 0.68, safeHeight - 120)
        let mapSize = snapSize(CGSize(width: maxWidth, height: maxHeight))
        let explored = fogIsEnabled ? exploredTiles : nil
        let texture = miniMapTexture ?? MiniMapNode.makeMapTexture(maze: maze, displayScale: displayScale, exploredTiles: explored)
        let overviewMap = MiniMapNode(maze: maze, size: mapSize, mapTexture: texture, cardStyle: .overlay, displayScale: displayScale, exploredTiles: explored)
        let mapCenterY = safeBottom + safeHeight * 0.58
        overviewMap.position = snap(CGPoint(x: 0, y: mapCenterY))
        overviewMap.updatePlayerPosition(playerGrid)
        overviewMap.zPosition = 2
        overlay.addChild(overviewMap)
        overviewMapNode = overviewMap

        let hint = SKLabelNode(fontNamed: ArcadeFont.body)
        hint.text = "TAP TO RETURN"
        hint.fontSize = 14
        hint.fontColor = ArcadeStyle.Color.textPrimary
        let hintY = max(safeBottom + 28, overviewMap.position.y - mapSize.height / 2 - 26)
        hint.position = snap(CGPoint(x: 0, y: hintY))
        hint.zPosition = 3
        overlay.addChild(hint)

        let closeButton = ArcadeButtonNode(text: "X", size: CGSize(width: 36, height: 36))
        closeButton.label.fontSize = 14
        closeButton.name = "btn_overview_close"
        closeButton.position = snap(CGPoint(x: mapSize.width / 2 - 26, y: mapSize.height / 2 - 26))
        overviewMap.addChild(closeButton)
        overviewCloseButton = closeButton

        overviewOverlay = overlay
        cameraNode.addChild(overlay)
    }

    private func closeOverview() {
        overviewOverlay?.removeFromParent()
        overviewOverlay = nil
        overviewMapNode = nil
        overviewCloseButton = nil
        isInOverviewMode = false
        activeButton?.setPressed(false)
        activeButton = nil
        if currentGameState == .playing {
            applyGameplayCameraScale()
        }
    }

    private func showOverviewPenalty() {
        guard let timerCard = timerCard else { return }
        let label = SKLabelNode(fontNamed: ArcadeFont.digits)
        label.text = String(format: "+%.2fs", overviewPenaltySeconds)
        label.fontSize = 12
        label.fontColor = ArcadeStyle.Color.accentMagenta
        label.alpha = 0
        let x = timerCard.position.x + timerCard.size.width / 2 - 28
        let y = timerCard.position.y + timerCard.size.height / 2 + 10
        label.position = snap(CGPoint(x: x, y: y))
        label.zPosition = 200
        hudNode.addChild(label)

        label.run(.sequence([
            .fadeIn(withDuration: 0.05),
            .group([
                .moveBy(x: 0, y: 12, duration: 0.55),
                .fadeOut(withDuration: 0.55)
            ]),
            .removeFromParent()
        ]))
    }

    private func updateTimer(now: TimeInterval) {
        guard let start = runStartTime else {
            elapsedTime = 0
            lastTimerUpdate = nil
            return
        }
        let paused = accumulatedPausedTime
        elapsedTime = max(0, now - start - paused)
        lastTimerUpdate = now
    }

    private func isWalkable(_ row: Int, _ col: Int) -> Bool {
        guard let tile = tileAt(GridPoint(row: row, col: col)) else { return false }
        if tile == "#" { return false }
        if tile == "D" && !doorsAreUnlocked { return false }
        if tile == "G" && !gateIsOpen { return false }
        return true
    }

    private func tileAt(_ point: GridPoint) -> Character? {
        currentMaze?.tile(at: point)
    }

    private func neighborCount(_ row: Int, _ col: Int) -> Int {
        var count = 0
        for direction in MoveDirection.allCases {
            let nextRow = row + direction.deltaRow
            let nextCol = col + direction.deltaCol
            if isWalkable(nextRow, nextCol) {
                count += 1
            }
        }
        return count
    }

    private func isIntersectionOrCorner(_ row: Int, _ col: Int) -> Bool {
        let directions = MoveDirection.allCases.filter { direction in
            isWalkable(row + direction.deltaRow, col + direction.deltaCol)
        }
        let count = neighborCount(row, col)
        if count >= 3 {
            return true
        }
        if count == 2 {
            let hasUp = directions.contains(.up)
            let hasDown = directions.contains(.down)
            let hasLeft = directions.contains(.left)
            let hasRight = directions.contains(.right)
            let opposite = (hasUp && hasDown) || (hasLeft && hasRight)
            return !opposite
        }
        return false
    }

    private func validTurn(fromTile tile: GridPoint, direction: MoveDirection) -> Bool {
        let next = tile.moved(by: direction)
        return isWalkable(next.row, next.col)
    }

    private func shouldTurn(atTile tile: GridPoint, queuedDirection: MoveDirection) -> Bool {
        guard isIntersectionOrCorner(tile.row, tile.col) else { return false }
        guard let currentDirection = currentDirection, queuedDirection != currentDirection else { return false }
        return validTurn(fromTile: tile, direction: queuedDirection)
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

    private func updateBackground() {
        backgroundNode?.removeAllActions()
        backgroundNode?.removeFromParent()
        let backgroundSize = snapSize(CGSize(width: size.width * 1.18, height: size.height * 1.18))
        let baseTexture = NeonFactory.backgroundNode(size: backgroundSize, theme: currentTheme).texture
        let background = SKSpriteNode(texture: baseTexture)
        background.size = backgroundSize
        background.position = snap(.zero)
        background.zPosition = -100
        background.setScale(1.0)

        let gridOverlay = SKSpriteNode(texture: NeonFactory.gridOverlayTexture(size: backgroundSize, theme: currentTheme))
        gridOverlay.size = backgroundSize
        gridOverlay.position = .zero
        gridOverlay.zPosition = 1
        gridOverlay.alpha = 0.44
        background.addChild(gridOverlay)

        let glowOverlay = SKSpriteNode(texture: NeonFactory.glowFieldTexture(size: backgroundSize, theme: currentTheme))
        glowOverlay.size = backgroundSize
        glowOverlay.position = .zero
        glowOverlay.zPosition = 2
        glowOverlay.alpha = 0.42
        background.addChild(glowOverlay)

        let sparkOverlay = SKSpriteNode(texture: NeonFactory.sparkTexture(size: backgroundSize, theme: currentTheme))
        sparkOverlay.size = backgroundSize
        sparkOverlay.position = .zero
        sparkOverlay.zPosition = 3
        sparkOverlay.alpha = 0.32
        background.addChild(sparkOverlay)

        let scanSize = snapSize(CGSize(width: backgroundSize.width * 0.94, height: max(120, backgroundSize.height * 0.16)))
        let scanBand = SKSpriteNode(texture: NeonFactory.scanBandTexture(size: scanSize, theme: currentTheme))
        scanBand.size = scanSize
        scanBand.position = CGPoint(x: -backgroundSize.width * 0.16, y: backgroundSize.height * 0.08)
        scanBand.zPosition = 4
        scanBand.alpha = 0.0
        scanBand.blendMode = .add
        background.addChild(scanBand)

        let backgroundDrift = SKAction.sequence([
            .moveBy(x: 12, y: -8, duration: 8.0),
            .moveBy(x: -18, y: 10, duration: 9.0),
            .moveBy(x: 6, y: -4, duration: 7.0)
        ])
        background.run(.repeatForever(backgroundDrift), withKey: "bgDrift")

        let gridDrift = SKAction.sequence([
            .moveBy(x: -18, y: 12, duration: 18.0),
            .moveBy(x: 24, y: -16, duration: 20.0)
        ])
        gridOverlay.run(.repeatForever(gridDrift), withKey: "gridDrift")

        let glowPulse = SKAction.sequence([
            .fadeAlpha(to: 0.52, duration: 3.2),
            .fadeAlpha(to: 0.32, duration: 3.8)
        ])
        glowOverlay.run(.repeatForever(glowPulse), withKey: "glowPulse")

        let sparkPulse = SKAction.sequence([
            .group([
                .fadeAlpha(to: 0.38, duration: 2.6),
                .moveBy(x: 4, y: -3, duration: 2.6)
            ]),
            .group([
                .fadeAlpha(to: 0.22, duration: 2.8),
                .moveBy(x: -4, y: 3, duration: 2.8)
            ])
        ])
        sparkOverlay.run(.repeatForever(sparkPulse), withKey: "sparkPulse")

        let resetScan = SKAction.run {
            scanBand.position = CGPoint(x: -backgroundSize.width * 0.18, y: backgroundSize.height * 0.08)
            scanBand.alpha = 0.0
        }
        let scanPass = SKAction.sequence([
            .wait(forDuration: 1.2),
            .run { scanBand.alpha = 0.0 },
            .group([
                .moveBy(x: backgroundSize.width * 0.36, y: 0, duration: 5.8),
                .sequence([
                    .fadeAlpha(to: 0.16, duration: 1.0),
                    .fadeAlpha(to: 0.0, duration: 1.2)
                ])
            ]),
            .wait(forDuration: 3.8),
            resetScan
        ])
        scanBand.run(.repeatForever(scanPass), withKey: "scanPass")

        backgroundNode = background
        cameraNode.addChild(background)
    }

    private func layoutWorldPosition() {
        applyWorldOffsetForDeadzone()
    }

    private func updateCameraScale(for maze: MazeData) {
        gameplayCameraScale = computeTargetGameplayCameraScale(for: maze)
        baseCameraScale = gameplayCameraScale
        cameraFollowsPlayer = true
        applyGameplayCameraScale(animated: true)
    }

    private func updateCameraPosition(animated: Bool, targetWorldPosition: CGPoint? = nil) {
        let worldTarget = targetWorldPosition ?? playerNode?.position ?? .zero
        let bias = tileSize * Tuning.cameraFollowBiasTiles
        let biasedTarget = CGPoint(x: worldTarget.x, y: worldTarget.y + bias)
        let worldTargetScene = worldNode.convert(biasedTarget, to: self)
        let playable = playableScreenRect()
        let desiredScreen = CGPoint(x: playable.midX, y: playable.midY)
        let target = CGPoint(
            x: worldTargetScene.x - desiredScreen.x * gameplayCameraScale,
            y: worldTargetScene.y - desiredScreen.y * gameplayCameraScale
        )
        let clamped = applyCameraClampingUsingPlayableArea(target, cameraScale: gameplayCameraScale)
        if animated {
            cameraNode.removeAction(forKey: "cameraStep")
            let move = SKAction.move(to: clamped, duration: stepDuration)
            move.timingMode = .linear
            cameraNode.run(move, withKey: "cameraStep")
        } else {
            cameraNode.position = clamped
        }
    }

    private func applyGameplayCameraScale(animated: Bool = false) {
        cameraNode.removeAllActions()
        if animated {
            let zoom = SKAction.scale(to: gameplayCameraScale, duration: 0.2)
            zoom.timingMode = .easeOut
            cameraNode.run(zoom, withKey: "gameplayZoom")
        } else {
            cameraNode.setScale(gameplayCameraScale)
        }
        hudNode.setScale(1.0)
        comboBadge.setScale(1.0)

        let clamped = applyCameraClampingUsingPlayableArea(cameraNode.position, cameraScale: gameplayCameraScale)
        cameraNode.position = clamped
        updateDebugHudLabel()
    }

    private func clampCameraPosition(_ target: CGPoint) -> CGPoint {
        return applyCameraClampingUsingPlayableArea(target, cameraScale: cameraNode.xScale)
    }

    private func applyCameraClampingUsingPlayableArea(_ target: CGPoint, cameraScale: CGFloat) -> CGPoint {
        guard mazeBounds != .zero else { return snap(target) }
        let mazeRect = mazeBounds.offsetBy(dx: worldNode.position.x, dy: worldNode.position.y)
        let playable = playableScreenRect()
        var minX = mazeRect.minX - playable.minX * cameraScale
        var maxX = mazeRect.maxX - playable.maxX * cameraScale
        var minY = mazeRect.minY - playable.minY * cameraScale
        var maxY = mazeRect.maxY - playable.maxY * cameraScale

        if minX > maxX {
            minX = mazeRect.midX
            maxX = mazeRect.midX
        }
        if minY > maxY {
            minY = mazeRect.midY
            maxY = mazeRect.midY
        }

        let clampedX = min(max(target.x, minX), maxX)
        let clampedY = min(max(target.y, minY), maxY)
        return snap(CGPoint(x: clampedX, y: clampedY))
    }

    private func computeTargetGameplayCameraScale(for maze: MazeData) -> CGFloat {
        let maxDimension = max(maze.rows, maze.cols)
        let targetTilesY = maxDimension >= Tuning.largeMazeThreshold ? Tuning.targetTilesYLarge : Tuning.targetTilesYNormal
        let playableHeight = playableScreenRect().height
        let desiredTilePx = clampValue(playableHeight / targetTilesY, min: Tuning.minTilePx, max: Tuning.maxTilePx)
        let scale = tileSize / max(1, desiredTilePx)
        return clampValue(scale, min: 0.45, max: 1.6)
    }

    private func gameplayViewportHeight() -> CGFloat {
        playableScreenRect().height
    }

    private func setGameState(_ newState: GameState) {
        guard currentGameState != newState else { return }
        currentGameState = newState
        switch newState {
        case .playing:
            lastTimerUpdate = nil
            applyGameplayCameraScale()
        case .paused, .levelCompleted:
            lastTimerUpdate = nil
        case .idle:
            lastTimerUpdate = nil
        }
    }

    private func beginPlayingIfNeeded() {
        let now = CACurrentMediaTime()
        dismissSwipeHintIfNeeded(markShown: true)
        if currentGameState == .idle {
            setGameState(.playing)
            lastTimerUpdate = now
        }
        if runStartTime == nil {
            runStartTime = now
            accumulatedPausedTime = 0
            pauseStartTime = nil
        }
        startBotRaceIfNeeded()
    }

    private func handleSwipe(_ direction: MoveDirection) {
        guard !isLoadingMaze else { return }
        guard tutorialOverlay == nil else { return }
        guard currentMaze != nil else { return }
        guard !isInOverviewMode else { return }
        guard currentGameState == .playing || currentGameState == .idle else { return }
        let now = CACurrentMediaTime()
        if isMoving {
            queuedDirection = direction
            queuedTimestamp = now
        } else {
            queuedDirection = nil
            queuedTimestamp = nil
            startSlide(direction: direction)
        }
    }

    private func startSlide(direction: MoveDirection) {
        guard validTurn(fromTile: playerGrid, direction: direction) else {
            return
        }
        beginPlayingIfNeeded()
        currentDirection = direction
        isMoving = true
        startTrailEmissionIfNeeded()
        stepForward()
    }

    private func stepForward() {
        guard currentGameState == .playing else { return }
        let directionToUse: MoveDirection
        if let forced = forcedDirection {
            directionToUse = forced
            currentDirection = forced
            forcedDirection = nil
        } else if let direction = currentDirection {
            directionToUse = direction
        } else {
            stopSliding(reason: .manual)
            return
        }

        let next = playerGrid.moved(by: directionToUse)
        guard isWalkable(next.row, next.col) else {
            let tile = tileAt(next)
            if tile == "G" || (tile == "D" && !doorsAreUnlocked) {
                stopSliding(reason: .manual)
            } else {
                stopSliding(reason: .wallHit)
            }
            return
        }

        if fogIsEnabled, revealTile(next) {
            markExplorationPresentationDirty()
        }

        let destination = positionFor(next)
        let moveAction = SKAction.move(to: destination, duration: stepDuration)
        moveAction.timingMode = .linear
        let arrivalAction = SKAction.run { [weak self] in
            self?.handleArrival(at: next)
        }
        playerNode?.run(SKAction.sequence([moveAction, arrivalAction]), withKey: "slideStep")
        updateCameraPosition(animated: true, targetWorldPosition: destination)
    }

    private func handleArrival(at point: GridPoint) {
        let landing = processLanding(at: point)
        let arrivalTime = CACurrentMediaTime()
        if currentGameState == .playing,
           let queuedDirection = queuedDirection,
           isIntersectionOrCorner(landing.point.row, landing.point.col) {
            let feedbackPosition = playerNode?.position ?? positionFor(landing.point)
            if let forced = landing.forcedDirection {
                if queuedDirection == forced, validTurn(fromTile: landing.point, direction: forced) {
                    let rating = timingRating(arrivalTime: arrivalTime, inputTime: queuedTimestamp)
                    let perfectPlus = rating == .perfect && (landing.passedGate || landing.forcedDirection != nil)
                    handleRating(rating, at: feedbackPosition, now: arrivalTime, perfectPlus: perfectPlus)
                    currentDirection = forced
                } else if let currentDirection = currentDirection, queuedDirection != currentDirection {
                    handlePenalty(now: arrivalTime)
                }
                self.queuedDirection = nil
                queuedTimestamp = nil
            } else if shouldTurn(atTile: landing.point, queuedDirection: queuedDirection) {
                let rating = timingRating(arrivalTime: arrivalTime, inputTime: queuedTimestamp)
                let perfectPlus = rating == .perfect && landing.passedGate
                handleRating(rating, at: feedbackPosition, now: arrivalTime, perfectPlus: perfectPlus)
                currentDirection = queuedDirection
                self.queuedDirection = nil
                queuedTimestamp = nil
            } else if let currentDirection = currentDirection, queuedDirection != currentDirection {
                handlePenalty(now: arrivalTime)
                self.queuedDirection = nil
                queuedTimestamp = nil
            }
        }

        if let forced = landing.forcedDirection {
            currentDirection = forced
            forcedDirection = nil
        }

        if fogIsEnabled, revealTiles(around: landing.point, radius: fogRevealRadius) {
            markExplorationPresentationDirty()
        }

        guard currentGameState == .playing else { return }
        stepForward()
    }

    private func timingRating(arrivalTime: TimeInterval, inputTime: TimeInterval?) -> TurnRating {
        guard let inputTime = inputTime else { return .ok }
        let delta = max(0, arrivalTime - inputTime)
        if delta <= perfectWindow { return .perfect }
        if delta <= goodWindow { return .good }
        return .ok
    }

    private func comboRating(from rating: TurnRating) -> ComboRating {
        switch rating {
        case .perfect:
            return .perfect
        case .good:
            return .good
        case .ok:
            return .ok
        }
    }

    private func handleRating(_ rating: TurnRating, at position: CGPoint, now: TimeInterval, perfectPlus: Bool) {
        let comboRating = comboRating(from: rating)
        let event = comboSystem.applyRating(comboRating, now: now)
        let labelOverride = perfectPlus && rating == .perfect ? "PERFECT+" : nil
        let colorOverride = perfectPlus && rating == .perfect ? ArcadeStyle.Color.accentMagenta : nil
        handleComboEvent(event, rating: rating, at: position, ratingLabelOverride: labelOverride, ratingColorOverride: colorOverride)

        if perfectPlus && rating == .perfect {
            let bonusEvent = comboSystem.applyBonus(amount: 1, now: now)
            handleComboEvent(bonusEvent, rating: nil, at: position)
        }

        let flowRating: FlowRating
        switch rating {
        case .perfect:
            flowRating = .perfect
        case .good:
            flowRating = .good
        case .ok:
            flowRating = .ok
        }
        let flowEvent = flowSystem.apply(rating: flowRating, now: now)
        handleFlowEvent(flowEvent, at: position)
    }

    private func handlePenalty(now: TimeInterval) {
        let event = comboSystem.applyPenalty(now: now)
        handleComboEvent(event, rating: nil, at: playerNode?.position ?? positionFor(playerGrid))

        let flowEvent = flowSystem.apply(rating: .penalty, now: now)
        handleFlowEvent(flowEvent, at: playerNode?.position ?? positionFor(playerGrid))
    }

    private func handleFlowEvent(_ event: FlowEvent, at position: CGPoint) {
        updateFlowBar()
        if event.delta > 0 {
            animateFlowHud(triggered: event.triggered)
        }
        guard event.triggered else { return }
        if Tuning.enableFlowShards {
            showFlowShards(at: position)
        }
        if Tuning.enableFlowFloatingLabel {
            showFlowLabel(points: event.pointsGained, at: position)
        }
    }

    private func showFlowShards(at position: CGPoint) {
        let count = 4
        for index in 0..<count {
            let shard = dequeueFlowShard()
            shard.position = position
            shard.zPosition = 28
            shard.zRotation = CGFloat(index) * (.pi * 2 / CGFloat(count))
            worldNode.addChild(shard)
            let angle = shard.zRotation
            let dx = cos(angle) * tileSize * 0.6
            let dy = sin(angle) * tileSize * 0.6
            shard.run(.sequence([
                .group([
                    .moveBy(x: dx, y: dy, duration: 0.22),
                    .fadeOut(withDuration: 0.22)
                ]),
                .run { [weak self, weak shard] in
                    guard let self, let shard else { return }
                    self.recycleFlowShard(shard)
                }
            ]))
        }
    }

    private func showFlowLabel(points: Int, at position: CGPoint) {
        let label = dequeueFlowLabel()
        label.text = points > 1 ? "FLOW +\(points)" : "FLOW +1"
        label.fontSize = 18
        label.fontColor = ArcadeStyle.Color.accentMagenta
        let safeRect = feedbackSafeRect()
        let desiredWorld = CGPoint(x: position.x, y: position.y + tileSize * 1.6)
        let desiredScene = worldNode.convert(desiredWorld, to: self)
        let clampedScene = clampPoint(desiredScene, to: safeRect)
        let clampedWorld = worldNode.convert(clampedScene, from: self)
        label.position = snap(clampedWorld)
        label.zPosition = 30
        label.alpha = 0
        label.setScale(0.7)
        worldNode.addChild(label)

        label.run(.sequence([
            .group([
                .fadeIn(withDuration: 0.06),
                .scale(to: 1.1, duration: 0.06)
            ]),
            .group([
                .moveBy(x: 0, y: tileSize * 0.4, duration: 0.25),
                .fadeOut(withDuration: 0.25)
            ]),
            .run { [weak self, weak label] in
                guard let self, let label else { return }
                self.recycleFlowLabel(label)
            }
        ]))
    }

    private func startTrailEmissionIfNeeded() {
        guard currentGameState == .playing || currentGameState == .idle else { return }
        guard let player = playerNode, player.action(forKey: "trailEmitter") == nil else { return }
        let emit = SKAction.run { [weak self] in
            self?.emitTrailParticle()
        }
        player.run(.repeatForever(.sequence([emit, .wait(forDuration: 0.055)])), withKey: "trailEmitter")
    }

    private func stopTrailEmission() {
        playerNode?.removeAction(forKey: "trailEmitter")
    }

    private func emitTrailParticle(extraBurst: Bool = false, origin: CGPoint? = nil) {
        guard let player = playerNode else { return }
        let style = CosmeticsStore.shared.selectedTrail
        let baseSize = tileSize * (style == .smoothLight ? 0.24 : 0.18)
        let size = snapSize(CGSize(width: baseSize, height: baseSize))
        let particle = SKSpriteNode(texture: TextureFactory.shared.trailParticleTexture(size: size, style: style))
        particle.position = origin ?? player.position
        particle.zPosition = 17
        particle.alpha = extraBurst ? 0.92 : 0.72
        particle.blendMode = .add

        let randomX = CGFloat.random(in: -tileSize * 0.08...tileSize * 0.08)
        let randomY = CGFloat.random(in: -tileSize * 0.08...tileSize * 0.08)
        particle.position.x += randomX
        particle.position.y += randomY
        particle.color = style.accentColor
        particle.colorBlendFactor = 0.24
        trailNode.addChild(particle)

        let driftMultiplier: CGFloat = extraBurst ? 0.42 : 0.22
        let drift = CGPoint(
            x: CGFloat.random(in: -tileSize * driftMultiplier...tileSize * driftMultiplier),
            y: CGFloat.random(in: -tileSize * driftMultiplier...tileSize * driftMultiplier)
        )
        let fadeDuration: TimeInterval = extraBurst ? 0.28 : 0.2
        let scaleUp: CGFloat = style == .pulseTrail || style == .energyBurst ? 1.18 : 1.05
        particle.run(.sequence([
            .group([
                .moveBy(x: drift.x, y: drift.y, duration: fadeDuration),
                .sequence([
                    .scale(to: scaleUp, duration: fadeDuration * 0.45),
                    .scale(to: 0.65, duration: fadeDuration * 0.55)
                ]),
                .fadeOut(withDuration: fadeDuration)
            ]),
            .removeFromParent()
        ]))
    }

    private func emitTrailComboBurst(rating: TurnRating, at position: CGPoint) {
        let style = CosmeticsStore.shared.selectedTrail
        let burstCount = rating == .perfect ? 6 : 4
        guard style == .classicNeon || style == .electricSparks || style == .pixelTrail || style == .pulseTrail || style == .energyBurst || style == .orbitTrail || style == .smoothLight else { return }
        for _ in 0..<burstCount {
            emitTrailParticle(extraBurst: true, origin: position)
        }
    }

    private func refreshTrailOrbit() {
        trailOrbitNode?.removeFromParent()
        trailOrbitNode = nil
        guard CosmeticsStore.shared.selectedTrail == .orbitTrail, let player = playerNode else { return }

        let orbitRoot = SKNode()
        orbitRoot.zPosition = 19
        player.addChild(orbitRoot)
        trailOrbitNode = orbitRoot

        for index in 0..<3 {
            let container = SKNode()
            container.zRotation = CGFloat(index) * (.pi * 2 / 3)
            let size = snapSize(CGSize(width: tileSize * 0.12, height: tileSize * 0.12))
            let dot = SKSpriteNode(texture: TextureFactory.shared.trailParticleTexture(size: size, style: .orbitTrail))
            dot.position = CGPoint(x: tileSize * 0.28, y: 0)
            dot.alpha = 0.75 - CGFloat(index) * 0.1
            dot.zPosition = 1
            container.addChild(dot)
            container.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 1.8 + Double(index) * 0.35)))
            orbitRoot.addChild(container)
        }
    }

    @discardableResult
    private func showRatingLabel(_ rating: TurnRating, at position: CGPoint, textOverride: String? = nil, colorOverride: SKColor? = nil) -> SKLabelNode {
        let label = dequeueRatingLabel()
        label.text = textOverride ?? rating.rawValue
        label.fontSize = rating == .perfect ? 20 : 16
        label.fontColor = colorOverride ?? rating.color

        // Centered, screen-space placement with small jitter + rotation.
        let safeRect = feedbackSafeRect()
        let center = CGPoint(x: safeRect.midX, y: safeRect.midY)
        let jitterLimitX = min(tileSize * 0.35, safeRect.width * 0.12)
        let jitterLimitY = min(tileSize * 0.25, safeRect.height * 0.12)
        let jitterX = CGFloat.random(in: -jitterLimitX...jitterLimitX)
        let jitterY = CGFloat.random(in: -jitterLimitY...jitterLimitY)
        let desiredScene = CGPoint(x: center.x + jitterX, y: center.y + jitterY)
        let clampedScene = clampPoint(desiredScene, to: safeRect)

        label.position = snap(clampedScene)
        label.zPosition = 30
        label.alpha = 1
        label.zRotation = CGFloat.random(in: -0.18...0.18)
        label.setScale(rating == .perfect ? 0.92 : 0.96)
        hudNode.addChild(label)

        let endScene = clampPoint(CGPoint(x: clampedScene.x, y: clampedScene.y + tileSize * 0.45), to: safeRect)
        let endPosition = snap(endScene)
        let popScale: CGFloat = rating == .perfect ? 1.25 : 1.05
        let popDuration = rating == .perfect ? 0.035 : 0.03
        let moveDuration = rating == .perfect ? 0.2 : 0.16

        label.run(.sequence([
            .scale(to: popScale, duration: popDuration),
            .group([
                .move(to: endPosition, duration: moveDuration),
                .fadeOut(withDuration: moveDuration)
            ]),
            .run { [weak self, weak label] in
                guard let self, let label else { return }
                self.recycleRatingLabel(label)
            }
        ]))

        return label
    }

    private enum StopReason {
        case wallHit
        case completed
        case manual
    }

    private func stopSliding(reason: StopReason) {
        playerNode?.removeAction(forKey: "slideStep")
        stopTrailEmission()
        isMoving = false
        currentDirection = nil
        forcedDirection = nil
        queuedDirection = nil
        queuedTimestamp = nil
        if reason == .wallHit {
            handlePenalty(now: CACurrentMediaTime())
        }
    }

    private func handleComboEvent(_ event: ComboEvent, rating: TurnRating?, at position: CGPoint, ratingLabelOverride: String? = nil, ratingColorOverride: SKColor? = nil) {
        if event.expired {
            updateComboBadge(combo: 0, rating: nil, animate: false)
            return
        }

        if event.haptic {
            playComboHaptic()
        }
        if let sound = event.sound {
            playComboSound(sound)
        }
        var milestoneDelay: TimeInterval = 0
        var feedbackLabel: SKLabelNode?
        if let rating = rating, event.showRatingLabel {
            feedbackLabel = showRatingLabel(rating, at: position, textOverride: ratingLabelOverride, colorOverride: ratingColorOverride)
            milestoneDelay = 0.05
        }
        if let milestone = event.milestone, event.showMilestoneLabel {
            scheduleMilestoneLabel(milestone, delay: milestoneDelay)
        }
        if Tuning.enableCameraPulseOnPerfect, rating == .perfect && event.delta > 0 {
            pulseCamera()
        }

        if let rating = rating, event.delta > 0 {
            emitTrailComboBurst(rating: rating, at: position)
            triggerComboImpact(combo: event.combo, rating: rating, feedbackLabel: feedbackLabel)
        }

        updateComboBadge(combo: event.combo, rating: rating, animate: event.delta > 0)
    }

    private func triggerComboImpact(combo: Int, rating: TurnRating, feedbackLabel: SKLabelNode?) {
        guard combo >= Tuning.comboDisplayThreshold else { return }

        let comboWeight = min(CGFloat(combo - Tuning.comboDisplayThreshold + 1), 5)
        let ratingBoost: CGFloat = rating == .perfect ? 1.2 : 1.0
        let intensity = comboWeight * ratingBoost

        rumbleScreenForCombo(intensity: intensity)
        if let feedbackLabel {
            rumbleDisplayForCombo(feedbackLabel, intensity: intensity, rating: rating)
        }
    }

    private func rumbleScreenForCombo(intensity: CGFloat) {
        let playable = playableScreenRect()
        let worldBasePosition = snap(CGPoint(x: playable.midX, y: playable.midY))
        let worldOffset = Tuning.comboScreenShakeBase + intensity * 0.16
        let hudOffset = Tuning.comboHudShakeBase + intensity * 0.10
        let rotation = Tuning.comboRotationBase * intensity
        let direction: CGFloat = Bool.random() ? 1 : -1

        worldNode.removeAction(forKey: "comboScreenRumble")
        hudNode.removeAction(forKey: "comboHudRumble")
        backgroundNode?.removeAction(forKey: "comboBackgroundPulse")

        worldNode.position = worldBasePosition
        worldNode.zRotation = 0
        hudNode.position = .zero
        hudNode.zRotation = 0

        let worldShake = SKAction.sequence([
            .group([
                .moveBy(x: worldOffset * direction, y: -worldOffset * 0.28, duration: 0.028),
                .rotate(toAngle: rotation * direction, duration: 0.028, shortestUnitArc: true)
            ]),
            .group([
                .moveBy(x: -worldOffset * 1.45 * direction, y: worldOffset * 0.42, duration: 0.045),
                .rotate(toAngle: -rotation * 0.72 * direction, duration: 0.045, shortestUnitArc: true)
            ]),
            .group([
                .move(to: worldBasePosition, duration: 0.08),
                .rotate(toAngle: 0, duration: 0.08, shortestUnitArc: true)
            ])
        ])
        worldNode.run(worldShake, withKey: "comboScreenRumble")

        let hudShake = SKAction.sequence([
            .group([
                .moveBy(x: hudOffset * direction * 0.65, y: hudOffset * 0.18, duration: 0.028),
                .rotate(toAngle: rotation * direction * 0.45, duration: 0.028, shortestUnitArc: true)
            ]),
            .group([
                .moveBy(x: -hudOffset * 1.05 * direction, y: -hudOffset * 0.26, duration: 0.045),
                .rotate(toAngle: -rotation * direction * 0.32, duration: 0.045, shortestUnitArc: true)
            ]),
            .group([
                .move(to: .zero, duration: 0.08),
                .rotate(toAngle: 0, duration: 0.08, shortestUnitArc: true)
            ])
        ])
        hudNode.run(hudShake, withKey: "comboHudRumble")

        let bgPulse = SKAction.sequence([
            .scale(to: Tuning.comboBackgroundPulseScale, duration: 0.04),
            .scale(to: 1.0, duration: 0.10)
        ])
        backgroundNode?.run(bgPulse, withKey: "comboBackgroundPulse")
    }

    private func rumbleDisplayForCombo(_ label: SKLabelNode, intensity: CGFloat, rating: TurnRating) {
        let offset = Tuning.comboDisplayShakeBase + intensity * 0.18
        let rotation = Tuning.comboRotationBase * intensity * (rating == .perfect ? 1.8 : 1.2)
        let direction: CGFloat = Bool.random() ? 1 : -1

        label.removeAction(forKey: "comboDisplayRumble")
        let shake = SKAction.sequence([
            .group([
                .moveBy(x: offset * direction, y: offset * 0.18, duration: 0.026),
                .rotate(byAngle: rotation * direction, duration: 0.026)
            ]),
            .group([
                .moveBy(x: -offset * 1.55 * direction, y: -offset * 0.22, duration: 0.04),
                .rotate(byAngle: -rotation * 1.6 * direction, duration: 0.04)
            ]),
            .group([
                .moveBy(x: offset * 0.55 * direction, y: offset * 0.04, duration: 0.05),
                .rotate(toAngle: 0, duration: 0.05, shortestUnitArc: true)
            ])
        ])
        label.run(shake, withKey: "comboDisplayRumble")
    }

    private func updateComboBadge(combo: Int, rating: TurnRating?, animate: Bool) {
        guard let card = comboCard else { return }
        if combo < Tuning.comboDisplayThreshold {
            card.removeAllActions()
            if card.alpha > 0 {
                card.run(.fadeOut(withDuration: 0.1))
            } else {
                card.alpha = 0
            }
            comboLabel.text = "x0"
            perfectLabel.text = "FLOW CHAIN"
            return
        }

        comboLabel.text = "x\(combo)"
        if let rating = rating {
            comboLabel.fontColor = rating.color
            perfectLabel.text = rating == .perfect ? "PERFECT CHAIN" : rating.rawValue
            perfectLabel.fontColor = rating.color
        } else {
            comboLabel.fontColor = ArcadeStyle.Color.accentCyan
            perfectLabel.text = "FLOW CHAIN"
            perfectLabel.fontColor = ArcadeStyle.Color.textPrimary
        }

        if card.alpha == 0 {
            card.alpha = 0
            card.run(.fadeIn(withDuration: 0.12))
        }

        if animate {
            card.removeAction(forKey: "comboPulse")
            let baseScale = max(card.xScale, 0.001)
            let up = SKAction.group([
                .scale(to: baseScale * 1.08, duration: 0.08),
                .fadeAlpha(to: 1.0, duration: 0.08)
            ])
            let down = SKAction.group([
                .scale(to: baseScale, duration: 0.12),
                .fadeAlpha(to: 0.96, duration: 0.12)
            ])
            card.run(.sequence([up, down]), withKey: "comboPulse")
        }
    }

    private func animateFlowHud(triggered: Bool) {
        guard let card = flowCard else { return }
        card.removeAction(forKey: "flowPulse")
        let baseScale = max(card.xScale, 0.001)
        let pulseUp = SKAction.scale(to: baseScale * (triggered ? 1.08 : 1.04), duration: 0.08)
        let pulseDown = SKAction.scale(to: baseScale, duration: 0.12)
        card.run(.sequence([pulseUp, pulseDown]), withKey: "flowPulse")

        flowIcon?.removeAction(forKey: "flowIconPulse")
        let iconPulse = SKAction.sequence([
            .group([
                .scale(to: 1.22, duration: 0.08),
                .rotate(byAngle: triggered ? 0.3 : 0.18, duration: 0.08)
            ]),
            .group([
                .scale(to: 1.0, duration: 0.12),
                .rotate(toAngle: 0, duration: 0.12, shortestUnitArc: true)
            ])
        ])
        flowIcon?.run(iconPulse, withKey: "flowIconPulse")
    }

    private func scheduleMilestoneLabel(_ milestone: ComboMilestone, delay: TimeInterval) {
        if delay <= 0 {
            showMilestoneLabel(milestone)
            return
        }
        let action = SKAction.sequence([
            .wait(forDuration: delay),
            .run { [weak self] in
                self?.showMilestoneLabel(milestone)
            }
        ])
        hudNode.run(action)
    }

    private func showMilestoneLabel(_ milestone: ComboMilestone) {
        let label = dequeueMilestoneLabel()
        label.text = milestone.text
        label.fontSize = 18
        label.fontColor = ArcadeStyle.Color.accentMagenta
        let safeTop = size.height / 2 - safeAreaInsets.top
        let y = safeTop - ArcadeStyle.Metric.hudHeight - 8
        label.position = snap(CGPoint(x: 0, y: y))
        label.zPosition = 120
        label.alpha = 0
        label.setScale(0.8)
        hudNode.addChild(label)

        let endPosition = snap(CGPoint(x: label.position.x, y: label.position.y + 14))
        label.run(.sequence([
            .group([
                .fadeIn(withDuration: 0.08),
                .scale(to: 1.1, duration: 0.08)
            ]),
            .group([
                .move(to: endPosition, duration: 0.22),
                .fadeOut(withDuration: 0.22)
            ]),
            .run { [weak self, weak label] in
                guard let self, let label else { return }
                self.recycleMilestoneLabel(label)
            }
        ]))
    }

    private func pulseCamera() {
        cameraNode.removeAction(forKey: "camPulse")
        let up = SKAction.scale(to: gameplayCameraScale * 0.98, duration: 0.06)
        let down = SKAction.scale(to: gameplayCameraScale, duration: 0.08)
        cameraNode.run(.sequence([up, down]), withKey: "camPulse")
    }

    private func playComboSound(_ sound: ComboSound) {
        switch sound {
        case .good:
            SoundFX.playHitFeedback(.good, on: self)
        case .perfect:
            SoundFX.playHitFeedback(.perfect, on: self)
        }
    }

    private func playComboHaptic() {
        #if os(iOS)
        guard SettingsStore.shared.isVibrationEnabled else { return }
        comboHapticGenerator.impactOccurred()
        comboHapticGenerator.prepare()
        #endif
    }

    private func dequeueRatingLabel() -> SKLabelNode {
        let label = ratingLabelPool.popLast() ?? SKLabelNode(fontNamed: ArcadeFont.header)
        resetFeedbackLabel(label)
        return label
    }

    private func recycleRatingLabel(_ label: SKLabelNode) {
        resetFeedbackLabel(label)
        ratingLabelPool.append(label)
    }

    private func dequeueMilestoneLabel() -> SKLabelNode {
        let label = milestoneLabelPool.popLast() ?? SKLabelNode(fontNamed: ArcadeFont.header)
        resetFeedbackLabel(label)
        return label
    }

    private func recycleMilestoneLabel(_ label: SKLabelNode) {
        resetFeedbackLabel(label)
        milestoneLabelPool.append(label)
    }

    private func dequeueFlowLabel() -> SKLabelNode {
        let label = flowLabelPool.popLast() ?? SKLabelNode(fontNamed: ArcadeFont.header)
        resetFeedbackLabel(label)
        return label
    }

    private func recycleFlowLabel(_ label: SKLabelNode) {
        resetFeedbackLabel(label)
        flowLabelPool.append(label)
    }

    private func resetFeedbackLabel(_ label: SKLabelNode) {
        label.removeAllActions()
        label.removeFromParent()
        label.alpha = 1
        label.setScale(1)
        label.zRotation = 0
        label.text = nil
        label.position = .zero
        label.zPosition = 0
        label.fontColor = ArcadeStyle.Color.textPrimary
    }

    private func dequeueFlowShard() -> SKSpriteNode {
        let shard = flowShardPool.popLast() ?? SKSpriteNode(color: ArcadeStyle.Color.accentMagenta, size: CGSize(width: 6, height: 2))
        shard.removeAllActions()
        shard.removeFromParent()
        shard.alpha = 1
        shard.color = ArcadeStyle.Color.accentMagenta
        shard.colorBlendFactor = 1
        shard.setScale(1)
        shard.zRotation = 0
        return shard
    }

    private func recycleFlowShard(_ shard: SKSpriteNode) {
        shard.removeAllActions()
        shard.removeFromParent()
        shard.alpha = 1
        shard.position = .zero
        shard.zPosition = 0
        shard.setScale(1)
        shard.zRotation = 0
        flowShardPool.append(shard)
    }

    private struct LandingResult {
        let point: GridPoint
        let forcedDirection: MoveDirection?
        let passedGate: Bool
    }

    private struct BotLandingResult {
        let point: GridPoint
        let forcedDirection: MoveDirection?
        let reachedExit: Bool
    }

    private func processLanding(at point: GridPoint) -> LandingResult {
        var currentPoint = point
        var passedGate = false

        if let destination = teleporterMap[currentPoint] {
            teleportPlayer(to: destination)
            currentPoint = destination
        }

        if let forced = oneWayDirections[currentPoint] {
            forcedDirection = forced
        }

        if gateTiles.contains(currentPoint), gateIsOpen {
            passedGate = true
        }

        activateSwitchIfNeeded(at: currentPoint)

        if let keyNode = keyNodes.removeValue(forKey: currentPoint) {
            keyCount += 1
            SoundFX.playUnlock(on: self)
            keyNode.removeFromParent()
            updateDoorVisuals()
            if botDifficulty == .hard {
                primeHardBotDirectionCache()
            }
        }

        if let orb = orbNodes.removeValue(forKey: currentPoint) {
            collectOrb(at: orb.position)
            orb.removeFromParent()
        }

        if currentPoint == currentMaze?.exit {
            playerGrid = currentPoint
            completeLevel()
            return LandingResult(point: currentPoint, forcedDirection: forcedDirection, passedGate: passedGate)
        }

        playerGrid = currentPoint
        return LandingResult(point: currentPoint, forcedDirection: forcedDirection, passedGate: passedGate)
    }

    private func processBotLanding(at point: GridPoint) -> BotLandingResult {
        var currentPoint = point

        if let destination = teleporterMap[currentPoint] {
            teleportBot(to: destination)
            currentPoint = destination
        }

        var forced: MoveDirection?
        if let oneWay = oneWayDirections[currentPoint] {
            forced = oneWay
        }

        activateSwitchIfNeeded(at: currentPoint)

        if let keyNode = keyNodes.removeValue(forKey: currentPoint) {
            keyCount += 1
            keyNode.removeFromParent()
            updateDoorVisuals()
            if botDifficulty == .hard {
                primeHardBotDirectionCache()
            }
        }

        botGrid = currentPoint
        if currentPoint == currentMaze?.exit {
            finishBotRace(winner: .bot)
            return BotLandingResult(point: currentPoint, forcedDirection: forced, reachedExit: true)
        }

        return BotLandingResult(point: currentPoint, forcedDirection: forced, reachedExit: false)
    }

    private func teleportPlayer(to point: GridPoint) {
        playerGrid = point
        let destination = positionFor(point)
        SoundFX.playTeleport(on: self)
        playerNode?.position = destination
        playerNode?.run(.sequence([
            .scale(to: 0.85, duration: 0.05),
            .scale(to: 1.0, duration: 0.05)
        ]))
        updateCameraPosition(animated: false, targetWorldPosition: destination)
    }

    private func teleportBot(to point: GridPoint) {
        botGrid = point
        let destination = botPositionFor(point)
        SoundFX.playTeleport(on: self)
        botNode?.position = destination
        botNode?.run(.sequence([
            .scale(to: 0.82, duration: 0.05),
            .scale(to: 1.0, duration: 0.05)
        ]))
    }

    private func collectOrb(at position: CGPoint) {
        score += 10
        if !isChallengeMode {
            CoinStore.shared.add(1)
            updateCoinHud()
        }
        let popSize = snapSize(CGSize(width: tileSize * 0.4, height: tileSize * 0.4))
        let pop = SKSpriteNode(texture: TextureFactory.shared.orbTexture(size: popSize))
        pop.position = position
        pop.alpha = 0.6
        pop.zPosition = 25
        worldNode.addChild(pop)
        pop.run(.sequence([
            .fadeOut(withDuration: 0.2),
            .removeFromParent()
        ]))
    }

    private func completeLevel() {
        guard currentGameState != .levelCompleted else { return }
        closeOverview()
        if currentGameState == .playing {
            updateTimer(now: CACurrentMediaTime())
        }
        playerNode?.removeAllActions()
        cameraNode.removeAllActions()
        stopSliding(reason: .completed)
        if isChallengeMode {
            challengeCompletedMazes += 1
            updateLeftHudState()
            advanceChallengeRun()
            return
        }
        if botRaceEnabled {
            finishBotRace(winner: .player)
            return
        }
        setGameState(.levelCompleted)
        applyGameplayCameraScale()
        activeButton = nil
        swipeStart = nil
        let finalTime = displayedElapsedTime()
        timerLabel.text = formattedClockTime(finalTime)

        let stars = starsForTime(finalTime)
        ProgressStore.shared.update(levelId: levelDefinition.id, time: finalTime, stars: stars)
        let flowBonus = flowSystem.pointsThisRun * 15
        if flowBonus > 0 {
            score += flowBonus
        }
        let rewardUnlock = CosmeticsStore.shared.unlockStoryRewardIfNeeded(forLevel: levelDefinition.id)
        let showResults = { [weak self] in
            guard let self else { return }
            if let rewardUnlock {
                self.showRewardUnlockOverlay(rewardUnlock) { [weak self] in
                    self?.showLevelResultOverlay(time: finalTime, stars: stars)
                }
            } else {
                self.showLevelResultOverlay(time: finalTime, stars: stars)
            }
        }
        let finishPosition = playerNode?.position ?? (currentMaze.map { positionFor($0.exit) } ?? .zero)
        SoundFX.playWin(on: self)
        playEquippedWinAnimation(at: finishPosition) {
            showResults()
        }

        if ThemeUnlocker.isNewUnlock(levelId: levelDefinition.id, starsEarned: stars) {
            let theme = ThemeUnlocker.theme(for: levelDefinition.id)
            ThemeProgress.shared.unlock(theme)
            showThemeUnlock(theme: theme)
        }
        let unlockedAchievements = AchievementStore.shared.evaluateLatestUnlocks()
        showAchievementUnlocks(unlockedAchievements)
    }

    private func finishBotRace(winner: RaceWinner) {
        guard currentGameState != .levelCompleted else { return }
        closeOverview()
        if currentGameState == .playing {
            updateTimer(now: CACurrentMediaTime())
        }
        let finalTime = displayedElapsedTime()
        botFinishTime = finalTime

        playerNode?.removeAllActions()
        botNode?.removeAllActions()
        cameraNode.removeAllActions()
        stopSliding(reason: .completed)
        botIsMoving = false
        botCurrentDirection = nil
        botForcedDirection = nil
        setGameState(.levelCompleted)
        applyGameplayCameraScale()
        activeButton = nil
        swipeStart = nil

        switch winner {
        case .player:
            if isDailyMode, let dailyDescriptor {
                let registration = DailyChallengeStore.shared.registerWin(for: dailyDescriptor, difficulty: botDifficulty, time: finalTime)
                let bestText = registration.bestTime.map { formattedClockTime($0) } ?? "--:--.--"
                let rewardText: String
                if registration.awardedCoins > 0 {
                    rewardText = "+\(registration.awardedCoins) COINS"
                    SoundFX.playReward(on: self)
                    showProgressToast(
                        title: "DAILY PAYOUT",
                        detail: "+\(registration.awardedCoins) COINS",
                        accentColor: ArcadeStyle.Color.accentYellow,
                        delay: 0.08
                    )
                } else {
                    rewardText = "REWARD CLAIMED"
                }
                showResultOverlay(
                    stars: nil,
                    headline: "DAILY CLEAR",
                    timeText: "Your Time: \(formattedClockTime(finalTime))",
                    detailLines: [
                        "Mode: Daily Challenge",
                        "Daily Best: \(bestText)",
                        registration.isNewBest ? rewardText + " • NEW BEST" : rewardText
                    ],
                    nextEnabled: false
                )
                return
            }
            let stars = starsForTime(finalTime)
            ProgressStore.shared.update(levelId: levelDefinition.id, time: finalTime, stars: stars)
            let flowBonus = flowSystem.pointsThisRun * 15
            if flowBonus > 0 {
                score += flowBonus
            }
            showLevelResultOverlay(time: finalTime, stars: stars, headline: "LEVEL COMPLETE")
        case .bot:
            if isDailyMode, let dailyDescriptor {
                let bestText = DailyChallengeStore.shared.bestTime(for: dailyDescriptor).map { formattedClockTime($0) } ?? "--:--.--"
                showResultOverlay(
                    stars: nil,
                    headline: "BOT WINS!",
                    timeText: "Your Time: \(formattedClockTime(finalTime))",
                    detailLines: [
                        "Mode: Daily Challenge",
                        "Daily Best: \(bestText)",
                        "\(botDifficulty.title.uppercased()) BOT"
                    ],
                    nextEnabled: false
                )
                return
            }
            showResultOverlay(
                stars: 0,
                headline: "BOT WINS!",
                timeText: "Your Time: \(formattedClockTime(finalTime))",
                detailLines: [
                    "Mode: Bot Race",
                    "Status: Try Again",
                    "\(botDifficulty.title.uppercased()) BOT"
                ],
                nextEnabled: false
            )
        }
    }

    private func showProgressToast(title: String, detail: String, accentColor: SKColor, delay: TimeInterval = 0) {
        let safeTop = size.height / 2 - safeAreaInsets.top

        let titleShadow = SKLabelNode(fontNamed: ArcadeFont.header)
        titleShadow.text = title
        titleShadow.fontSize = 18
        titleShadow.fontColor = SKColor(white: 0.0, alpha: 0.72)
        titleShadow.position = snap(CGPoint(x: 1, y: safeTop - 57))
        titleShadow.zPosition = 10001
        titleShadow.alpha = 0
        hudNode.addChild(titleShadow)

        let titleLabel = SKLabelNode(fontNamed: ArcadeFont.header)
        titleLabel.text = title
        titleLabel.fontSize = 18
        titleLabel.fontColor = accentColor
        titleLabel.position = snap(CGPoint(x: 0, y: safeTop - 56))
        titleLabel.zPosition = 10002
        titleLabel.alpha = 0
        hudNode.addChild(titleLabel)

        let detailLabel = SKLabelNode(fontNamed: ArcadeFont.body)
        detailLabel.text = detail
        detailLabel.fontSize = 12
        detailLabel.fontColor = ArcadeStyle.Color.textSecondary
        detailLabel.position = snap(CGPoint(x: 0, y: safeTop - 74))
        detailLabel.zPosition = 10002
        detailLabel.alpha = 0
        hudNode.addChild(detailLabel)

        let appear = SKAction.sequence([
            .wait(forDuration: delay),
            .group([
                .fadeIn(withDuration: 0.14),
                .scale(to: 1.03, duration: 0.14)
            ]),
            .wait(forDuration: 1.18),
            .fadeOut(withDuration: 0.22),
            .removeFromParent()
        ])
        titleShadow.setScale(0.96)
        titleLabel.setScale(0.96)
        detailLabel.setScale(0.98)
        titleShadow.run(appear)
        titleLabel.run(appear)
        detailLabel.run(.sequence([
            .wait(forDuration: delay + 0.03),
            .fadeIn(withDuration: 0.16),
            .wait(forDuration: 1.08),
            .fadeOut(withDuration: 0.22),
            .removeFromParent()
        ]))
    }

    private func showAchievementUnlocks(_ achievements: [AchievementDefinition]) {
        guard !achievements.isEmpty else { return }
        for (index, achievement) in achievements.enumerated() {
            let delay = 0.22 + Double(index) * 1.45
            showProgressToast(
                title: "ACHIEVEMENT UNLOCKED",
                detail: achievement.title,
                accentColor: ArcadeStyle.Color.accentYellow,
                delay: delay
            )
        }
    }

    private func showThemeUnlock(theme: MazeTheme) {
        SoundFX.playReward(on: self)
        showProgressToast(
            title: "NEW THEME UNLOCKED",
            detail: "THEME \(theme.rawValue + 1)",
            accentColor: ArcadeStyle.Color.accentMagenta
        )
    }

    private func showRewardUnlockOverlay(_ unlock: StoryRewardUnlock, onContinue: @escaping () -> Void) {
        rewardUnlockOverlay?.removeFromParent()
        SoundFX.playReward(on: self)
        let safeTop = size.height / 2 - safeAreaInsets.top
        let safeBottom = -size.height / 2 + safeAreaInsets.bottom
        let overlay = RewardUnlockOverlayNode(
            size: size,
            safeTop: safeTop,
            safeBottom: safeBottom,
            reward: unlock.reward
        )
        overlay.position = snap(.zero)
        overlay.zPosition = 9800
        overlay.onContinue = { [weak self, weak overlay] in
            overlay?.removeFromParent()
            self?.rewardUnlockOverlay = nil
            onContinue()
        }
        rewardUnlockOverlay = overlay
        hudNode.addChild(overlay)
    }

    private func playEquippedWinAnimation(at position: CGPoint, completion: @escaping () -> Void) {
        let style = CosmeticsStore.shared.selectedWinAnimation
        let container = SKNode()
        container.position = position
        container.zPosition = 42
        worldNode.addChild(container)
        playerNode?.alpha = 0

        var totalDuration: TimeInterval = 0.48
        switch style {
        case .neonExplosion:
            totalDuration = 0.42
            for index in 0..<8 {
                let shard = SKSpriteNode(texture: TextureFactory.shared.trailParticleTexture(size: CGSize(width: tileSize * 0.18, height: tileSize * 0.18), style: .classicNeon))
                shard.position = .zero
                shard.alpha = 0.92
                shard.blendMode = .add
                container.addChild(shard)
                let angle = CGFloat(index) / 8 * .pi * 2
                shard.run(.sequence([
                    .group([
                        .moveBy(x: cos(angle) * tileSize * 0.72, y: sin(angle) * tileSize * 0.72, duration: totalDuration),
                        .fadeOut(withDuration: totalDuration)
                    ]),
                    .removeFromParent()
                ]))
            }
        case .energyImplosion:
            let ring = SKShapeNode(circleOfRadius: tileSize * 0.2)
            ring.strokeColor = CosmeticsStore.shared.selectedPlayerSkin.highlightColor
            ring.lineWidth = 3
            ring.glowWidth = tileSize * 0.18
            ring.fillColor = .clear
            container.addChild(ring)
            ring.run(.sequence([
                .group([.scale(to: 0.4, duration: 0.16), .fadeAlpha(to: 1.0, duration: 0.16)]),
                .group([.scale(to: 1.45, duration: 0.28), .fadeOut(withDuration: 0.28)]),
                .removeFromParent()
            ]))
        case .pixelShatter:
            totalDuration = 0.44
            for row in -1...1 {
                for col in -1...1 {
                    let pixel = SKSpriteNode(texture: TextureFactory.shared.trailParticleTexture(size: CGSize(width: tileSize * 0.14, height: tileSize * 0.14), style: .pixelTrail))
                    pixel.position = CGPoint(x: CGFloat(col) * tileSize * 0.08, y: CGFloat(row) * tileSize * 0.08)
                    container.addChild(pixel)
                    pixel.run(.sequence([
                        .group([
                            .moveBy(x: CGFloat(col) * tileSize * 0.35, y: CGFloat(row) * tileSize * 0.35, duration: totalDuration),
                            .fadeOut(withDuration: totalDuration)
                        ]),
                        .removeFromParent()
                    ]))
                }
            }
        case .shockwaveRing:
            let ring = SKShapeNode(circleOfRadius: tileSize * 0.18)
            ring.strokeColor = ArcadeStyle.Color.accentCyan
            ring.lineWidth = 3
            ring.glowWidth = tileSize * 0.22
            ring.fillColor = .clear
            container.addChild(ring)
            ring.run(.sequence([
                .group([.scale(to: 2.4, duration: totalDuration), .fadeOut(withDuration: totalDuration)]),
                .removeFromParent()
            ]))
        case .lightBeamFinish:
            let beam = SKSpriteNode(color: ArcadeStyle.Color.accentYellow.withAlphaComponent(0.42), size: CGSize(width: tileSize * 0.5, height: tileSize * 2.3))
            beam.position = CGPoint(x: 0, y: tileSize * 0.2)
            beam.blendMode = .add
            container.addChild(beam)
            beam.run(.sequence([
                .group([.fadeAlpha(to: 0.86, duration: 0.18), .scaleY(to: 1.1, duration: 0.18)]),
                .group([.fadeOut(withDuration: 0.28), .scaleY(to: 0.8, duration: 0.28)]),
                .removeFromParent()
            ]))
        }

        container.run(.sequence([
            .wait(forDuration: totalDuration),
            .run { [weak self, weak container] in
                container?.removeFromParent()
                self?.playerNode?.alpha = 1
                completion()
            }
        ]))
    }

    private func showLevelResultOverlay(time: TimeInterval, stars: Int, headline: String = "LEVEL COMPLETE", nextEnabled: Bool? = nil) {
        showResultOverlay(
            stars: stars,
            headline: headline,
            timeText: "Your Time: \(formattedClockTime(time))",
            detailLines: [],
            requirementRows: starRequirementRows(highlighting: stars),
            nextEnabled: nextEnabled
        )
    }

    private func showResultOverlay(
        stars: Int?,
        headline: String,
        timeText: String,
        detailLines: [String],
        requirementRows: [ResultOverlayNode.RequirementRow] = [],
        nextEnabled: Bool? = nil
    ) {
        resultOverlay?.removeFromParent()
        challengeResultOverlay?.removeFromParent()
        challengeResultOverlay = nil
        rewardUnlockOverlay?.removeFromParent()
        rewardUnlockOverlay = nil
        let safeTop = size.height / 2 - safeAreaInsets.top
        let safeBottom = -size.height / 2 + safeAreaInsets.bottom
        let overlay = ResultOverlayNode(
            size: size,
            safeTop: safeTop,
            safeBottom: safeBottom,
            headline: headline,
            timeLine: timeText,
            stars: stars,
            detailLines: detailLines,
            requirementRows: requirementRows
        )
        overlay.position = snap(.zero)
        overlay.zPosition = 10000
        overlay.onRetry = { [weak self] in
            self?.retryLevel()
        }
        overlay.onLevelSelect = { [weak self] in
            self?.goToLevelSelect()
        }
        overlay.onNext = { [weak self] in
            self?.goToNextLevel()
        }
        let hasNextLevel = levelIndex < LevelStore.levels.count - 1
        overlay.setNextEnabled(nextEnabled ?? hasNextLevel)
        resultOverlay = overlay
        hudNode.addChild(overlay)

        if flowSystem.pointsThisRun > 0 {
            let label = SKLabelNode(fontNamed: ArcadeFont.body)
            label.text = "FLOW ORBS +\(flowSystem.pointsThisRun)"
            label.fontSize = 14
            label.fontColor = ArcadeStyle.Color.accentMagenta
            label.position = snap(CGPoint(x: 0, y: safeTop - 24))
            label.zPosition = 10001
            hudNode.addChild(label)
            label.run(.sequence([
                .wait(forDuration: 1.6),
                .fadeOut(withDuration: 0.3),
                .removeFromParent()
            ]))
        }
    }

    private func showChallengeResultOverlay(duration: TimeChallengeDuration, completedMazes: Int, bestMazes: Int, isNewRecord: Bool) {
        challengeResultOverlay?.removeFromParent()
        resultOverlay?.removeFromParent()
        resultOverlay = nil
        rewardUnlockOverlay?.removeFromParent()
        rewardUnlockOverlay = nil
        if isNewRecord {
            SoundFX.playReward(on: self)
        }
        let safeTop = size.height / 2 - safeAreaInsets.top
        let safeBottom = -size.height / 2 + safeAreaInsets.bottom
        let overlay = ChallengeResultOverlayNode(
            size: size,
            safeTop: safeTop,
            safeBottom: safeBottom,
            duration: duration,
            completedMazes: completedMazes,
            bestMazes: bestMazes,
            isNewRecord: isNewRecord
        )
        overlay.position = snap(.zero)
        overlay.zPosition = 10000
        overlay.onRetry = { [weak self] in
            self?.retryLevel()
        }
        overlay.onMenu = { [weak self] in
            self?.goToLevelSelect()
        }
        challengeResultOverlay = overlay
        hudNode.addChild(overlay)
    }

    private func advanceChallengeRun() {
        guard let challengeDuration else { return }
        let now = CACurrentMediaTime()
        updateTimer(now: now)
        updateTimerLabel()
        if displayedElapsedTime() >= challengeDuration.seconds {
            finishChallengeRun()
            return
        }

        challengeMazeNumber += 1
        levelConfig = makeChallengeLevelConfig(mazeNumber: challengeMazeNumber)
        prepareForNextChallengeMaze()
        loadMaze()
    }

    private func prepareForNextChallengeMaze() {
        activeButton?.setPressed(false)
        activeButton = nil
        swipeStart = nil
        isMiniMapTouch = false
        isMoving = false
        currentDirection = nil
        forcedDirection = nil
        queuedDirection = nil
        queuedTimestamp = nil
        score = 0

        comboSystem.reset()
        flowSystem.resetRun()
        updateComboBadge(combo: 0, rating: nil, animate: false)

        playerNode?.removeAllActions()
        playerNode = nil
        worldNode.removeAllChildren()
        tileMapNode = nil
        currentMaze = nil
        currentStarBenchmarks = nil
        orbNodes.removeAll()
        keyNodes.removeAll()
        switchNodes.removeAll()
        doorNodes.removeAll()
        gateNodes.removeAll()
        gateTiles.removeAll()
        teleporterNodes.removeAll()
        teleporterMap.removeAll()
        oneWayDirections.removeAll()
        miniMapNode?.removeFromParent()
        miniMapNode = nil
        miniMapTexture = nil
        fogNode?.removeFromParent()
        fogNode = nil
        fogTileMapNode = nil
        playerLightNode = nil
        exploredTiles.removeAll()
        keyCount = 0
        switchActivated = false
        gateIsOpen = true
        setupHUD()
    }

    private func finishChallengeRun() {
        guard let duration = challengeDuration, currentGameState != .levelCompleted else { return }
        mazeLoadGeneration += 1
        loadingIndicatorWorkItem?.cancel()
        loadingIndicatorWorkItem = nil
        prefetchedChallengeMaze = nil
        prefetchedChallengeMazeNumber = nil
        challengePrefetchToken += 1
        closeOverview()
        playerNode?.removeAllActions()
        cameraNode.removeAllActions()
        stopSliding(reason: .completed)
        hidePauseOverlay()
        activeButton?.setPressed(false)
        activeButton = nil
        swipeStart = nil
        setGameState(.levelCompleted)
        applyGameplayCameraScale()
        updateTimerLabel()

        let previousBest = ChallengeStore.shared.best(for: duration)
        let isNewRecord = ChallengeStore.shared.register(duration: duration, completedMazes: challengeCompletedMazes)
        let best = max(previousBest, challengeCompletedMazes)
        showChallengeResultOverlay(duration: duration, completedMazes: challengeCompletedMazes, bestMazes: best, isNewRecord: isNewRecord)
    }

    private func retryLevel() {
        cameraNode.removeAllActions()
        applyGameplayCameraScale()
        resultOverlay?.removeFromParent()
        resultOverlay = nil
        challengeResultOverlay?.removeFromParent()
        challengeResultOverlay = nil
        rewardUnlockOverlay?.removeFromParent()
        rewardUnlockOverlay = nil
        hideTutorialOverlay()
        resetGameAndReloadLevel()
    }

    private func goToNextLevel() {
        guard !isChallengeMode else {
            retryLevel()
            return
        }
        cameraNode.removeAllActions()
        applyGameplayCameraScale()
        resultOverlay?.removeFromParent()
        resultOverlay = nil
        if levelIndex < LevelStore.levels.count - 1 {
            resetGameAndReloadLevel(targetLevelIndex: levelIndex + 1)
        } else {
            goToLevelSelect()
        }
    }

    private func goToLevelSelect() {
        transitionToLevelSelect()
    }

    private func starsForTime(_ time: TimeInterval) -> Int {
        guard let benchmarks = levelBenchmarkData() else { return 0 }
        return benchmarks.stars(for: time)
    }

    private func levelBenchmarkData() -> LevelBenchmarkData? {
        if let currentStarBenchmarks {
            return currentStarBenchmarks
        }
        guard !isChallengeMode, let maze = currentMaze else { return nil }
        let benchmarks = MazeBenchmarkStore.shared.benchmarks(levelId: levelDefinition.id, maze: maze)
        currentStarBenchmarks = benchmarks
        return benchmarks
    }

    private func starRequirementRows(highlighting earnedStars: Int) -> [ResultOverlayNode.RequirementRow] {
        guard let benchmarks = levelBenchmarkData() else { return [] }
        return [
            ResultOverlayNode.RequirementRow(
                starCount: 1,
                timeText: formattedRequirementTime(benchmarks.oneStarTime),
                highlighted: earnedStars == 1
            ),
            ResultOverlayNode.RequirementRow(
                starCount: 2,
                timeText: formattedRequirementTime(benchmarks.twoStarTime),
                highlighted: earnedStars == 2
            ),
            ResultOverlayNode.RequirementRow(
                starCount: 3,
                timeText: formattedRequirementTime(benchmarks.threeStarTime),
                highlighted: earnedStars == 3
            )
        ]
    }

    private func formattedRequirementTime(_ time: TimeInterval) -> String {
        String(format: "%.2fs", max(0, time))
    }

    private func togglePause() {
        guard tutorialOverlay == nil else { return }
        if currentGameState == .paused {
            resumeGame()
        } else if currentGameState == .playing {
            pauseGame()
        }
    }

    private func handlePausePressed() {
        guard tutorialOverlay == nil else { return }
        guard currentGameState == .playing || currentGameState == .idle else { return }
        pauseGame()
    }

    private func pendingTutorialMechanic() -> Mechanic? {
        guard !isChallengeMode, !isDailyMode else { return nil }
        guard let mechanic = introMechanic(for: levelDefinition.id) else { return nil }
        guard !MechanicTutorialStore.shared.hasShown(mechanic) else { return nil }
        return mechanic
    }

    private func showTutorialOverlay(for mechanic: Mechanic) {
        tutorialOverlay?.removeFromParent()
        let safeTop = size.height / 2 - safeAreaInsets.top
        let safeBottom = -size.height / 2 + safeAreaInsets.bottom
        let overlay = MechanicTutorialOverlayNode(size: size, safeTop: safeTop, safeBottom: safeBottom, mechanic: mechanic)
        overlay.position = snap(.zero)
        overlay.zPosition = 9500
        overlay.onContinue = { [weak self, weak overlay] in
            guard let self, let overlay else { return }
            SoundFX.playButtonTap(on: self.hudNode)
            MechanicTutorialStore.shared.markShown(overlay.mechanic)
            self.hideTutorialOverlay()
        }
        tutorialOverlay = overlay
        hudNode.addChild(overlay)
    }

    private func hideTutorialOverlay() {
        tutorialOverlay?.removeFromParent()
        tutorialOverlay = nil
    }

    private func pauseGame() {
        guard currentGameState == .playing || currentGameState == .idle else { return }
        let now = CACurrentMediaTime()
        if currentGameState == .playing, runStartTime != nil {
            updateTimer(now: now)
            pauseStartTime = now
        } else {
            pauseStartTime = nil
        }
        setGameState(.paused)
        queuedDirection = nil
        queuedTimestamp = nil
        forcedDirection = nil
        activeButton = nil
        swipeStart = nil
        playerNode?.removeAction(forKey: "slideStep")
        botNode?.removeAction(forKey: "botStep")
        botNode?.removeAction(forKey: "botWait")
        isMoving = false
        botIsMoving = false
        currentDirection = nil
        showPauseOverlay()
    }

    private func resumeGame() {
        guard currentGameState == .paused else { return }
        let now = CACurrentMediaTime()
        if let pausedAt = pauseStartTime {
            accumulatedPausedTime += now - pausedAt
        }
        pauseStartTime = nil
        setGameState(.playing)
        lastTimerUpdate = now
        hidePauseOverlay()
        if botRaceEnabled, botHasStarted, botFinishTime == nil {
            botIsMoving = true
            stepBotForward()
        }
    }

    private func showPauseOverlay() {
        pauseOverlay?.removeFromParent()
        let safeTop = size.height / 2 - safeAreaInsets.top
        let safeBottom = -size.height / 2 + safeAreaInsets.bottom
        let overlay = PauseOverlayNode(size: size, safeTop: safeTop, safeBottom: safeBottom)
        overlay.position = snap(.zero)
        overlay.zPosition = 9000
        overlay.setScale(1.0)
        overlay.onResume = { [weak self] in self?.resumeGame() }
        overlay.onRestart = { [weak self] in self?.restartLevel() }
        overlay.onLevelSelect = { [weak self] in self?.goToLevelSelectFromPause() }
        pauseOverlay = overlay
        hudNode.addChild(overlay)
    }

    private func hidePauseOverlay() {
        pauseOverlay?.removeFromParent()
        pauseOverlay = nil
    }

    private func goToLevelSelectFromPause() {
        transitionToLevelSelect()
    }

    private func restartLevel() {
        resetGameAndReloadLevel()
    }

    private func presentLevelSelect() {
        guard let view = view else { return }
        let scene: SKScene
        if isChallengeMode {
            scene = ChallengeSelectScene(size: size)
        } else if isDailyMode {
            scene = DailyChallengeScene(size: size)
        } else {
            scene = LevelSelectScene(size: size)
        }
        scene.scaleMode = .resizeFill
        view.presentScene(scene, transition: SKTransition.fade(withDuration: 0.3))
    }

    private func transitionToLevelSelect() {
        guard !isTransitioning else { return }
        isTransitioning = true
        hideTutorialOverlay()
        hidePauseOverlay()
        rewardUnlockOverlay?.removeFromParent()
        rewardUnlockOverlay = nil
        resultOverlay?.removeFromParent()
        resultOverlay = nil
        closeOverview()
        cleanupBeforeSceneTransition()
        presentLevelSelect()
    }

    private func cleanupBeforeSceneTransition() {
        mazeLoadGeneration += 1
        loadingIndicatorWorkItem?.cancel()
        loadingIndicatorWorkItem = nil
        hardBotCacheWorkItem?.cancel()
        hardBotCacheWorkItem = nil
        prefetchedChallengeMaze = nil
        prefetchedChallengeMazeNumber = nil
        challengePrefetchToken += 1
        autoPausedForLifecycle = false
        removeAllActions()
        cameraNode.removeAllActions()
        worldNode.removeAllActions()
        hudNode.removeAllActions()
        playerNode?.removeAllActions()
        playerNode = nil
        botNode?.removeAllActions()
        botNode = nil
        tileMapNode = nil
        currentMaze = nil
        currentStarBenchmarks = nil
        isMoving = false
        botIsMoving = false
        botHasStarted = false
        botCurrentDirection = nil
        botForcedDirection = nil
        botFinishTime = nil
        easyBotLoopTracker = MazeSolvability.EasyBotLoopTracker()
        queuedDirection = nil
        queuedTimestamp = nil
        currentDirection = nil
        forcedDirection = nil
        isInOverviewMode = false
        overviewOverlay?.removeFromParent()
        overviewOverlay = nil
        challengeResultOverlay?.removeFromParent()
        challengeResultOverlay = nil
        tutorialOverlay?.removeFromParent()
        tutorialOverlay = nil
        rewardUnlockOverlay?.removeFromParent()
        rewardUnlockOverlay = nil
        overviewMapNode = nil
        overviewCloseButton = nil
        miniMapNode?.removeFromParent()
        miniMapNode = nil
        swipeHintLabel?.removeFromParent()
        swipeHintLabel = nil
        worldNode.removeAllChildren()
        hudNode.removeAllChildren()
    }

    private func presentNextLevel() {
        guard let view = view else { return }
        let nextIndex = levelIndex + 1
        if nextIndex < LevelStore.levels.count {
            let scene = GameScene(size: size, levelIndex: nextIndex)
            scene.scaleMode = .resizeFill
            view.presentScene(scene, transition: SKTransition.fade(withDuration: 0.3))
        } else {
            presentLevelSelect()
        }
    }

    private func resetGameAndReloadLevel(targetLevelIndex: Int? = nil) {
        mazeLoadGeneration += 1
        loadingIndicatorWorkItem?.cancel()
        loadingIndicatorWorkItem = nil
        hardBotCacheWorkItem?.cancel()
        hardBotCacheWorkItem = nil
        prefetchedChallengeMaze = nil
        prefetchedChallengeMazeNumber = nil
        challengePrefetchToken += 1
        autoPausedForLifecycle = false
        if let targetIndex = targetLevelIndex, targetIndex != levelIndex, !isChallengeMode {
            resultOverlay?.removeFromParent()
            resultOverlay = nil
            pauseOverlay?.removeFromParent()
            pauseOverlay = nil
            tutorialOverlay?.removeFromParent()
            tutorialOverlay = nil
            rewardUnlockOverlay?.removeFromParent()
            rewardUnlockOverlay = nil
            overviewOverlay?.removeFromParent()
            overviewOverlay = nil
            overviewMapNode = nil
            overviewCloseButton = nil
            isInOverviewMode = false
            guard let view = view else { return }
            let scene = GameScene(size: size, levelIndex: targetIndex)
            scene.scaleMode = .resizeFill
            view.presentScene(scene, transition: SKTransition.fade(withDuration: 0.3))
            return
        }

        removeAllActions()
        cameraNode.removeAllActions()
        hudNode.removeAllActions()
        hudNode.removeAllChildren()
        comboBadge.removeAllActions()
        comboBadge.removeAllChildren()
        flowCard = nil
        flowFill = nil
        playerNode?.removeAllActions()
        playerNode = nil
        botNode?.removeAllActions()
        botNode = nil
        worldNode.removeAllActions()
        worldNode.isPaused = false
        worldNode.removeAllChildren()
        tileMapNode = nil

        isMoving = false
        botIsMoving = false
        botHasStarted = false
        botCurrentDirection = nil
        botForcedDirection = nil
        botFinishTime = nil
        currentDirection = nil
        forcedDirection = nil
        queuedDirection = nil
        queuedTimestamp = nil
        comboSystem.reset()
        flowSystem.resetRun()
        score = 0
        addedOverviewPenalty = 0
        runStartTime = nil
        isInOverviewMode = false
        keyCount = 0
        switchActivated = false
        gateIsOpen = true
        oneWayDirections.removeAll()
        teleporterMap.removeAll()
        gateTiles.removeAll()
        keyNodes.removeAll()
        switchNodes.removeAll()
        doorNodes.removeAll()
        gateNodes.removeAll()
        teleporterNodes.removeAll()

        elapsedTime = 0
        lastTimerUpdate = nil
        accumulatedPausedTime = 0
        pauseStartTime = nil
        activeButton = nil
        swipeStart = nil
        isMiniMapTouch = false

        pauseOverlay?.removeFromParent()
        pauseOverlay = nil
        resultOverlay?.removeFromParent()
        resultOverlay = nil
        challengeResultOverlay?.removeFromParent()
        challengeResultOverlay = nil
        tutorialOverlay?.removeFromParent()
        tutorialOverlay = nil
        rewardUnlockOverlay?.removeFromParent()
        rewardUnlockOverlay = nil
        overviewOverlay?.removeFromParent()
        overviewOverlay = nil
        overviewMapNode = nil
        overviewCloseButton = nil
        miniMapNode?.removeFromParent()
        miniMapNode = nil
        miniMapTexture = nil
        swipeHintLabel?.removeFromParent()
        swipeHintLabel = nil
        fogNode?.removeFromParent()
        fogNode = nil
        fogTileMapNode = nil
        playerLightNode = nil
        exploredTiles.removeAll()
        comboCard?.removeAllActions()
        comboCard?.alpha = 0

        if isChallengeMode {
            challengeMazeNumber = 1
            challengeCompletedMazes = 0
            challengeRunSeedSalt = Int.random(in: 1...Int.max / 4)
            levelConfig = makeChallengeLevelConfig(mazeNumber: challengeMazeNumber)
        }

        setGameState(.idle)
        currentMaze = nil
        loadMaze()
    }

    override func update(_ currentTime: TimeInterval) {
        guard currentGameState == .playing else {
            lastTimerUpdate = nil
            return
        }
        let now = CACurrentMediaTime()
        updateTimer(now: now)
        updateTimerLabel()
        if let challengeDuration, displayedElapsedTime() >= challengeDuration.seconds {
            finishChallengeRun()
            return
        }
        if needsExplorationRefresh, now - lastExplorationRefreshTime >= Tuning.explorationRefreshInterval {
            refreshExplorationPresentation()
            needsExplorationRefresh = false
            lastExplorationRefreshTime = now
        }
        updateGateState(now: now)
        if let flowEvent = flowSystem.tick(now: now) {
            if flowEvent.delta != 0 {
                updateFlowBar()
            }
        }
        if let event = comboSystem.tick(now: now) {
            handleComboEvent(event, rating: nil, at: playerNode?.position ?? positionFor(playerGrid))
        }
    }

    override func didFinishUpdate() {
        super.didFinishUpdate()
        flushPendingMiniMapSetupIfNeeded(now: CACurrentMediaTime())
        guard let player = playerNode else { return }
        updateFogMask()
        let threshold = Tuning.miniMapPositionUpdateThreshold
        let shouldRefreshMiniMapPosition: Bool
        if let last = lastMiniMapPlayerWorldPosition {
            let dx = player.position.x - last.x
            let dy = player.position.y - last.y
            shouldRefreshMiniMapPosition = (dx * dx + dy * dy) >= (threshold * threshold)
        } else {
            shouldRefreshMiniMapPosition = true
        }

        if shouldRefreshMiniMapPosition {
            lastMiniMapPlayerWorldPosition = player.position
            miniMapNode?.updatePlayerPosition(worldPosition: player.position, gridOrigin: gridOrigin, tileSize: tileSize)
            overviewMapNode?.updatePlayerPosition(worldPosition: player.position, gridOrigin: gridOrigin, tileSize: tileSize)
        }
    }

    private func handleTap(at point: CGPoint) {
        guard !isInOverviewMode else { return }
        if let overlay = tutorialOverlay {
            if let button = overlay.button(at: point, in: self) {
                overlay.handleTap(button: button)
            } else {
                overlay.onContinue?()
            }
            return
        }
        if let overlay = rewardUnlockOverlay {
            if let button = overlay.button(at: point, in: self) {
                overlay.handleTap(button: button)
            } else {
                overlay.onContinue?()
            }
            return
        }
        switch currentGameState {
        case .paused:
            if let overlay = pauseOverlay, let button = overlay.button(at: point, in: self) {
                overlay.handleTap(button: button)
            }
        case .levelCompleted:
            if let button = overlayButton(at: point) {
                if let overlay = challengeResultOverlay, button.inParentHierarchy(overlay) {
                    overlay.handleTap(button: button)
                } else if let overlay = resultOverlay {
                    overlay.handleTap(button: button)
                }
            }
        case .playing:
            if let button = arcadeButton(at: point), button === pauseButton {
                button.onTap?()
            }
        case .idle:
            if let button = arcadeButton(at: point), button === pauseButton {
                button.onTap?()
            }
        }
    }

    private func buttonForTouch(at point: CGPoint) -> ArcadeButtonNode? {
        if let overlay = tutorialOverlay, let button = overlay.button(at: point, in: self) {
            return button
        }
        if let overlay = rewardUnlockOverlay, let button = overlay.button(at: point, in: self) {
            return button
        }
        switch currentGameState {
        case .paused:
            if let overlay = pauseOverlay, let button = overlay.button(at: point, in: self) {
                return button
            }
        case .levelCompleted:
            return overlayButton(at: point)
        case .playing:
            if let button = arcadeButton(at: point), button === pauseButton {
                return button
            }
        case .idle:
            if let button = arcadeButton(at: point), button === pauseButton {
                return button
            }
        }
        return nil
    }

    private func overlayButton(at point: CGPoint) -> ArcadeButtonNode? {
        let targets: Set<String> = ["btn_next", "btn_retry", "btn_levelselect"]
        if let overlay = challengeResultOverlay {
            if let button = overlay.button(at: point, in: self),
               button.isEnabled,
               let name = button.name,
               targets.contains(name) {
                return button
            }
            let cameraPoint = cameraNode.convert(point, from: self)
            if let button = overlay.button(at: cameraPoint, in: cameraNode),
               button.isEnabled,
               let name = button.name,
               targets.contains(name) {
                return button
            }
        }
        if let overlay = resultOverlay {
            if let button = overlay.button(at: point, in: self),
               button.isEnabled,
               let name = button.name,
               targets.contains(name) {
                return button
            }
            let cameraPoint = cameraNode.convert(point, from: self)
            if let button = overlay.button(at: cameraPoint, in: cameraNode),
               button.isEnabled,
               let name = button.name,
               targets.contains(name) {
                return button
            }
        }
        return nil
    }

    private func handlePauseOverlayTap(at point: CGPoint) -> Bool {
        guard pauseOverlay != nil else { return false }
        let targets: [String: () -> Void] = [
            "btn_pause_resume": { [weak self] in self?.pauseOverlay?.handleTap(named: "btn_pause_resume") },
            "btn_pause_restart": { [weak self] in self?.pauseOverlay?.handleTap(named: "btn_pause_restart") },
            "btn_pause_menu": { [weak self] in self?.pauseOverlay?.handleTap(named: "btn_pause_menu") }
        ]

        for node in nodes(at: point) {
            if let name = node.name ?? node.parent?.name,
               let action = targets[name] {
                action()
                return true
            }
        }

        let cameraPoint = cameraNode.convert(point, from: self)
        for node in cameraNode.nodes(at: cameraPoint) {
            if let name = node.name ?? node.parent?.name,
               let action = targets[name] {
                action()
                return true
            }
        }

        if let overlay = pauseOverlay,
           let button = overlay.button(at: point, in: self) {
            overlay.handleTap(button: button)
            return true
        }
        return false
    }

    private func localPoint(for button: ArcadeButtonNode, scenePoint: CGPoint) -> CGPoint {
        if button.inParentHierarchy(cameraNode) {
            let cameraPoint = cameraNode.convert(scenePoint, from: self)
            return button.convert(cameraPoint, from: cameraNode)
        }
        return button.convert(scenePoint, from: self)
    }

    private func swipeDirection(from start: CGPoint, to end: CGPoint) -> MoveDirection? {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let threshold: CGFloat = 20
        if abs(dx) < threshold && abs(dy) < threshold { return nil }
        if abs(dx) > abs(dy) {
            return dx > 0 ? .right : .left
        } else {
            return dy > 0 ? .up : .down
        }
    }

    #if os(iOS) || os(tvOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }
        if tutorialOverlay != nil {
            if let button = buttonForTouch(at: location) {
                activeButton = button
                button.setPressed(true)
            } else {
                activeButton = nil
            }
            swipeStart = nil
            isMiniMapTouch = false
            return
        }
        if rewardUnlockOverlay != nil {
            if let button = buttonForTouch(at: location) {
                activeButton = button
                button.setPressed(true)
            } else {
                activeButton = nil
            }
            swipeStart = nil
            isMiniMapTouch = false
            return
        }
        if overviewOverlay != nil {
            if let button = overviewCloseButton, button.hitTest(location, in: self) {
                activeButton = button
                button.setPressed(true)
            }
            swipeStart = nil
            isMiniMapTouch = false
            return
        }
        if resultOverlay != nil || challengeResultOverlay != nil {
            activeButton?.setPressed(false)
            activeButton = nil
            swipeStart = nil
            return
        }
        if currentGameState == .levelCompleted {
            if let button = overlayButton(at: location) {
                activeButton = button
                button.setPressed(true)
            }
            swipeStart = nil
            return
        }
        if let button = buttonForTouch(at: location) {
            activeButton = button
            button.setPressed(true)
            swipeStart = nil
            return
        }
        if (currentGameState == .playing || currentGameState == .idle),
           let miniMap = miniMapNode,
           miniMap.hitTest(location, in: self) {
            isMiniMapTouch = true
            swipeStart = location
            return
        }
        if currentGameState == .playing || currentGameState == .idle {
            swipeStart = location
        } else {
            swipeStart = nil
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }
        if let overlay = tutorialOverlay {
            if let button = activeButton {
                let localPoint = localPoint(for: button, scenePoint: location)
                let shouldTap = button.contains(localPoint) && button.isEnabled
                button.setPressed(false)
                activeButton = nil
                swipeStart = nil
                if shouldTap {
                    overlay.handleTap(button: button)
                }
            } else {
                overlay.onContinue?()
                swipeStart = nil
            }
            return
        }
        if let overlay = rewardUnlockOverlay {
            if let button = activeButton {
                let localPoint = localPoint(for: button, scenePoint: location)
                let shouldTap = button.contains(localPoint) && button.isEnabled
                button.setPressed(false)
                activeButton = nil
                swipeStart = nil
                if shouldTap {
                    overlay.handleTap(button: button)
                }
            } else {
                overlay.onContinue?()
                swipeStart = nil
            }
            return
        }
        if overviewOverlay != nil {
            if let button = activeButton {
                let localPoint = localPoint(for: button, scenePoint: location)
                button.setPressed(false)
                activeButton = nil
                _ = button.contains(localPoint)
            }
            swipeStart = nil
            isMiniMapTouch = false
            closeOverview()
            return
        }
        if isMiniMapTouch {
            isMiniMapTouch = false
            let shouldOpen: Bool
            if let start = swipeStart {
                let dx = location.x - start.x
                let dy = location.y - start.y
                shouldOpen = hypot(dx, dy) < 12
            } else {
                shouldOpen = true
            }
            swipeStart = nil
            if shouldOpen, let miniMap = miniMapNode, miniMap.hitTest(location, in: self) {
                openOverview()
            }
            return
        }
        if resultOverlay != nil || challengeResultOverlay != nil {
            activeButton?.setPressed(false)
            activeButton = nil
            swipeStart = nil

            for node in nodes(at: location) {
                let name = node.name ?? node.parent?.name
                switch name {
                case "btn_retry":
                    retryLevel()
                    return
                case "btn_levelselect":
                    goToLevelSelect()
                    return
                case "btn_next":
                    goToNextLevel()
                    return
                default:
                    break
                }
            }
            let cameraPoint = cameraNode.convert(location, from: self)
            for node in cameraNode.nodes(at: cameraPoint) {
                let name = node.name ?? node.parent?.name
                switch name {
                case "btn_retry":
                    retryLevel()
                    return
                case "btn_levelselect":
                    goToLevelSelect()
                    return
                case "btn_next":
                    goToNextLevel()
                    return
                default:
                    break
                }
            }
            return
        }
        if pauseOverlay != nil, activeButton == nil {
            if handlePauseOverlayTap(at: location) {
                swipeStart = nil
                return
            }
        }
        if let button = activeButton {
            let shouldTap: Bool
            if button === pauseButton {
                shouldTap = button.isEnabled
            } else if let overlay = pauseOverlay, button.inParentHierarchy(overlay) {
                shouldTap = button.isEnabled
            } else {
                let localPoint = localPoint(for: button, scenePoint: location)
                shouldTap = button.contains(localPoint) && button.isEnabled
            }
            button.setPressed(false)
            activeButton = nil
            swipeStart = nil
            if shouldTap {
                if let overlay = pauseOverlay {
                    overlay.handleTap(button: button)
                } else if let overlay = challengeResultOverlay, button.inParentHierarchy(overlay) {
                    overlay.handleTap(button: button)
                } else if let overlay = resultOverlay {
                    overlay.handleTap(button: button)
                } else if button === pauseButton {
                    button.onTap?()
                }
            }
            return
        }

        if currentGameState == .playing || currentGameState == .idle {
            if let start = swipeStart, let direction = swipeDirection(from: start, to: location) {
                handleSwipe(direction)
            } else {
                handleTap(at: location)
            }
        } else {
            handleTap(at: location)
        }
        swipeStart = nil
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if tutorialOverlay != nil {
            if let button = activeButton, let location = touches.first?.location(in: self) {
                let localPoint = localPoint(for: button, scenePoint: location)
                button.setPressed(button.contains(localPoint))
            }
            return
        }
        if rewardUnlockOverlay != nil {
            if let button = activeButton, let location = touches.first?.location(in: self) {
                let localPoint = localPoint(for: button, scenePoint: location)
                button.setPressed(button.contains(localPoint))
            }
            return
        }
        if overviewOverlay != nil {
            if let button = activeButton, let location = touches.first?.location(in: self) {
                let localPoint = localPoint(for: button, scenePoint: location)
                button.setPressed(button.contains(localPoint))
            }
            return
        }
        if isMiniMapTouch, let start = swipeStart, let location = touches.first?.location(in: self) {
            let dx = location.x - start.x
            let dy = location.y - start.y
            if hypot(dx, dy) > 12 {
                isMiniMapTouch = false
                swipeStart = nil
            }
            return
        }
        if resultOverlay != nil {
            return
        }
        guard let button = activeButton, let location = touches.first?.location(in: self) else { return }
        let localPoint = localPoint(for: button, scenePoint: location)
        button.setPressed(button.contains(localPoint))
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeButton?.setPressed(false)
        activeButton = nil
        swipeStart = nil
        isMiniMapTouch = false
    }
    #endif

    #if os(OSX)
    override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        if tutorialOverlay != nil {
            if let button = buttonForTouch(at: location) {
                activeButton = button
                button.setPressed(true)
            } else {
                activeButton = nil
            }
            swipeStart = nil
            isMiniMapTouch = false
            return
        }
        if rewardUnlockOverlay != nil {
            if let button = buttonForTouch(at: location) {
                activeButton = button
                button.setPressed(true)
            } else {
                activeButton = nil
            }
            swipeStart = nil
            isMiniMapTouch = false
            return
        }
        if overviewOverlay != nil {
            if let button = overviewCloseButton, button.hitTest(location, in: self) {
                activeButton = button
                button.setPressed(true)
            }
            swipeStart = nil
            isMiniMapTouch = false
            return
        }
        if (currentGameState == .playing || currentGameState == .idle),
           let miniMap = miniMapNode,
           miniMap.hitTest(location, in: self) {
            isMiniMapTouch = true
            swipeStart = location
            return
        }
        if currentGameState == .levelCompleted {
            if let button = overlayButton(at: location) {
                activeButton = button
                button.setPressed(true)
            }
            swipeStart = nil
            return
        }
        if let button = buttonForTouch(at: location) {
            activeButton = button
            button.setPressed(true)
            swipeStart = nil
            return
        }
        if currentGameState == .playing || currentGameState == .idle {
            swipeStart = location
        } else {
            swipeStart = nil
        }
    }

    override func mouseUp(with event: NSEvent) {
        let location = event.location(in: self)
        if let overlay = tutorialOverlay {
            if let button = activeButton {
                let localPoint = localPoint(for: button, scenePoint: location)
                let shouldTap = button.contains(localPoint) && button.isEnabled
                button.setPressed(false)
                activeButton = nil
                swipeStart = nil
                if shouldTap {
                    overlay.handleTap(button: button)
                }
            } else {
                overlay.onContinue?()
                swipeStart = nil
            }
            return
        }
        if let overlay = rewardUnlockOverlay {
            if let button = activeButton {
                let localPoint = localPoint(for: button, scenePoint: location)
                let shouldTap = button.contains(localPoint) && button.isEnabled
                button.setPressed(false)
                activeButton = nil
                swipeStart = nil
                if shouldTap {
                    overlay.handleTap(button: button)
                }
            } else {
                overlay.onContinue?()
                swipeStart = nil
            }
            return
        }
        if overviewOverlay != nil {
            if let button = activeButton {
                let localPoint = localPoint(for: button, scenePoint: location)
                button.setPressed(false)
                activeButton = nil
                _ = button.contains(localPoint)
            }
            swipeStart = nil
            isMiniMapTouch = false
            closeOverview()
            return
        }
        if isMiniMapTouch {
            isMiniMapTouch = false
            let shouldOpen: Bool
            if let start = swipeStart {
                let dx = location.x - start.x
                let dy = location.y - start.y
                shouldOpen = hypot(dx, dy) < 12
            } else {
                shouldOpen = true
            }
            swipeStart = nil
            if shouldOpen, let miniMap = miniMapNode, miniMap.hitTest(location, in: self) {
                openOverview()
            }
            return
        }
        if currentGameState == .levelCompleted {
            if let button = activeButton {
                let localPoint = localPoint(for: button, scenePoint: location)
                let shouldTap = button.contains(localPoint) && button.isEnabled
                button.setPressed(false)
                activeButton = nil
                swipeStart = nil
                if shouldTap {
                    if let overlay = challengeResultOverlay, button.inParentHierarchy(overlay) {
                        overlay.handleTap(button: button)
                    } else {
                        resultOverlay?.handleTap(button: button)
                    }
                }
            } else if let button = overlayButton(at: location) {
                if let overlay = challengeResultOverlay, button.inParentHierarchy(overlay) {
                    overlay.handleTap(button: button)
                } else {
                    resultOverlay?.handleTap(button: button)
                }
            }
            swipeStart = nil
            return
        }
        if pauseOverlay != nil, activeButton == nil {
            if handlePauseOverlayTap(at: location) {
                swipeStart = nil
                return
            }
        }
        if let button = activeButton {
            let shouldTap: Bool
            if button === pauseButton {
                shouldTap = button.isEnabled
            } else if let overlay = pauseOverlay, button.inParentHierarchy(overlay) {
                shouldTap = button.isEnabled
            } else {
                let localPoint = localPoint(for: button, scenePoint: location)
                shouldTap = button.contains(localPoint) && button.isEnabled
            }
            button.setPressed(false)
            activeButton = nil
            swipeStart = nil
            if shouldTap {
                if let overlay = pauseOverlay {
                    overlay.handleTap(button: button)
                } else if let overlay = challengeResultOverlay, button.inParentHierarchy(overlay) {
                    overlay.handleTap(button: button)
                } else if let overlay = resultOverlay {
                    overlay.handleTap(button: button)
                } else if button === pauseButton {
                    button.onTap?()
                }
            }
            return
        }

        if currentGameState == .playing || currentGameState == .idle {
            if let start = swipeStart, let direction = swipeDirection(from: start, to: location) {
                handleSwipe(direction)
            } else {
                handleTap(at: location)
            }
        } else {
            handleTap(at: location)
        }
        swipeStart = nil
    }

    override func mouseDragged(with event: NSEvent) {
        if tutorialOverlay != nil {
            if let button = activeButton {
                let location = event.location(in: self)
                let localPoint = localPoint(for: button, scenePoint: location)
                button.setPressed(button.contains(localPoint))
            }
            return
        }
        if rewardUnlockOverlay != nil {
            if let button = activeButton {
                let location = event.location(in: self)
                let localPoint = localPoint(for: button, scenePoint: location)
                button.setPressed(button.contains(localPoint))
            }
            return
        }
        if overviewOverlay != nil {
            if let button = activeButton {
                let location = event.location(in: self)
                let localPoint = localPoint(for: button, scenePoint: location)
                button.setPressed(button.contains(localPoint))
            }
            return
        }
        if isMiniMapTouch, let start = swipeStart {
            let location = event.location(in: self)
            let dx = location.x - start.x
            let dy = location.y - start.y
            if hypot(dx, dy) > 12 {
                isMiniMapTouch = false
                swipeStart = nil
            }
            return
        }
        guard let button = activeButton else { return }
        let location = event.location(in: self)
        let localPoint = localPoint(for: button, scenePoint: location)
        button.setPressed(button.contains(localPoint))
    }

    #endif
}
