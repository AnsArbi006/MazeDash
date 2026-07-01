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

    private enum PendingTutorial {
        case basics
        case mechanic(Mechanic)
    }

    private enum RaceWinner {
        case player
        case bot
    }

    private struct BotPathState: Hashable {
        let point: GridPoint
        let hasKey: Bool
        let switchActive: Bool
        let breakHits: [UInt8]
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
    private var timeBonusNodes: [GridPoint: SKNode] = [:]
    private var keyNodes: [GridPoint: SKNode] = [:]
    private var switchNodes: [GridPoint: SKNode] = [:]
    private var switchBlockNodes: [GridPoint: SKSpriteNode] = [:]
    private var orderedSwitchBlockPoints: [GridPoint] = []
    private var breakableNodes: [GridPoint: SKNode] = [:]
    private var gateNodes: [GridPoint: SKSpriteNode] = [:]
    private var gateTiles: Set<GridPoint> = []
    private var oneWayDirections: [GridPoint: MoveDirection] = [:]
    private var teleporterMap: [GridPoint: GridPoint] = [:]
    private var teleporterNodes: [GridPoint: SKSpriteNode] = [:]
    private var movingBlockDefinitions: [MovingBlockData] = []
    private var movingBlockTracks: [Int: [GridPoint]] = [:]
    private var movingBlockNodes: [Int: SKNode] = [:]
    private var movingBlockOccupiedTiles: Set<GridPoint> = []
    private var exitMarkerNode: SKSpriteNode?
    private var exitGlowNode: SKShapeNode?
    private var exitLockNode: SKNode?
    private var keyFollowerNode: SKNode?
    private var routeHintNode: SKNode?

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
    private var dailyResultOverlay: DailyResultOverlayNode?
    private var storyLeaderboardOverlay: StoryLevelLeaderboardOverlayNode?
    private var storyLeaderboardFetchTask: Task<Void, Never>?
    private var leaderboardNameOverlay: LeaderboardNamePromptOverlayNode?
    private var tutorialOverlay: MechanicTutorialOverlayNode?
    private var rewardUnlockOverlay: RewardUnlockOverlayNode?
    private lazy var gameplayKeyIconTexture = SKTexture(imageNamed: "GameplayKeyIcon")
    private lazy var gameplayTimeBonusIconTexture = SKTexture(imageNamed: "GameplayTimeBonusIcon")
    private lazy var exitLockClosedIconTexture = SKTexture(imageNamed: "ExitLockClosed")
    private lazy var exitLockOpenIconTexture = SKTexture(imageNamed: "ExitLockOpen")
    private var loadingLabel: SKLabelNode?
    private var loadingIndicatorWorkItem: DispatchWorkItem?
    private var overviewOverlay: SKNode?
    private var overviewMapNode: MiniMapNode?
    private var overviewCloseButton: ArcadeButtonNode?
    #if os(iOS) || os(tvOS)
    private var leaderboardTextField: UITextField?
    #endif
    private var requiresLeaderboardNamePrompt = false
    private var pendingStoryLeaderboardLevelId: Int?

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
    private var breakableHits: [GridPoint: Int] = [:]
    private var orderedBreakablePoints: [GridPoint] = []
    private var gateIsOpen: Bool = true

    private var elapsedTime: TimeInterval = 0
    private var challengeBonusTime: TimeInterval = 0
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
    private let hardBotStepMultiplier: TimeInterval = 1.1
    private let hardBotTurnHesitation: TimeInterval = 0.045
    private var mazeMechanicStartTime: TimeInterval = 0
    private var playerPathHistory: [GridPoint] = []
    private var chaserNode: SKSpriteNode?
    private var chaserGrid = GridPoint(row: 0, col: 0)
    private var chaserCurrentDirection: MoveDirection?
    private var chaserBehavior: ChaserBehavior?
    private var chaserIsMoving = false
    private var chaserCaughtPlayer = false
    private var chaserStartAt: TimeInterval = 0
    private var chaserNextStepTime: TimeInterval = 0
    private var chaserNextRepathTime: TimeInterval = 0
    private var chaserStartDelay: TimeInterval = 1.1
    private var chaserRepathDelay: TimeInterval = 0.28
    private var chaserSpeedMultiplier: Double = 0.84
    private var chaserTrailDelaySteps = 0
    private var chaserRevealPlayed = false
    private var chaserTargetLockPlayed = false
    private var chaserThreatLevel = 0

    private var swipeStart: CGPoint?
    private var swipeConsumed = false
    private var activeButton: ArcadeButtonNode?
    private var isMiniMapTouch = false
    private var miniMapNode: MiniMapNode?
    private var miniMapTexture: SKTexture?
    private var miniMapSetupPending = false
    private var miniMapSetupDeadline: TimeInterval = 0
    private var mazeBounds: CGRect = .zero

    private var exitRequiresKey: Bool {
        levelConfig.enabledMechanics.contains(.keysDoors)
    }

    private var exitIsUnlocked: Bool {
        !exitRequiresKey || keyCount > 0
    }

    private struct RouteHintStep {
        let destination: GridPoint
        let touchedPoints: [GridPoint]
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
        teardownLeaderboardTextField()
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
        if let overlay = storyLeaderboardOverlay {
            let safeTop = size.height / 2 - safeAreaInsets.top
            let safeBottom = -size.height / 2 + safeAreaInsets.bottom
            if overlay.parent == nil {
                hudNode.addChild(overlay)
            }
            overlay.layout(in: size, safeTop: safeTop, safeBottom: safeBottom)
            overlay.setScale(1.0)
        }
        if let overlay = leaderboardNameOverlay {
            let safeTop = size.height / 2 - safeAreaInsets.top
            let safeBottom = -size.height / 2 + safeAreaInsets.bottom
            if overlay.parent == nil {
                hudNode.addChild(overlay)
            }
            overlay.layout(in: size, safeTop: safeTop, safeBottom: safeBottom)
            overlay.setScale(1.0)
            layoutLeaderboardTextField()
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
        mazeMechanicStartTime = CACurrentMediaTime()
        updateBackground()
        worldNode.removeAllChildren()
        trailNode.removeAllChildren()
        trailNode.removeAllActions()
        trailOrbitNode?.removeFromParent()
        trailOrbitNode = nil
        trailNode.zPosition = 18
        worldNode.addChild(trailNode)
        orbNodes.removeAll()
        timeBonusNodes.removeAll()
        tileMapNode?.removeFromParent()
        tileMapNode = nil
        exitMarkerNode = nil
        exitGlowNode = nil
        exitLockNode = nil
        movingBlockDefinitions = maze.movingBlocks
        movingBlockTracks.removeAll()
        movingBlockNodes.removeAll()
        movingBlockOccupiedTiles.removeAll()
        botNode = nil
        botGrid = maze.start
        botCurrentDirection = nil
        botForcedDirection = nil
        easyBotLoopTracker.seed(at: maze.start, facing: nil)
        botIsMoving = false
        botHasStarted = false
        botFinishTime = nil
        hardBotDirectionCache.removeAll(keepingCapacity: true)
        playerPathHistory = [maze.start]
        chaserNode = nil
        chaserGrid = maze.start
        chaserCurrentDirection = nil
        chaserBehavior = maze.chaserSpawn?.behavior
        chaserIsMoving = false
        chaserCaughtPlayer = false
        chaserStartDelay = maze.chaserSpawn?.startDelay ?? 1.1
        chaserRepathDelay = maze.chaserSpawn?.repathDelay ?? 0.28
        chaserSpeedMultiplier = maze.chaserSpawn?.speedMultiplier ?? 0.84
        chaserTrailDelaySteps = maze.chaserSpawn?.trailDelaySteps ?? 0
        chaserStartAt = mazeMechanicStartTime + chaserStartDelay
        chaserNextStepTime = chaserStartAt
        chaserNextRepathTime = chaserStartAt
        chaserRevealPlayed = false
        chaserTargetLockPlayed = false
        chaserThreatLevel = 0
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
        exitMarker.addChild(exitGlow)
        worldNode.addChild(exitMarker)
        exitMarkerNode = exitMarker
        exitGlowNode = exitGlow
        exitLockNode?.removeFromParent()
        if exitRequiresKey {
            let lockNode = makeExitLockNode()
            lockNode.zPosition = 2
            exitMarker.addChild(lockNode)
            exitLockNode = lockNode
        } else {
            exitLockNode = nil
        }
        updateExitLockVisuals(animated: false)

        for orbPoint in maze.orbs {
            if isChallengeMode {
                let bonus = makeTimeBonusPickupNode()
                bonus.position = positionFor(orbPoint)
                bonus.zPosition = 12
                worldNode.addChild(bonus)
                timeBonusNodes[orbPoint] = bonus
            } else {
                let orb = SKSpriteNode(texture: orbTexture)
                orb.position = positionFor(orbPoint)
                orb.zPosition = 12
                worldNode.addChild(orb)
                orbNodes[orbPoint] = orb
            }
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
        setupChaserIfNeeded(texture: playerTexture)
        updateMovingBlocks(now: mazeMechanicStartTime)

        let mazeWidth = CGFloat(maze.cols) * tileSize
        let mazeHeight = CGFloat(maze.rows) * tileSize
        mazeBounds = CGRect(x: -mazeWidth / 2, y: -mazeHeight / 2, width: mazeWidth, height: mazeHeight)
        miniMapTexture = nil

        updateCameraScale(for: maze)
        updateCameraPosition(animated: true)
        setupFog()
        scheduleHardBotDirectionCachePriming()
        runLevelStartEntrance(startMarker: startMarker, exitMarker: exitMarker)
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
        if let tutorial = pendingTutorial() {
            setGameState(.idle)
            showTutorialOverlay(for: tutorial)
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
        isChallengeMode && currentGameState == .idle
    }

    private func updateSwipeHintIfNeeded() {
        if shouldShowSwipeHint {
            if swipeHintLabel == nil {
                let label = SKLabelNode(fontNamed: ArcadeFont.body)
                label.fontSize = 14
                label.fontColor = ArcadeStyle.Color.textPrimary.withAlphaComponent(0.9)
                label.horizontalAlignmentMode = .center
                label.verticalAlignmentMode = .center
                label.text = "SWIPE TO START"
                label.zPosition = 120
                label.alpha = 0
                hudNode.addChild(label)
                label.run(.fadeAlpha(to: 0.96, duration: 0.18))
                swipeHintLabel = label
            } else {
                swipeHintLabel?.text = "SWIPE TO START"
            }

            let safeBottom = -size.height / 2 + safeAreaInsets.bottom
            swipeHintLabel?.position = snap(CGPoint(x: 0, y: safeBottom + 34))
            return
        }

        swipeHintLabel?.removeFromParent()
        swipeHintLabel = nil
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
            primaryText = duration.hudTitle
            secondaryText = "RUN \(max(1, challengeMazeNumber))"
        } else if isDailyMode {
            primaryText = "DAILY"
            secondaryText = botDifficulty == .hard ? "BOT HARD" : "BOT EASY"
        } else {
            primaryText = "LVL \(levelDefinition.id)"
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
            (.breakableWalls, "BREAK"),
            (.keysDoors, "🗝"),
            (.teleporters, "TP"),
            (.timingGates, "GATE"),
            (.switchBlocks, "SW"),
            (.movingBlocks, "MOVE"),
            (.chaserEnemy, "CHASE"),
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
        if registerBreakableHit(at: next, triggeredByBot: true) {
            if botDifficulty == .easy {
                easyBotLoopTracker.recordMove(from: botGrid, to: botGrid, facing: directionToUse)
            }
            bot.removeAllActions()
            bot.run(.sequence([
                .wait(forDuration: 0.05),
                .run { [weak self] in self?.stepBotForward() }
            ]), withKey: "botBreakWait")
            return
        }
        guard botCanEnter(next, hasKey: keyCount > 0, switchActive: switchActivated, allowClosedGate: false) else {
            if movingBlockOccupiedTiles.contains(next) {
                bot.removeAllActions()
                bot.run(.sequence([
                    .wait(forDuration: 0.06),
                    .run { [weak self] in self?.stepBotForward() }
                ]), withKey: "botMovingBlockWait")
                return
            }
            botIsMoving = false
            return
        }

        let destination = botPositionFor(next)
        let moveDuration = botDifficulty == .hard ? stepDuration * hardBotStepMultiplier : stepDuration
        let moveAction = SKAction.move(to: destination, duration: moveDuration)
        moveAction.timingMode = .linear
        let shouldHesitateBeforeMove = botDifficulty == .hard
            && botCurrentDirection != nil
            && isIntersectionOrCorner(botGrid.row, botGrid.col)
            && botForcedDirection == nil

        var actions: [SKAction] = []
        if shouldHesitateBeforeMove {
            actions.append(.wait(forDuration: hardBotTurnHesitation))
        }
        actions.append(moveAction)
        actions.append(.run { [weak self] in
            self?.handleBotArrival(at: next)
        })
        bot.run(.sequence(actions), withKey: "botStep")
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
        if let forced = forcedBotDirection(at: point, hasKey: hasKey, switchActive: switchActive, breakHits: breakHitsVector(), allowClosedGate: true) {
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
            botCanAttempt(point.moved(by: direction), hasKey: hasKey, switchActive: switchActive, breakHits: breakHitsVector(), allowClosedGate: true)
        }
        return easyBotLoopTracker.chooseDirection(from: point, facing: facing, candidates: legal)
    }

    private func nextHardBotDirection(at point: GridPoint, hasKey: Bool, switchActive: Bool) -> MoveDirection? {
        let normalizedState = BotPathState(
            point: point,
            hasKey: hasKey || tileAt(point) == "K",
            switchActive: switchActive,
            breakHits: breakHitsVector()
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
            switchActive: switchActive,
            breakHits: breakHitsVector()
        )
        if startState.point == maze.exit {
            return nil
        }

        let initialDirections = availableBotDirections(
            from: point,
            hasKey: startState.hasKey,
            switchActive: startState.switchActive,
            breakHits: startState.breakHits,
            allowClosedGate: true
        )
        guard !initialDirections.isEmpty else {
            return nextEasyBotDirection(at: point, facing: botCurrentDirection, hasKey: hasKey, switchActive: switchActive)
        }
        var queue: [(BotPathState, MoveDirection, Int)] = []
        var visited = Set<BotPathState>([startState])
        var index = 0
        var bestCosts: [MoveDirection: Int] = [:]

        for direction in initialDirections {
            guard let nextState = botAdvanceState(from: startState, direction: direction, allowClosedGate: true) else { continue }
            if visited.insert(nextState).inserted {
                queue.append((nextState, direction, 1))
            }
        }

        while index < queue.count {
            let (state, firstMove, depth) = queue[index]
            index += 1
            if state.point == maze.exit {
                if bestCosts[firstMove] == nil {
                    bestCosts[firstMove] = depth
                }
                if bestCosts.count == initialDirections.count {
                    break
                }
                continue
            }

            let directions = availableBotDirections(
                from: state.point,
                hasKey: state.hasKey,
                switchActive: state.switchActive,
                breakHits: state.breakHits,
                allowClosedGate: true
            )
            for direction in directions {
                guard let nextState = botAdvanceState(from: state, direction: direction, allowClosedGate: true) else { continue }
                if visited.insert(nextState).inserted {
                    queue.append((nextState, firstMove, depth + 1))
                }
            }
        }

        if let softened = softenedHardBotChoice(
            from: point,
            facing: botCurrentDirection,
            costs: bestCosts,
            preferredOrder: initialDirections
        ) {
            return softened
        }
        return nextEasyBotDirection(at: point, facing: botCurrentDirection, hasKey: hasKey, switchActive: switchActive)
    }

    private func softenedHardBotChoice(
        from point: GridPoint,
        facing: MoveDirection?,
        costs: [MoveDirection: Int],
        preferredOrder: [MoveDirection]
    ) -> MoveDirection? {
        let ordered = preferredOrder.compactMap { direction -> (MoveDirection, Int)? in
            guard let cost = costs[direction] else { return nil }
            return (direction, cost)
        }.sorted {
            if $0.1 == $1.1 {
                return directionPriority($0.0, facing: facing) < directionPriority($1.0, facing: facing)
            }
            return $0.1 < $1.1
        }

        guard let best = ordered.first else { return nil }
        guard ordered.count > 1 else { return best.0 }

        let second = ordered[1]
        if shouldTakeHardBotDetour(at: point, facing: facing, bestCost: best.1, secondBestCost: second.1) {
            return second.0
        }
        return best.0
    }

    private func shouldTakeHardBotDetour(
        at point: GridPoint,
        facing: MoveDirection?,
        bestCost: Int,
        secondBestCost: Int
    ) -> Bool {
        guard secondBestCost <= bestCost + 2 else { return false }
        let facingSeed: Int
        switch facing {
        case .up: facingSeed = 1
        case .down: facingSeed = 2
        case .left: facingSeed = 3
        case .right: facingSeed = 4
        case nil: facingSeed = 0
        }
        let seed = point.row * 37 + point.col * 19 + facingSeed * 11
        return seed % 5 == 0
    }

    private func directionPriority(_ direction: MoveDirection, facing: MoveDirection?) -> Int {
        guard let facing else {
            switch direction {
            case .up: return 0
            case .right: return 1
            case .down: return 2
            case .left: return 3
            }
        }
        if direction == facing { return 0 }
        if direction == leftTurn(from: facing) { return 1 }
        if direction == rightTurn(from: facing) { return 2 }
        return 3
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
                            switchActive: switchActive,
                            breakHits: breakHitsVector()
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

    private func invalidateHardBotDirectionCacheForDynamicStateChange() {
        guard botDifficulty == .hard else { return }
        hardBotDirectionCache.removeAll(keepingCapacity: true)
        botCurrentDirection = nil
    }

    private func botAdvanceState(from state: BotPathState, direction: MoveDirection, allowClosedGate: Bool) -> BotPathState? {
        let next = state.point.moved(by: direction)
        if tileAt(next) == "B",
           let breakableIndex = orderedBreakablePoints.firstIndex(of: next),
           state.breakHits[breakableIndex] < 3 {
            var nextBreakHits = state.breakHits
            nextBreakHits[breakableIndex] = min(3, nextBreakHits[breakableIndex] + 1)
            return BotPathState(point: state.point, hasKey: state.hasKey, switchActive: state.switchActive, breakHits: nextBreakHits)
        }
        guard botCanEnter(next, hasKey: state.hasKey, switchActive: state.switchActive, allowClosedGate: allowClosedGate) else { return nil }
        var destination = next
        var nextHasKey = state.hasKey || tileAt(next) == "K"
        var nextSwitchActive = tileAt(next) == "T" ? !state.switchActive : state.switchActive
        if let teleported = teleporterMap[next] {
            destination = teleported
            nextHasKey = nextHasKey || tileAt(teleported) == "K"
            nextSwitchActive = tileAt(teleported) == "T" ? !nextSwitchActive : nextSwitchActive
        }
        return BotPathState(point: destination, hasKey: nextHasKey, switchActive: nextSwitchActive, breakHits: state.breakHits)
    }

    private func availableBotDirections(from point: GridPoint, hasKey: Bool, switchActive: Bool, breakHits: [UInt8], allowClosedGate: Bool) -> [MoveDirection] {
        if let forced = forcedBotDirection(at: point, hasKey: hasKey, switchActive: switchActive, breakHits: breakHits, allowClosedGate: allowClosedGate) {
            return [forced]
        }
        return MoveDirection.allCases.filter { direction in
            botCanAttempt(point.moved(by: direction), hasKey: hasKey, switchActive: switchActive, breakHits: breakHits, allowClosedGate: allowClosedGate)
        }
    }

    private func forcedBotDirection(at point: GridPoint, hasKey: Bool, switchActive: Bool, breakHits: [UInt8], allowClosedGate: Bool) -> MoveDirection? {
        guard let forced = oneWayDirections[point] else { return nil }
        return botCanAttempt(point.moved(by: forced), hasKey: hasKey, switchActive: switchActive, breakHits: breakHits, allowClosedGate: allowClosedGate) ? forced : nil
    }

    private func botCanEnter(_ point: GridPoint, hasKey: Bool, switchActive: Bool, allowClosedGate: Bool) -> Bool {
        guard let tile = tileAt(point) else { return false }
        if tile == "#" { return false }
        if movingBlockOccupiedTiles.contains(point) { return false }
        if tile == "E", exitRequiresKey, !hasKey { return false }
        if tile == "X", !switchActive { return false }
        if tile == "B", !isBreakableDestroyed(at: point) { return false }
        if tile == "G", !allowClosedGate, !gateIsOpen { return false }
        return true
    }

    private func botCanAttempt(_ point: GridPoint, hasKey: Bool, switchActive: Bool, breakHits: [UInt8], allowClosedGate: Bool) -> Bool {
        if tileAt(point) == "B",
           let breakableIndex = orderedBreakablePoints.firstIndex(of: point),
           breakHits[breakableIndex] < 3 {
            return true
        }
        return botCanEnter(point, hasKey: hasKey, switchActive: switchActive, allowClosedGate: allowClosedGate)
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
        routeHintNode?.removeAllActions()
        routeHintNode?.removeFromParent()
        timeBonusNodes.values.forEach { $0.removeFromParent() }
        keyFollowerNode?.removeFromParent()
        keyNodes.values.forEach { $0.removeFromParent() }
        switchNodes.values.forEach { $0.removeFromParent() }
        switchBlockNodes.values.forEach { $0.removeFromParent() }
        breakableNodes.values.forEach { $0.removeFromParent() }
        gateNodes.values.forEach { $0.removeFromParent() }
        teleporterNodes.values.forEach { $0.removeFromParent() }
        movingBlockNodes.values.forEach { $0.removeFromParent() }
        keyNodes.removeAll()
        keyFollowerNode = nil
        routeHintNode = nil
        timeBonusNodes.removeAll()
        switchNodes.removeAll()
        switchBlockNodes.removeAll()
        orderedSwitchBlockPoints.removeAll()
        orderedSwitchBlockPoints.removeAll()
        breakableNodes.removeAll()
        gateNodes.removeAll()
        gateTiles.removeAll()
        teleporterNodes.removeAll()
        movingBlockTracks.removeAll()
        movingBlockNodes.removeAll()
        movingBlockOccupiedTiles.removeAll()
        forcedDirection = nil
        keyCount = 0
        switchActivated = false
        breakableHits.removeAll()
        orderedBreakablePoints.removeAll()
        gateIsOpen = true

        var teleporterBuckets: [Character: [GridPoint]] = [:]
        let switchTexture = TextureFactory.shared.tileTexture(size: snapSize(CGSize(width: tileSize * 0.7, height: tileSize * 0.7)), style: .floor)
        let breakableTexture = TextureFactory.shared.tileTexture(size: snapSize(CGSize(width: tileSize * 0.82, height: tileSize * 0.82)), style: .wall)
        let switchBlockTexture = TextureFactory.shared.tileTexture(size: snapSize(CGSize(width: tileSize * 0.82, height: tileSize * 0.82)), style: .wall)
        let gateTexture = TextureFactory.shared.tileTexture(size: snapSize(CGSize(width: tileSize * 0.86, height: tileSize * 0.86)), style: .floor)
        let movingBlockTexture = TextureFactory.shared.tileTexture(size: snapSize(CGSize(width: tileSize * 0.8, height: tileSize * 0.8)), style: .wall)
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
                    let key = makeKeyPickupNode()
                    key.position = positionFor(point)
                    key.zPosition = 11
                    worldNode.addChild(key)
                    keyNodes[point] = key
                case "T":
                    let trigger = makeSwitchTriggerNode(texture: switchTexture)
                    trigger.position = positionFor(point)
                    trigger.zPosition = 11
                    worldNode.addChild(trigger)
                    switchNodes[point] = trigger
                case "X":
                    let block = makeSwitchBlockNode(texture: switchBlockTexture)
                    block.position = positionFor(point)
                    block.zPosition = 9
                    worldNode.addChild(block)
                    switchBlockNodes[point] = block
                    orderedSwitchBlockPoints.append(point)
                case "B":
                    let breakable = makeBreakableBlockNode(texture: breakableTexture)
                    breakable.position = positionFor(point)
                    breakable.zPosition = 9
                    worldNode.addChild(breakable)
                    breakableNodes[point] = breakable
                    breakableHits[point] = 0
                    orderedBreakablePoints.append(point)
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
                        if !["S", "E", "O", "K", "T", "D", "G", "B", "X"].contains(upper) {
                            teleporterBuckets[upper, default: []].append(point)
                        }
                    }
                }
            }
        }

        orderedBreakablePoints.sort {
            ($0.row, $0.col) < ($1.row, $1.col)
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

        for (index, movingBlock) in maze.movingBlocks.enumerated() {
            let track = movingBlockTrack(for: movingBlock)
            guard let first = track.first else { continue }
            let node = makeMovingBlockNode(texture: movingBlockTexture, track: track)
            node.position = positionFor(first)
            node.zPosition = 10
            worldNode.addChild(node)
            movingBlockTracks[index] = track
            movingBlockNodes[index] = node
        }

        updateGateVisuals()
        updateExitLockVisuals(animated: false)
        updateSwitchTriggerVisuals(animated: false)
        updateSwitchBlockVisuals(animated: false)
        updateAllBreakableVisuals(animated: false)
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

    private func updateExitLockVisuals(animated: Bool) {
        guard exitRequiresKey else {
            exitMarkerNode?.colorBlendFactor = 0
            exitGlowNode?.strokeColor = currentTheme.palette.accentPink
            exitGlowNode?.fillColor = currentTheme.palette.accentPink.withAlphaComponent(0.18)
            exitGlowNode?.alpha = 0.58
            configureExitGlowIdle(unlocked: true)
            exitLockNode?.alpha = 0
            return
        }

        let unlocked = exitIsUnlocked
        let unlockedGlowColor = mixedColor(currentTheme.palette.accentCyan, ArcadeStyle.Color.accentGreen, ratio: 0.42)
        let lockedGlowColor = currentTheme.palette.cardBorder
        let markerColor = unlocked
            ? currentTheme.palette.accentCyan
            : currentTheme.palette.cardBottom
        let glowColor = unlocked
            ? unlockedGlowColor
            : lockedGlowColor
        let glowAlpha: CGFloat = unlocked ? 0.84 : 0.11
        let markerBlend: CGFloat = unlocked ? 0.22 : 0.08
        let markerAlpha: CGFloat = unlocked ? 1.0 : 0.78

        if animated {
            exitMarkerNode?.run(.sequence([
                .scale(to: 1.07, duration: 0.12),
                .scale(to: 1.0, duration: 0.16)
            ]), withKey: "exitPulse")
            exitGlowNode?.run(.sequence([
                .group([
                    .fadeAlpha(to: min(1.0, glowAlpha + 0.14), duration: 0.12),
                    .scale(to: 1.12, duration: 0.12)
                ]),
                .group([
                    .fadeAlpha(to: glowAlpha, duration: 0.18),
                    .scale(to: 1.0, duration: 0.18)
                ])
            ]), withKey: "exitGlowPulse")
            spawnExitActivationWave(unlocked: unlocked)
        }

        exitMarkerNode?.color = markerColor
        exitMarkerNode?.colorBlendFactor = markerBlend
        exitMarkerNode?.alpha = markerAlpha
        exitGlowNode?.strokeColor = glowColor
        exitGlowNode?.fillColor = glowColor.withAlphaComponent(unlocked ? 0.18 : 0.0)
        exitGlowNode?.alpha = glowAlpha
        configureExitGlowIdle(unlocked: unlocked)

        if let lockNode = exitLockNode {
            lockNode.childNode(withName: "closed_icon")?.alpha = unlocked ? 0.0 : 1.0
            lockNode.childNode(withName: "open_icon")?.alpha = unlocked ? 1.0 : 0.0
            configureExitLockIdle(lockNode, unlocked: unlocked)
            if animated {
                if unlocked {
                    playExitUnlockSequence(for: lockNode)
                } else {
                    lockNode.removeAction(forKey: "lockState")
                    lockNode.run(.group([
                        .fadeAlpha(to: 1.0, duration: 0.14),
                        .scale(to: 1.0, duration: 0.14)
                    ]), withKey: "lockState")
                }
            } else {
                lockNode.alpha = 1.0
                lockNode.setScale(1.0)
            }
        }
    }

    private func configureExitGlowIdle(unlocked: Bool) {
        guard let exitGlowNode else { return }
        exitGlowNode.removeAction(forKey: "exitGlowIdle")
        let lowAlpha: CGFloat = unlocked ? 0.52 : 0.08
        let highAlpha: CGFloat = unlocked ? 0.82 : 0.18
        let lowScale: CGFloat = 1.0
        let highScale: CGFloat = unlocked ? 1.08 : 1.03
        exitGlowNode.run(.repeatForever(.sequence([
            .group([
                .fadeAlpha(to: highAlpha, duration: unlocked ? 0.4 : 0.62),
                .scale(to: highScale, duration: unlocked ? 0.4 : 0.62)
            ]),
            .group([
                .fadeAlpha(to: lowAlpha, duration: unlocked ? 0.4 : 0.75),
                .scale(to: lowScale, duration: unlocked ? 0.4 : 0.75)
            ])
        ])), withKey: "exitGlowIdle")
    }

    private func configureExitLockIdle(_ lockNode: SKNode, unlocked: Bool) {
        lockNode.removeAction(forKey: "lockIdle")
        let lowAlpha: CGFloat = unlocked ? 0.94 : 0.9
        let highAlpha: CGFloat = 1.0
        let highScale: CGFloat = unlocked ? 1.03 : 1.04
        lockNode.run(.repeatForever(.sequence([
            .group([
                timed(.fadeAlpha(to: highAlpha, duration: unlocked ? 0.44 : 0.58), mode: .easeInEaseOut),
                timed(.scale(to: highScale, duration: unlocked ? 0.44 : 0.58), mode: .easeInEaseOut)
            ]),
            .group([
                timed(.fadeAlpha(to: lowAlpha, duration: unlocked ? 0.6 : 0.75), mode: .easeInEaseOut),
                timed(.scale(to: 1.0, duration: unlocked ? 0.6 : 0.75), mode: .easeInEaseOut)
            ])
        ])), withKey: "lockIdle")
    }

    private func pulseLockedExit() {
        SoundFX.playBlocked(on: self)
        let basePosition = exitMarkerNode?.position ?? .zero
        let denyColor = currentTheme.palette.cardBorder
        exitLockNode?.run(.sequence([
            .group([
                .fadeAlpha(to: 1.0, duration: 0.08),
                .scale(to: 1.08, duration: 0.08)
            ]),
            .moveBy(x: -3, y: 0, duration: 0.03),
            .moveBy(x: 6, y: 0, duration: 0.05),
            .moveBy(x: -3, y: 0, duration: 0.04),
            .group([
                .fadeAlpha(to: 1.0, duration: 0.14),
                .scale(to: 1.0, duration: 0.14)
            ])
        ]), withKey: "lockedExitBounce")
        exitGlowNode?.run(.sequence([
            .group([
                .fadeAlpha(to: 0.26, duration: 0.08),
                .scale(to: 1.025, duration: 0.08)
            ]),
            .group([
                .fadeAlpha(to: 0.11, duration: 0.18),
                .scale(to: 1.0, duration: 0.18)
            ])
        ]), withKey: "lockedExitGlow")
        exitGlowNode?.strokeColor = denyColor
        exitMarkerNode?.run(.sequence([
            .group([
                .fadeAlpha(to: 0.54, duration: 0.08),
                .moveBy(x: 2, y: 0, duration: 0.04)
            ]),
            .group([
                .fadeAlpha(to: 0.62, duration: 0.16),
                .move(to: basePosition, duration: 0.12)
            ])
        ]), withKey: "lockedExitMarkerDim")
        spawnLockedExitDenyRipple()
    }

    private func spawnLockedExitDenyRipple() {
        guard let exitMarkerNode else { return }
        let ripple = SKShapeNode(circleOfRadius: tileSize * 0.16)
        ripple.position = exitMarkerNode.position
        ripple.strokeColor = currentTheme.palette.cardBorder.withAlphaComponent(0.92)
        ripple.lineWidth = 2.3
        ripple.glowWidth = 6
        ripple.fillColor = currentTheme.palette.cardBorder.withAlphaComponent(0.08)
        ripple.zPosition = 7
        worldNode.addChild(ripple)
        ripple.run(.sequence([
            .group([
                timed(.scale(to: 1.82, duration: 0.18), mode: .easeOut),
                timed(.fadeOut(withDuration: 0.18), mode: .easeOut)
            ]),
            .removeFromParent()
        ]))
    }

    private func playExitUnlockSequence(for lockNode: SKNode) {
        lockNode.removeAction(forKey: "lockState")
        let closedIcon = lockNode.childNode(withName: "closed_icon")
        let openIcon = lockNode.childNode(withName: "open_icon")
        lockNode.run(.sequence([
            .group([
                timed(.scale(to: 1.08, duration: 0.08), mode: .easeOut),
                timed(.fadeAlpha(to: 1.0, duration: 0.08), mode: .easeOut)
            ]),
            .group([
                timed(.scale(to: 0.94, duration: 0.18), mode: .easeInEaseOut),
                timed(.fadeAlpha(to: 1.0, duration: 0.18), mode: .easeInEaseOut)
            ])
        ]), withKey: "lockState")

        closedIcon?.run(.sequence([
            .group([
                timed(.fadeOut(withDuration: 0.16), mode: .easeInEaseOut),
                timed(.scale(to: 0.72, duration: 0.16), mode: .easeInEaseOut),
                timed(.moveBy(x: 0, y: tileSize * 0.05, duration: 0.16), mode: .easeInEaseOut)
            ])
        ]), withKey: "unlockClosedIcon")

        openIcon?.alpha = 0
        openIcon?.setScale(0.72)
        openIcon?.run(.sequence([
            .wait(forDuration: 0.05),
            .group([
                timed(.fadeAlpha(to: 1.0, duration: 0.18), mode: .easeOut),
                timed(.scale(to: 1.0, duration: 0.18), mode: .easeOut),
                timed(.moveBy(x: tileSize * 0.01, y: tileSize * 0.015, duration: 0.18), mode: .easeOut)
            ])
        ]), withKey: "unlockOpenIcon")

        if let flare = lockNode.childNode(withName: "lock_flare") as? SKShapeNode {
            flare.alpha = 0.0
            flare.run(.sequence([
                .group([
                    timed(.fadeAlpha(to: 0.34, duration: 0.08), mode: .easeOut),
                    timed(.scale(to: 1.18, duration: 0.08), mode: .easeOut)
                ]),
                .group([
                    timed(.fadeOut(withDuration: 0.2), mode: .easeInEaseOut),
                    timed(.scale(to: 0.92, duration: 0.2), mode: .easeInEaseOut)
                ])
            ]), withKey: "unlockFlare")
        }
    }

    private func makeExitLockNode() -> SKNode {
        let container = SKNode()
        let closedTint = currentTheme.palette.cardBorder
        let openTint = SKColor(white: 0.98, alpha: 1.0)

        let shadowPlate = SKShapeNode(ellipseOf: snapSize(CGSize(width: tileSize * 0.36, height: tileSize * 0.12)))
        shadowPlate.fillColor = SKColor(white: 0.0, alpha: 0.28)
        shadowPlate.strokeColor = .clear
        shadowPlate.position = snap(CGPoint(x: 0, y: -tileSize * 0.17))
        shadowPlate.zPosition = -1
        container.addChild(shadowPlate)

        let flare = SKShapeNode(circleOfRadius: tileSize * 0.16)
        flare.name = "lock_flare"
        flare.fillColor = SKColor(white: 1.0, alpha: 0.08)
        flare.strokeColor = .clear
        flare.alpha = 0.14
        flare.glowWidth = 2.6
        flare.position = snap(CGPoint(x: 0, y: -tileSize * 0.01))
        flare.zPosition = 0.2
        container.addChild(flare)

        let iconSize = snapSize(CGSize(width: tileSize * 0.34, height: tileSize * 0.34))

        let closedIcon = SKSpriteNode(texture: tintedTexture(from: exitLockOpenIconTexture, assetName: "ExitLockOpen", color: closedTint))
        closedIcon.name = "closed_icon"
        closedIcon.size = iconSize
        closedIcon.position = snap(CGPoint(x: 0, y: -tileSize * 0.01))
        closedIcon.zRotation = .pi
        closedIcon.zPosition = 1
        container.addChild(closedIcon)

        let openIcon = SKSpriteNode(texture: tintedTexture(from: exitLockClosedIconTexture, assetName: "ExitLockClosed", color: openTint))
        openIcon.name = "open_icon"
        openIcon.size = iconSize
        openIcon.position = snap(CGPoint(x: tileSize * 0.01, y: tileSize * 0.005))
        openIcon.zRotation = .pi
        openIcon.alpha = 0.0
        openIcon.zPosition = 1
        container.addChild(openIcon)

        return container
    }

    private func makeKeyPickupNode() -> SKNode {
        let container = SKNode()
        let keyTint = SKColor(red: 1.0, green: 0.81, blue: 0.18, alpha: 1.0)
        let keyHighlightTint = SKColor(red: 1.0, green: 0.93, blue: 0.52, alpha: 1.0)

        let glow = SKShapeNode(circleOfRadius: tileSize * 0.13)
        glow.fillColor = keyTint.withAlphaComponent(0.07)
        glow.strokeColor = keyHighlightTint.withAlphaComponent(0.22)
        glow.lineWidth = 1.1
        glow.glowWidth = 2.8
        glow.zPosition = 0
        container.addChild(glow)

        let plate = SKShapeNode(circleOfRadius: tileSize * 0.17)
        plate.fillColor = SKColor(red: 0.055, green: 0.045, blue: 0.03, alpha: 0.9)
        plate.strokeColor = keyTint.withAlphaComponent(0.34)
        plate.lineWidth = 1.2
        plate.position = snap(CGPoint(x: 0, y: -tileSize * 0.005))
        plate.zPosition = 0.4
        container.addChild(plate)

        let keyBackShadow = SKSpriteNode(texture: tintedTexture(from: gameplayKeyIconTexture, assetName: "GameplayKeyIcon", color: SKColor(white: 0.0, alpha: 1.0)))
        keyBackShadow.size = snapSize(CGSize(width: tileSize * 0.42, height: tileSize * 0.42))
        keyBackShadow.position = snap(CGPoint(x: tileSize * 0.02, y: -tileSize * 0.015))
        keyBackShadow.alpha = 0.34
        keyBackShadow.zRotation = -.pi / 18
        keyBackShadow.zPosition = 0.72
        container.addChild(keyBackShadow)

        let keyShadow = SKSpriteNode(texture: tintedTexture(from: gameplayKeyIconTexture, assetName: "GameplayKeyIcon", color: SKColor(white: 0.06, alpha: 1.0)))
        keyShadow.size = snapSize(CGSize(width: tileSize * 0.42, height: tileSize * 0.42))
        keyShadow.position = snap(CGPoint(x: tileSize * 0.012, y: -tileSize * 0.012))
        keyShadow.alpha = 0.5
        keyShadow.zRotation = -.pi / 18
        keyShadow.zPosition = 0.8
        container.addChild(keyShadow)

        let key = SKSpriteNode(texture: tintedTexture(from: gameplayKeyIconTexture, assetName: "GameplayKeyIcon", color: keyTint))
        key.name = "key_icon"
        key.size = snapSize(CGSize(width: tileSize * 0.42, height: tileSize * 0.42))
        key.position = snap(CGPoint(x: 0, y: 0))
        key.zRotation = -.pi / 18
        key.zPosition = 1
        container.addChild(key)

        let keyHighlight = SKSpriteNode(texture: tintedTexture(from: gameplayKeyIconTexture, assetName: "GameplayKeyIcon", color: keyHighlightTint))
        keyHighlight.size = snapSize(CGSize(width: tileSize * 0.42, height: tileSize * 0.42))
        keyHighlight.position = snap(CGPoint(x: -tileSize * 0.008, y: tileSize * 0.01))
        keyHighlight.alpha = 0.22
        keyHighlight.zRotation = -.pi / 18
        keyHighlight.blendMode = .add
        keyHighlight.zPosition = 1.1
        container.addChild(keyHighlight)

        let floatUp = SKAction.moveBy(x: 0, y: tileSize * 0.04, duration: 0.7)
        floatUp.timingMode = .easeInEaseOut
        let floatDown = SKAction.moveBy(x: 0, y: -tileSize * 0.04, duration: 0.7)
        floatDown.timingMode = .easeInEaseOut
        container.run(.repeatForever(.sequence([floatUp, floatDown])), withKey: "keyFloat")

        let pulseUp = SKAction.fadeAlpha(to: 0.24, duration: 0.7)
        pulseUp.timingMode = .easeInEaseOut
        let pulseDown = SKAction.fadeAlpha(to: 0.09, duration: 0.7)
        pulseDown.timingMode = .easeInEaseOut
        glow.alpha = 0.11
        glow.run(.repeatForever(.sequence([pulseUp, pulseDown])), withKey: "keyGlow")

        keyHighlight.run(.repeatForever(.sequence([
            timed(.fadeAlpha(to: 0.34, duration: 0.72), mode: .easeInEaseOut),
            timed(.fadeAlpha(to: 0.18, duration: 0.72), mode: .easeInEaseOut)
        ])), withKey: "keyHighlight")

        return container
    }

    private func makeTimeBonusPickupNode() -> SKNode {
        let container = SKNode()
        let ringTint = ArcadeStyle.Color.accentYellow
        let fillTint = SKColor(red: 1.0, green: 0.95, blue: 0.68, alpha: 1.0)
        let accentTint = SKColor(red: 0.55, green: 0.94, blue: 1.0, alpha: 1.0)
        let warmCoreTint = SKColor(red: 1.0, green: 0.84, blue: 0.28, alpha: 1.0)

        let glow = SKShapeNode(circleOfRadius: tileSize * 0.22)
        glow.fillColor = ringTint.withAlphaComponent(0.11)
        glow.strokeColor = accentTint.withAlphaComponent(0.3)
        glow.lineWidth = 1.4
        glow.glowWidth = 5.2
        glow.zPosition = 0
        container.addChild(glow)

        let halo = SKShapeNode(circleOfRadius: tileSize * 0.27)
        halo.fillColor = .clear
        halo.strokeColor = ringTint.withAlphaComponent(0.18)
        halo.lineWidth = 1.2
        halo.glowWidth = 4.6
        halo.zPosition = 0.15
        container.addChild(halo)

        let plate = SKShapeNode(circleOfRadius: tileSize * 0.245)
        plate.fillColor = SKColor(red: 0.05, green: 0.075, blue: 0.14, alpha: 0.96)
        plate.strokeColor = ringTint.withAlphaComponent(0.44)
        plate.lineWidth = 1.5
        plate.zPosition = 0.4
        container.addChild(plate)

        let innerDisc = SKShapeNode(circleOfRadius: tileSize * 0.165)
        innerDisc.fillColor = SKColor(red: 0.11, green: 0.14, blue: 0.22, alpha: 0.94)
        innerDisc.strokeColor = warmCoreTint.withAlphaComponent(0.24)
        innerDisc.lineWidth = 1.0
        innerDisc.zPosition = 0.55
        container.addChild(innerDisc)

        let iconShadow = SKSpriteNode(texture: tintedTexture(from: gameplayTimeBonusIconTexture, assetName: "GameplayTimeBonusIcon", color: SKColor(white: 0.0, alpha: 1.0)))
        iconShadow.size = snapSize(CGSize(width: tileSize * 0.62, height: tileSize * 0.62))
        iconShadow.position = snap(CGPoint(x: tileSize * 0.018, y: -tileSize * 0.016))
        iconShadow.alpha = 0.32
        iconShadow.zPosition = 0.8
        container.addChild(iconShadow)

        let iconBackGlow = SKSpriteNode(texture: tintedTexture(from: gameplayTimeBonusIconTexture, assetName: "GameplayTimeBonusIcon", color: warmCoreTint))
        iconBackGlow.size = snapSize(CGSize(width: tileSize * 0.66, height: tileSize * 0.66))
        iconBackGlow.alpha = 0.22
        iconBackGlow.blendMode = .add
        iconBackGlow.zPosition = 0.92
        container.addChild(iconBackGlow)

        let icon = SKSpriteNode(texture: tintedTexture(from: gameplayTimeBonusIconTexture, assetName: "GameplayTimeBonusIcon", color: fillTint))
        icon.name = "time_bonus_icon"
        icon.size = snapSize(CGSize(width: tileSize * 0.62, height: tileSize * 0.62))
        icon.zPosition = 1
        container.addChild(icon)

        let iconAccent = SKSpriteNode(texture: tintedTexture(from: gameplayTimeBonusIconTexture, assetName: "GameplayTimeBonusIcon", color: accentTint))
        iconAccent.size = snapSize(CGSize(width: tileSize * 0.62, height: tileSize * 0.62))
        iconAccent.position = snap(CGPoint(x: -tileSize * 0.01, y: tileSize * 0.01))
        iconAccent.alpha = 0.16
        iconAccent.blendMode = .add
        iconAccent.zPosition = 1.1
        container.addChild(iconAccent)

        let iconHighlight = SKSpriteNode(texture: tintedTexture(from: gameplayTimeBonusIconTexture, assetName: "GameplayTimeBonusIcon", color: .white))
        iconHighlight.size = snapSize(CGSize(width: tileSize * 0.62, height: tileSize * 0.62))
        iconHighlight.position = snap(CGPoint(x: -tileSize * 0.015, y: tileSize * 0.02))
        iconHighlight.alpha = 0.12
        iconHighlight.blendMode = .add
        iconHighlight.zPosition = 1.18
        container.addChild(iconHighlight)

        plate.run(.repeatForever(.sequence([
            timed(.scale(to: 1.06, duration: 0.72), mode: .easeInEaseOut),
            timed(.scale(to: 1.0, duration: 0.72), mode: .easeInEaseOut)
        ])), withKey: "timeBonusPlatePulse")

        container.run(.repeatForever(.sequence([
            timed(.moveBy(x: 0, y: tileSize * 0.055, duration: 0.62), mode: .easeInEaseOut),
            timed(.moveBy(x: 0, y: -tileSize * 0.055, duration: 0.62), mode: .easeInEaseOut)
        ])), withKey: "timeBonusFloat")

        glow.alpha = 0.14
        glow.run(.repeatForever(.sequence([
            timed(.fadeAlpha(to: 0.34, duration: 0.62), mode: .easeInEaseOut),
            timed(.fadeAlpha(to: 0.12, duration: 0.62), mode: .easeInEaseOut)
        ])), withKey: "timeBonusGlow")

        halo.alpha = 0.24
        halo.run(.repeatForever(.sequence([
            timed(.scale(to: 1.08, duration: 0.74), mode: .easeInEaseOut),
            timed(.scale(to: 0.98, duration: 0.74), mode: .easeInEaseOut)
        ])), withKey: "timeBonusHaloPulse")
        halo.run(.repeatForever(timed(.rotate(byAngle: -.pi * 2, duration: 5.8), mode: .linear)), withKey: "timeBonusHaloSpin")

        icon.run(.repeatForever(.sequence([
            timed(.scale(to: 1.04, duration: 0.48), mode: .easeOut),
            timed(.scale(to: 1.0, duration: 0.54), mode: .easeInEaseOut)
        ])), withKey: "timeBonusIconPulse")
        iconAccent.run(.repeatForever(.sequence([
            timed(.fadeAlpha(to: 0.26, duration: 0.48), mode: .easeOut),
            timed(.fadeAlpha(to: 0.12, duration: 0.62), mode: .easeInEaseOut)
        ])), withKey: "timeBonusAccentPulse")
        iconHighlight.run(.repeatForever(.sequence([
            timed(.fadeAlpha(to: 0.22, duration: 0.42), mode: .easeOut),
            timed(.fadeAlpha(to: 0.08, duration: 0.64), mode: .easeInEaseOut)
        ])), withKey: "timeBonusHighlightPulse")
        iconBackGlow.run(.repeatForever(.sequence([
            timed(.fadeAlpha(to: 0.34, duration: 0.52), mode: .easeOut),
            timed(.fadeAlpha(to: 0.18, duration: 0.66), mode: .easeInEaseOut)
        ])), withKey: "timeBonusCoreGlow")

        return container
    }

    private func attachCollectedKeyFollower(from keyNode: SKNode) {
        keyFollowerNode?.removeFromParent()
        keyFollowerNode = keyNode
        keyNode.removeAction(forKey: "keyFloat")
        keyNode.setScale(0.82)
        keyNode.zPosition = 19
        if keyNode.parent == nil {
            worldNode.addChild(keyNode)
        }

        let settle = SKAction.sequence([
            .scale(to: 0.94, duration: 0.08),
            .scale(to: 0.82, duration: 0.12)
        ])
        keyNode.run(settle, withKey: "keyFollowSettle")
        updateCollectedKeyFollower(forceSnap: true)
    }

    private func updateCollectedKeyFollower(forceSnap: Bool = false) {
        guard let player = playerNode, let keyFollowerNode else { return }

        let facing = currentDirection ?? forcedDirection ?? .right
        let hoverPhase = CGFloat(CACurrentMediaTime() * 4.6)
        let hoverYOffset = sin(hoverPhase) * tileSize * 0.04
        let targetOffset: CGPoint
        switch facing {
        case .up:
            targetOffset = CGPoint(x: tileSize * 0.16, y: -tileSize * 0.34 + hoverYOffset)
        case .down:
            targetOffset = CGPoint(x: -tileSize * 0.16, y: tileSize * 0.34 + hoverYOffset)
        case .left:
            targetOffset = CGPoint(x: tileSize * 0.34, y: tileSize * 0.12 + hoverYOffset)
        case .right:
            targetOffset = CGPoint(x: -tileSize * 0.34, y: tileSize * 0.12 + hoverYOffset)
        }

        let target = CGPoint(x: player.position.x + targetOffset.x, y: player.position.y + targetOffset.y)
        if forceSnap {
            keyFollowerNode.position = snap(target)
            return
        }

        let current = keyFollowerNode.position
        let lerp: CGFloat = 0.22
        let next = CGPoint(
            x: current.x + (target.x - current.x) * lerp,
            y: current.y + (target.y - current.y) * lerp
        )
        keyFollowerNode.position = snap(next)
        keyFollowerNode.zRotation = sin(hoverPhase * 0.5) * 0.08
    }

    private func makeBreakableBlockNode(texture: SKTexture) -> SKNode {
        let container = SKNode()

        let shadow = makeGroundShadow(size: CGSize(width: tileSize * 0.42, height: tileSize * 0.16), alpha: 0.22)
        shadow.position = CGPoint(x: 0, y: -tileSize * 0.18)
        shadow.zPosition = -2
        container.addChild(shadow)

        let halo = makeGlowHalo(radius: tileSize * 0.18, color: ArcadeStyle.Color.accentYellow, alpha: 0.16, glowWidth: 7)
        halo.name = "halo"
        halo.zPosition = -1
        container.addChild(halo)

        let base = SKSpriteNode(texture: texture)
        base.name = "base"
        base.color = ArcadeStyle.Color.accentYellow
        base.colorBlendFactor = 0.42
        base.zPosition = 0
        container.addChild(base)

        let panel = SKShapeNode(rectOf: snapSize(CGSize(width: tileSize * 0.62, height: tileSize * 0.62)), cornerRadius: 7)
        panel.name = "panel"
        panel.fillColor = SKColor(red: 0.22, green: 0.16, blue: 0.08, alpha: 0.92)
        panel.strokeColor = SKColor(red: 1.0, green: 0.82, blue: 0.38, alpha: 0.3)
        panel.lineWidth = 1.0
        panel.zPosition = 0.5
        container.addChild(panel)

        let frame = SKShapeNode(rectOf: snapSize(CGSize(width: tileSize * 0.8, height: tileSize * 0.8)), cornerRadius: 8)
        frame.name = "frame"
        frame.strokeColor = ArcadeStyle.Color.accentYellow.withAlphaComponent(0.95)
        frame.lineWidth = 1.8
        frame.glowWidth = 3
        frame.fillColor = .clear
        frame.zPosition = 1
        container.addChild(frame)

        for index in [-1, 1] {
            let brace = SKShapeNode(rectOf: snapSize(CGSize(width: tileSize * 0.12, height: tileSize * 0.5)), cornerRadius: 3)
            brace.name = "brace_\(index == -1 ? "left" : "right")"
            brace.fillColor = SKColor(white: 0.08, alpha: 0.34)
            brace.strokeColor = .clear
            brace.position = snap(CGPoint(x: CGFloat(index) * tileSize * 0.18, y: 0))
            brace.zPosition = 1.2
            container.addChild(brace)
        }

        for index in 0..<3 {
            let pip = SKShapeNode(rectOf: snapSize(CGSize(width: tileSize * 0.14, height: tileSize * 0.06)), cornerRadius: 2)
            pip.name = "hp_\(index)"
            pip.fillColor = ArcadeStyle.Color.accentYellow
            pip.strokeColor = .clear
            pip.position = snap(CGPoint(x: CGFloat(index - 1) * tileSize * 0.16, y: -tileSize * 0.22))
            pip.zPosition = 2
            container.addChild(pip)
        }

        let crackPathA = CGMutablePath()
        crackPathA.move(to: CGPoint(x: -tileSize * 0.18, y: tileSize * 0.16))
        crackPathA.addLine(to: CGPoint(x: 0, y: 0))
        let crackPathB = CGMutablePath()
        crackPathB.move(to: CGPoint(x: tileSize * 0.16, y: tileSize * 0.12))
        crackPathB.addLine(to: CGPoint(x: -tileSize * 0.04, y: -tileSize * 0.06))
        let crackPathC = CGMutablePath()
        crackPathC.move(to: CGPoint(x: -tileSize * 0.04, y: tileSize * 0.02))
        crackPathC.addLine(to: CGPoint(x: tileSize * 0.18, y: -tileSize * 0.18))

        for (name, path) in [("crack_1", crackPathA), ("crack_2", crackPathB), ("crack_3", crackPathC)] {
            let line = SKShapeNode(path: path)
            line.name = name
            line.strokeColor = SKColor(white: 0.08, alpha: 0.92)
            line.lineWidth = 2.2
            line.glowWidth = 2
            line.zPosition = 2
            line.alpha = 0
            container.addChild(line)
        }

        return container
    }

    private func makeSwitchTriggerNode(texture: SKTexture) -> SKNode {
        let container = SKNode()

        let base = SKSpriteNode(texture: texture)
        base.name = "base"
        base.color = ArcadeStyle.Color.panelBottom
        base.colorBlendFactor = 0.34
        base.alpha = 0.9
        base.setScale(0.92)
        base.zPosition = 0
        container.addChild(base)

        let plate = SKShapeNode(rectOf: snapSize(CGSize(width: tileSize * 0.76, height: tileSize * 0.76)), cornerRadius: 10)
        plate.name = "plate"
        plate.fillColor = SKColor(red: 0.1, green: 0.14, blue: 0.24, alpha: 0.92)
        plate.strokeColor = ArcadeStyle.Color.accentCyan.withAlphaComponent(0.78)
        plate.lineWidth = 1.8
        plate.glowWidth = 4
        plate.position = snap(CGPoint(x: 0, y: -tileSize * 0.01))
        plate.zPosition = 1
        container.addChild(plate)

        let outerRing = SKShapeNode(circleOfRadius: tileSize * 0.22)
        outerRing.name = "outerRing"
        outerRing.strokeColor = ArcadeStyle.Color.accentCyan.withAlphaComponent(0.42)
        outerRing.lineWidth = 1.2
        outerRing.glowWidth = 2
        outerRing.fillColor = .clear
        outerRing.position = snap(CGPoint(x: 0, y: -tileSize * 0.015))
        outerRing.zPosition = 1.4
        container.addChild(outerRing)

        let panel = SKShapeNode(rectOf: snapSize(CGSize(width: tileSize * 0.54, height: tileSize * 0.54)), cornerRadius: 8)
        panel.name = "panel"
        panel.fillColor = SKColor(red: 0.07, green: 0.11, blue: 0.2, alpha: 0.98)
        panel.strokeColor = ArcadeStyle.Color.accentMagenta.withAlphaComponent(0.74)
        panel.lineWidth = 1.2
        panel.glowWidth = 2
        panel.position = snap(CGPoint(x: 0, y: -tileSize * 0.015))
        panel.zPosition = 2
        container.addChild(panel)

        let ring = SKShapeNode(circleOfRadius: tileSize * 0.12)
        ring.name = "ring"
        ring.strokeColor = ArcadeStyle.Color.accentCyan.withAlphaComponent(0.94)
        ring.lineWidth = 1.7
        ring.glowWidth = 4
        ring.fillColor = .clear
        ring.position = snap(CGPoint(x: 0, y: tileSize * 0.03))
        ring.zPosition = 3
        container.addChild(ring)

        let stem = SKShapeNode(rectOf: snapSize(CGSize(width: tileSize * 0.05, height: tileSize * 0.14)), cornerRadius: tileSize * 0.02)
        stem.name = "stem"
        stem.fillColor = ArcadeStyle.Color.accentCyan.withAlphaComponent(0.94)
        stem.strokeColor = .clear
        stem.position = snap(CGPoint(x: 0, y: tileSize * 0.11))
        stem.zPosition = 4
        container.addChild(stem)

        let core = SKShapeNode(circleOfRadius: tileSize * 0.055)
        core.name = "core"
        core.fillColor = ArcadeStyle.Color.accentMagenta.withAlphaComponent(0.96)
        core.strokeColor = .clear
        core.position = snap(CGPoint(x: 0, y: tileSize * 0.03))
        core.zPosition = 5
        container.addChild(core)

        let badgeBar = SKShapeNode(rectOf: snapSize(CGSize(width: tileSize * 0.2, height: tileSize * 0.035)), cornerRadius: tileSize * 0.016)
        badgeBar.name = "badgeBar"
        badgeBar.fillColor = ArcadeStyle.Color.textPrimary.withAlphaComponent(0.82)
        badgeBar.strokeColor = .clear
        badgeBar.position = snap(CGPoint(x: 0, y: -tileSize * 0.22))
        badgeBar.zPosition = 5
        container.addChild(badgeBar)

        for index in 0..<4 {
            let marker = SKShapeNode(rectOf: snapSize(CGSize(width: tileSize * 0.07, height: tileSize * 0.025)), cornerRadius: tileSize * 0.01)
            marker.name = "marker_\(index)"
            marker.fillColor = ArcadeStyle.Color.textPrimary.withAlphaComponent(0.72)
            marker.strokeColor = .clear
            let angle = CGFloat(index) * (.pi / 2)
            marker.position = snap(CGPoint(x: cos(angle) * tileSize * 0.18, y: -tileSize * 0.015 + sin(angle) * tileSize * 0.18))
            marker.zRotation = angle
            marker.zPosition = 4.5
            container.addChild(marker)
        }

        let idlePulse = SKAction.repeatForever(.sequence([
            .group([
                .fadeAlpha(to: 0.7, duration: 0.8),
                .scale(to: 0.92, duration: 0.8)
            ]),
            .group([
                .fadeAlpha(to: 1.0, duration: 0.95),
                .scale(to: 1.0, duration: 0.95)
            ])
        ]))
        ring.run(idlePulse, withKey: "switchIdle")
        core.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.8, duration: 0.65),
            .fadeAlpha(to: 1.0, duration: 0.85)
        ])), withKey: "switchIdle")

        return container
    }

    private func makeSwitchBlockNode(texture: SKTexture) -> SKSpriteNode {
        let base = SKSpriteNode(texture: texture)
        base.name = "base"
        base.color = ArcadeStyle.Color.accentCyan
        base.colorBlendFactor = 0.26

        let frame = SKShapeNode(rectOf: snapSize(CGSize(width: tileSize * 0.84, height: tileSize * 0.84)), cornerRadius: 8)
        frame.name = "frame"
        frame.strokeColor = ArcadeStyle.Color.accentCyan.withAlphaComponent(0.96)
        frame.lineWidth = 1.8
        frame.glowWidth = 5
        frame.fillColor = .clear
        frame.zPosition = 1
        base.addChild(frame)

        let panel = SKShapeNode(rectOf: snapSize(CGSize(width: tileSize * 0.62, height: tileSize * 0.62)), cornerRadius: 6)
        panel.name = "panel"
        panel.fillColor = ArcadeStyle.Color.accentCyan.withAlphaComponent(0.28)
        panel.strokeColor = .clear
        panel.position = snap(CGPoint(x: 0, y: 0))
        panel.zPosition = 2
        base.addChild(panel)

        let inset = SKShapeNode(rectOf: snapSize(CGSize(width: tileSize * 0.44, height: tileSize * 0.44)), cornerRadius: 4)
        inset.name = "inset"
        inset.fillColor = SKColor(red: 0.05, green: 0.1, blue: 0.18, alpha: 0.92)
        inset.strokeColor = ArcadeStyle.Color.accentCyan.withAlphaComponent(0.18)
        inset.lineWidth = 0.8
        inset.zPosition = 2.2
        base.addChild(inset)

        for index in -1...1 {
            let bar = SKShapeNode(rectOf: snapSize(CGSize(width: tileSize * 0.16, height: tileSize * 0.05)), cornerRadius: 2)
            bar.name = "bar_\(index + 1)"
            bar.fillColor = ArcadeStyle.Color.textPrimary.withAlphaComponent(0.85)
            bar.strokeColor = .clear
            bar.zRotation = -.pi / 4
            bar.position = snap(CGPoint(x: CGFloat(index) * tileSize * 0.16, y: CGFloat(index) * tileSize * 0.04))
            bar.zPosition = 3
            base.addChild(bar)
        }

        let verticalCore = SKShapeNode(rectOf: snapSize(CGSize(width: tileSize * 0.06, height: tileSize * 0.36)), cornerRadius: 2)
        verticalCore.name = "verticalCore"
        verticalCore.fillColor = ArcadeStyle.Color.accentCyan.withAlphaComponent(0.7)
        verticalCore.strokeColor = .clear
        verticalCore.zPosition = 2.9
        base.addChild(verticalCore)

        let railTop = SKShapeNode(rectOf: snapSize(CGSize(width: tileSize * 0.48, height: tileSize * 0.03)), cornerRadius: tileSize * 0.012)
        railTop.name = "railTop"
        railTop.fillColor = ArcadeStyle.Color.accentCyan.withAlphaComponent(0.42)
        railTop.strokeColor = .clear
        railTop.position = snap(CGPoint(x: 0, y: tileSize * 0.17))
        railTop.zPosition = 2.6
        base.addChild(railTop)

        let railBottom = SKShapeNode(rectOf: snapSize(CGSize(width: tileSize * 0.48, height: tileSize * 0.03)), cornerRadius: tileSize * 0.012)
        railBottom.name = "railBottom"
        railBottom.fillColor = ArcadeStyle.Color.accentCyan.withAlphaComponent(0.42)
        railBottom.strokeColor = .clear
        railBottom.position = snap(CGPoint(x: 0, y: -tileSize * 0.17))
        railBottom.zPosition = 2.6
        base.addChild(railBottom)

        let stateLight = SKShapeNode(circleOfRadius: tileSize * 0.05)
        stateLight.name = "stateLight"
        stateLight.fillColor = ArcadeStyle.Color.accentCyan
        stateLight.strokeColor = .clear
        stateLight.position = snap(CGPoint(x: tileSize * 0.22, y: tileSize * 0.22))
        stateLight.glowWidth = 4
        stateLight.zPosition = 4
        base.addChild(stateLight)

        let gateBar = SKShapeNode(rectOf: snapSize(CGSize(width: tileSize * 0.34, height: tileSize * 0.045)), cornerRadius: tileSize * 0.02)
        gateBar.name = "gateBar"
        gateBar.fillColor = ArcadeStyle.Color.textPrimary.withAlphaComponent(0.82)
        gateBar.strokeColor = .clear
        gateBar.position = snap(CGPoint(x: 0, y: -tileSize * 0.22))
        gateBar.zPosition = 4
        base.addChild(gateBar)

        let passOutline = SKShapeNode(rectOf: snapSize(CGSize(width: tileSize * 0.72, height: tileSize * 0.72)), cornerRadius: 7)
        passOutline.name = "passOutline"
        passOutline.strokeColor = ArcadeStyle.Color.accentGreen.withAlphaComponent(0.0)
        passOutline.lineWidth = 1.4
        passOutline.glowWidth = 2
        passOutline.fillColor = .clear
        passOutline.zPosition = 4.3
        base.addChild(passOutline)

        return base
    }

    private func updateSwitchTriggerVisuals(animated: Bool) {
        for node in switchNodes.values {
            let frameColor = switchActivated ? ArcadeStyle.Color.accentMagenta : ArcadeStyle.Color.accentCyan
            let coreColor = switchActivated ? ArcadeStyle.Color.accentYellow : ArcadeStyle.Color.accentMagenta
            let targetScale: CGFloat = switchActivated ? 1.03 : 1.0
            let panelOffsetY = switchActivated ? -tileSize * 0.045 : -tileSize * 0.015
            let plateOffsetY = switchActivated ? -tileSize * 0.032 : -tileSize * 0.01

            if let base = node.childNode(withName: "base") as? SKSpriteNode {
                base.color = switchActivated ? ArcadeStyle.Color.panelTop : ArcadeStyle.Color.panelBottom
            }
            if let plate = node.childNode(withName: "plate") as? SKShapeNode {
                plate.strokeColor = frameColor.withAlphaComponent(switchActivated ? 1.0 : 0.78)
                plate.fillColor = switchActivated
                    ? SKColor(red: 0.13, green: 0.1, blue: 0.2, alpha: 0.96)
                    : SKColor(red: 0.1, green: 0.14, blue: 0.24, alpha: 0.92)
                plate.glowWidth = switchActivated ? 7 : 4
                plate.position = snap(CGPoint(x: 0, y: plateOffsetY))
            }
            if let outerRing = node.childNode(withName: "outerRing") as? SKShapeNode {
                outerRing.strokeColor = frameColor.withAlphaComponent(switchActivated ? 0.88 : 0.42)
                outerRing.alpha = switchActivated ? 0.92 : 0.76
                outerRing.glowWidth = switchActivated ? 5 : 2
            }
            if let panel = node.childNode(withName: "panel") as? SKShapeNode {
                panel.strokeColor = switchActivated ? ArcadeStyle.Color.accentYellow.withAlphaComponent(0.82) : ArcadeStyle.Color.accentMagenta.withAlphaComponent(0.74)
                panel.fillColor = switchActivated
                    ? ArcadeStyle.Color.accentMagenta.withAlphaComponent(0.22)
                    : SKColor(red: 0.07, green: 0.11, blue: 0.2, alpha: 0.98)
                panel.position = snap(CGPoint(x: 0, y: panelOffsetY))
            }
            if let ring = node.childNode(withName: "ring") as? SKShapeNode {
                ring.strokeColor = frameColor.withAlphaComponent(0.96)
                ring.glowWidth = switchActivated ? 8 : 4
            }
            if let stem = node.childNode(withName: "stem") as? SKShapeNode {
                stem.fillColor = frameColor.withAlphaComponent(0.96)
            }
            if let core = node.childNode(withName: "core") as? SKShapeNode {
                core.fillColor = coreColor.withAlphaComponent(0.98)
                core.glowWidth = switchActivated ? 7 : 3
            }
            if let badgeBar = node.childNode(withName: "badgeBar") as? SKShapeNode {
                badgeBar.fillColor = switchActivated ? ArcadeStyle.Color.accentYellow.withAlphaComponent(0.88) : ArcadeStyle.Color.textPrimary.withAlphaComponent(0.82)
            }
            for index in 0..<4 {
                if let marker = node.childNode(withName: "marker_\(index)") as? SKShapeNode {
                    marker.fillColor = switchActivated
                        ? ArcadeStyle.Color.accentYellow.withAlphaComponent(0.84)
                        : ArcadeStyle.Color.textPrimary.withAlphaComponent(0.72)
                }
            }

            node.removeAction(forKey: "switchTriggerVisual")
            if animated {
                node.run(.sequence([
                    .group([
                        .scale(to: targetScale, duration: 0.06),
                        .fadeAlpha(to: 0.84, duration: 0.06)
                    ]),
                    .group([
                        .scale(to: 1.0, duration: 0.14),
                        .fadeAlpha(to: 1.0, duration: 0.14)
                    ])
                ]), withKey: "switchTriggerVisual")
            } else {
                node.alpha = 1.0
                node.setScale(1.0)
            }
        }
    }

    private func updateSwitchBlockVisuals(animated: Bool) {
        let passable = switchActivated
        for (index, point) in orderedSwitchBlockPoints.enumerated() {
            guard let node = switchBlockNodes[point] else { continue }
            node.removeAction(forKey: "switchBlockVisual")
            let targetAlpha: CGFloat = passable ? 0.26 : 0.98
            let targetScale: CGFloat = passable ? 0.88 : 1.0
            let targetColor = passable ? ArcadeStyle.Color.panelBorder : ArcadeStyle.Color.accentCyan
            node.color = targetColor
            node.colorBlendFactor = passable ? 0.08 : 0.3
            if let frame = node.childNode(withName: "frame") as? SKShapeNode {
                frame.strokeColor = (passable ? ArcadeStyle.Color.accentGreen : ArcadeStyle.Color.accentCyan).withAlphaComponent(passable ? 0.54 : 0.98)
                frame.alpha = passable ? 0.54 : 1.0
                frame.glowWidth = passable ? 1.5 : 6
            }
            if let panel = node.childNode(withName: "panel") as? SKShapeNode {
                panel.fillColor = passable
                    ? ArcadeStyle.Color.accentGreen.withAlphaComponent(0.04)
                    : ArcadeStyle.Color.accentCyan.withAlphaComponent(0.16)
                panel.alpha = passable ? 0.38 : 0.95
            }
            if let inset = node.childNode(withName: "inset") as? SKShapeNode {
                inset.fillColor = passable
                    ? SKColor(red: 0.04, green: 0.09, blue: 0.11, alpha: 0.55)
                    : SKColor(red: 0.05, green: 0.1, blue: 0.18, alpha: 0.92)
                inset.strokeColor = (passable ? ArcadeStyle.Color.accentGreen : ArcadeStyle.Color.accentCyan).withAlphaComponent(passable ? 0.12 : 0.22)
            }
            if let verticalCore = node.childNode(withName: "verticalCore") as? SKShapeNode {
                verticalCore.fillColor = (passable ? ArcadeStyle.Color.accentGreen : ArcadeStyle.Color.accentCyan).withAlphaComponent(passable ? 0.24 : 0.72)
                verticalCore.alpha = passable ? 0.36 : 1.0
            }
            if let railTop = node.childNode(withName: "railTop") as? SKShapeNode {
                railTop.fillColor = (passable ? ArcadeStyle.Color.accentGreen : ArcadeStyle.Color.accentCyan).withAlphaComponent(passable ? 0.18 : 0.42)
                railTop.alpha = passable ? 0.44 : 1.0
            }
            if let railBottom = node.childNode(withName: "railBottom") as? SKShapeNode {
                railBottom.fillColor = (passable ? ArcadeStyle.Color.accentGreen : ArcadeStyle.Color.accentCyan).withAlphaComponent(passable ? 0.18 : 0.42)
                railBottom.alpha = passable ? 0.44 : 1.0
            }
            for index in 0...2 {
                if let bar = node.childNode(withName: "bar_\(index)") as? SKShapeNode {
                    bar.alpha = passable ? 0.08 : 0.82
                    bar.fillColor = passable ? ArcadeStyle.Color.accentGreen.withAlphaComponent(0.36) : ArcadeStyle.Color.textPrimary.withAlphaComponent(0.86)
                }
            }
            if let stateLight = node.childNode(withName: "stateLight") as? SKShapeNode {
                stateLight.fillColor = passable ? ArcadeStyle.Color.accentGreen : ArcadeStyle.Color.accentCyan
                stateLight.alpha = passable ? 0.78 : 1.0
                stateLight.glowWidth = passable ? 6 : 4
            }
            if let gateBar = node.childNode(withName: "gateBar") as? SKShapeNode {
                gateBar.fillColor = passable ? ArcadeStyle.Color.accentGreen.withAlphaComponent(0.62) : ArcadeStyle.Color.textPrimary.withAlphaComponent(0.82)
                gateBar.alpha = passable ? 0.55 : 0.92
            }
            if let passOutline = node.childNode(withName: "passOutline") as? SKShapeNode {
                passOutline.strokeColor = ArcadeStyle.Color.accentGreen.withAlphaComponent(passable ? 0.72 : 0.0)
                passOutline.alpha = passable ? 0.82 : 0.0
                passOutline.glowWidth = passable ? 3 : 0
            }
            if animated {
                node.run(.sequence([
                    .wait(forDuration: Double(index) * 0.012),
                    .group([
                        .fadeAlpha(to: min(1.0, targetAlpha + 0.16), duration: 0.05),
                        .scale(to: passable ? 0.93 : 1.05, duration: 0.05)
                    ]),
                    .group([
                        .fadeAlpha(to: targetAlpha, duration: 0.16),
                        .scale(to: targetScale, duration: 0.16)
                    ])
                ]), withKey: "switchBlockVisual")
            } else {
                node.alpha = targetAlpha
                node.setScale(targetScale)
            }
        }
    }

    private func makeMovingBlockNode(texture: SKTexture, track: [GridPoint]) -> SKNode {
        let container = SKNode()

        let shadow = makeGroundShadow(size: CGSize(width: tileSize * 0.4, height: tileSize * 0.16), alpha: 0.22)
        shadow.position = CGPoint(x: 0, y: -tileSize * 0.16)
        shadow.zPosition = -2
        container.addChild(shadow)

        let halo = makeGlowHalo(radius: tileSize * 0.2, color: ArcadeStyle.Color.accentMagenta, alpha: 0.26, glowWidth: 8)
        halo.name = "halo"
        halo.zPosition = -1
        container.addChild(halo)

        let base = SKSpriteNode(texture: texture)
        base.name = "base"
        base.color = ArcadeStyle.Color.accentMagenta
        base.colorBlendFactor = 0.54
        base.zPosition = 0
        container.addChild(base)

        let frame = SKShapeNode(rectOf: snapSize(CGSize(width: tileSize * 0.8, height: tileSize * 0.8)), cornerRadius: 8)
        frame.strokeColor = ArcadeStyle.Color.accentMagenta.withAlphaComponent(0.94)
        frame.lineWidth = 1.6
        frame.glowWidth = 5
        frame.fillColor = .clear
        frame.zPosition = 1
        container.addChild(frame)

        let panel = SKShapeNode(rectOf: snapSize(CGSize(width: tileSize * 0.58, height: tileSize * 0.58)), cornerRadius: 6)
        panel.fillColor = ArcadeStyle.Color.accentCyan.withAlphaComponent(0.16)
        panel.strokeColor = .clear
        panel.zPosition = 2
        container.addChild(panel)

        for index in -1...1 {
            let bar = SKShapeNode(rectOf: snapSize(CGSize(width: tileSize * 0.16, height: tileSize * 0.05)), cornerRadius: 2)
            bar.fillColor = ArcadeStyle.Color.textPrimary.withAlphaComponent(0.82)
            bar.strokeColor = .clear
            bar.zRotation = -.pi / 6
            bar.position = snap(CGPoint(x: CGFloat(index) * tileSize * 0.15, y: 0))
            bar.zPosition = 3
            container.addChild(bar)
        }

        let pulse = SKAction.repeatForever(.sequence([
            .group([
                .fadeAlpha(to: 0.38, duration: 0.52),
                .scale(to: 1.05, duration: 0.52)
            ]),
            .group([
                .fadeAlpha(to: 0.22, duration: 0.62),
                .scale(to: 1.0, duration: 0.62)
            ])
        ]))
        halo.run(pulse, withKey: "movingBlockPulse")

        if let first = track.first, let last = track.last, first != last {
            let horizontal = first.row == last.row
            let startPosition = positionFor(first)
            for (index, point) in [first, last].enumerated() {
                let anchor = SKShapeNode(
                    rectOf: snapSize(CGSize(
                        width: horizontal ? tileSize * 0.17 : tileSize * 0.09,
                        height: horizontal ? tileSize * 0.09 : tileSize * 0.17
                    )),
                    cornerRadius: tileSize * 0.022
                )
                anchor.fillColor = ArcadeStyle.Color.accentMagenta.withAlphaComponent(0.18)
                anchor.strokeColor = ArcadeStyle.Color.accentCyan.withAlphaComponent(0.48)
                anchor.lineWidth = 1.0
                anchor.glowWidth = 1.5
                anchor.alpha = 0.68
                anchor.zPosition = -1.5
                let pointPosition = positionFor(point)
                anchor.position = snap(CGPoint(x: pointPosition.x - startPosition.x, y: pointPosition.y - startPosition.y))
                container.addChild(anchor)
                anchor.run(.repeatForever(.sequence([
                    .wait(forDuration: Double(index) * 0.18),
                    .group([
                        timed(.fadeAlpha(to: 0.96, duration: 0.42), mode: .easeInEaseOut),
                        timed(.scale(to: 1.08, duration: 0.42), mode: .easeInEaseOut)
                    ]),
                    .group([
                        timed(.fadeAlpha(to: 0.62, duration: 0.62), mode: .easeInEaseOut),
                        timed(.scale(to: 1.0, duration: 0.62), mode: .easeInEaseOut)
                    ])
                ])), withKey: "movingAnchorPulse_\(index)")
            }
        }

        return container
    }

    private func movingBlockTrack(for definition: MovingBlockData) -> [GridPoint] {
        if let cached = movingBlockTracks.first(where: { $0.value.first == definition.start && $0.value.last == definition.end })?.value {
            return cached
        }

        if definition.start.row == definition.end.row {
            let row = definition.start.row
            let lower = min(definition.start.col, definition.end.col)
            let upper = max(definition.start.col, definition.end.col)
            return (lower...upper).map { GridPoint(row: row, col: $0) }
        }

        let col = definition.start.col
        let lower = min(definition.start.row, definition.end.row)
        let upper = max(definition.start.row, definition.end.row)
        return (lower...upper).map { GridPoint(row: $0, col: col) }
    }

    private func movingBlockProgress(for track: [GridPoint], definition: MovingBlockData, now: TimeInterval) -> Double {
        guard track.count > 1 else { return 0 }
        let segmentCount = track.count - 1
        let tileTravelDuration = stepDuration / max(0.35, definition.speedMultiplier)
        let total = Double(segmentCount * 2)
        var progress = ((now - mazeMechanicStartTime) / tileTravelDuration) + definition.phaseOffset
        progress.formTruncatingRemainder(dividingBy: total)
        if progress < 0 {
            progress += total
        }
        if progress <= Double(segmentCount) {
            return progress
        }
        return total - progress
    }

    private func movingBlockInterpolatedPosition(for track: [GridPoint], definition: MovingBlockData, now: TimeInterval) -> CGPoint {
        guard let first = track.first else { return .zero }
        guard track.count > 1 else { return positionFor(first) }

        let progress = movingBlockProgress(for: track, definition: definition, now: now)
        let lowerIndex = max(0, min(track.count - 1, Int(floor(progress))))
        let upperIndex = min(track.count - 1, lowerIndex + 1)
        let blend = CGFloat(progress - Double(lowerIndex))
        let startPosition = positionFor(track[lowerIndex])
        let endPosition = positionFor(track[upperIndex])
        return snap(CGPoint(
            x: startPosition.x + (endPosition.x - startPosition.x) * blend,
            y: startPosition.y + (endPosition.y - startPosition.y) * blend
        ))
    }

    private func movingBlockOccupiedTile(for track: [GridPoint], definition: MovingBlockData, now: TimeInterval) -> GridPoint? {
        guard !track.isEmpty else { return nil }
        let progress = movingBlockProgress(for: track, definition: definition, now: now)
        let index = max(0, min(track.count - 1, Int(progress.rounded())))
        return track[index]
    }

    private func updateMovingBlocks(now: TimeInterval) {
        guard !movingBlockDefinitions.isEmpty else {
            movingBlockOccupiedTiles.removeAll()
            return
        }

        var occupied = Set<GridPoint>()
        for (index, definition) in movingBlockDefinitions.enumerated() {
            let track = movingBlockTracks[index] ?? movingBlockTrack(for: definition)
            movingBlockTracks[index] = track
            if let occupiedTile = movingBlockOccupiedTile(for: track, definition: definition, now: now) {
                occupied.insert(occupiedTile)
            }
            if let node = movingBlockNodes[index] {
                node.position = movingBlockInterpolatedPosition(for: track, definition: definition, now: now)
                updateMovingBlockVisual(node, track: track, definition: definition, now: now)
            }
        }
        movingBlockOccupiedTiles = occupied
    }

    private func updateMovingBlockVisual(_ node: SKNode, track: [GridPoint], definition: MovingBlockData, now: TimeInterval) {
        guard track.count > 1 else { return }
        let progress = movingBlockProgress(for: track, definition: definition, now: now)
        let segmentCount = max(1, track.count - 1)
        let normalized = progress / Double(segmentCount)
        let distanceToEnd = min(normalized, 1.0 - normalized)
        let nearEndpoint = distanceToEnd < 0.085

        if let halo = node.childNode(withName: "halo") as? SKShapeNode {
            halo.run(.group([
                timed(.fadeAlpha(to: nearEndpoint ? 0.34 : 0.24, duration: 0.08), mode: .easeInEaseOut),
                timed(.scale(to: nearEndpoint ? 0.92 : 1.0, duration: 0.08), mode: .easeInEaseOut)
            ]), withKey: "anticipation")
        }
        if let base = node.childNode(withName: "base") as? SKSpriteNode {
            base.run(timed(.scale(to: nearEndpoint ? 0.95 : 1.0, duration: 0.08), mode: .easeInEaseOut), withKey: "anticipation")
        }
    }

    private func chaserPositionFor(_ point: GridPoint) -> CGPoint {
        let base = positionFor(point)
        return snap(CGPoint(x: base.x - tileSize * 0.14, y: base.y - tileSize * 0.14))
    }

    private func setupChaserIfNeeded(texture: SKTexture) {
        guard let chaserSpawn = currentMaze?.chaserSpawn else { return }

        let chaser = SKSpriteNode(texture: texture)
        chaser.size = snapSize(CGSize(width: tileSize * 0.56, height: tileSize * 0.56))
        chaser.color = ArcadeStyle.Color.accentMagenta
        chaser.colorBlendFactor = 0.88
        chaser.alpha = 0.82
        chaser.position = chaserPositionFor(chaserSpawn.spawn)
        chaser.zPosition = 18.5

        let shadow = makeGroundShadow(size: CGSize(width: tileSize * 0.32, height: tileSize * 0.13), alpha: 0.24)
        shadow.position = CGPoint(x: 0, y: -tileSize * 0.14)
        shadow.zPosition = -2
        chaser.addChild(shadow)

        let glow = makeGlowHalo(radius: tileSize * 0.18, color: ArcadeStyle.Color.accentMagenta, alpha: 0.48, glowWidth: 10)
        glow.zPosition = -1
        chaser.addChild(glow)
        glow.run(.repeatForever(.sequence([
            .group([
                .fadeAlpha(to: 0.62, duration: 0.45),
                .scale(to: 1.06, duration: 0.45)
            ]),
            .group([
                .fadeAlpha(to: 0.42, duration: 0.55),
                .scale(to: 1.0, duration: 0.55)
            ])
        ])), withKey: "chaserPulse")

        worldNode.addChild(chaser)
        chaserNode = chaser
        chaserGrid = chaserSpawn.spawn
        playChaserReveal()
    }

    private func playChaserReveal() {
        guard let chaser = chaserNode, !chaserRevealPlayed else { return }
        chaserRevealPlayed = true
        chaser.alpha = 0
        chaser.setScale(0.72)

        let flare = SKShapeNode(circleOfRadius: tileSize * 0.18)
        flare.position = chaser.position
        flare.strokeColor = ArcadeStyle.Color.accentMagenta.withAlphaComponent(0.94)
        flare.lineWidth = 2.2
        flare.glowWidth = 9
        flare.fillColor = ArcadeStyle.Color.accentMagenta.withAlphaComponent(0.08)
        flare.zPosition = 18.4
        worldNode.addChild(flare)
        flare.run(.sequence([
            .group([
                timed(.scale(to: 2.0, duration: 0.22), mode: .easeOut),
                timed(.fadeOut(withDuration: 0.22), mode: .easeOut)
            ]),
            .removeFromParent()
        ]))

        chaser.run(.sequence([
            .group([
                timed(.fadeAlpha(to: 0.96, duration: 0.16), mode: .easeOut),
                timed(.scale(to: 1.05, duration: 0.16), mode: .easeOut)
            ]),
            timed(.scale(to: 1.0, duration: 0.14), mode: .easeInEaseOut)
        ]), withKey: "chaserReveal")
    }

    private func playChaserTargetLockCue() {
        guard let chaser = chaserNode, !chaserTargetLockPlayed else { return }
        chaserTargetLockPlayed = true
        let cue = SKShapeNode(circleOfRadius: tileSize * 0.08)
        cue.position = CGPoint(x: 0, y: tileSize * 0.18)
        cue.strokeColor = ArcadeStyle.Color.accentYellow.withAlphaComponent(0.95)
        cue.lineWidth = 1.8
        cue.glowWidth = 6
        cue.fillColor = .clear
        cue.zPosition = 3
        chaser.addChild(cue)
        cue.run(.sequence([
            .group([
                timed(.scale(to: 2.0, duration: 0.18), mode: .easeOut),
                timed(.fadeOut(withDuration: 0.18), mode: .easeOut)
            ]),
            .removeFromParent()
        ]))
    }

    private func updateChaserThreatFeedback() {
        guard currentMaze?.chaserSpawn != nil else { return }
        let threatDistance = abs(chaserGrid.row - playerGrid.row) + abs(chaserGrid.col - playerGrid.col)
        let nextLevel: Int
        if threatDistance <= 2 {
            nextLevel = 2
        } else if threatDistance <= 4 {
            nextLevel = 1
        } else {
            nextLevel = 0
        }
        guard nextLevel != chaserThreatLevel else { return }
        chaserThreatLevel = nextLevel

        if let timerCard {
            timerCard.removeAction(forKey: "chaserThreat")
            if nextLevel > 0 {
                let targetAlpha: CGFloat = nextLevel == 2 ? 0.24 : 0.14
                timerCard.run(.repeatForever(.sequence([
                    timed(.colorize(with: ArcadeStyle.Color.accentMagenta, colorBlendFactor: targetAlpha, duration: nextLevel == 2 ? 0.22 : 0.35), mode: .easeInEaseOut),
                    timed(.colorize(withColorBlendFactor: 0.0, duration: nextLevel == 2 ? 0.22 : 0.35), mode: .easeInEaseOut)
                ])), withKey: "chaserThreat")
            } else {
                timerCard.run(timed(.colorize(withColorBlendFactor: 0.0, duration: 0.18), mode: .easeOut))
            }
        }

        if let topHudBar {
            topHudBar.removeAction(forKey: "chaserThreat")
            if nextLevel == 2 {
                topHudBar.run(.sequence([
                    timed(.colorize(with: ArcadeStyle.Color.accentMagenta, colorBlendFactor: 0.12, duration: 0.08), mode: .easeOut),
                    timed(.colorize(withColorBlendFactor: 0.0, duration: 0.16), mode: .easeInEaseOut)
                ]), withKey: "chaserThreat")
            }
        }
    }

    private func chaserStepDuration() -> TimeInterval {
        stepDuration / max(0.3, chaserSpeedMultiplier)
    }

    private func currentChaserTarget() -> GridPoint {
        guard chaserBehavior == .delayed else { return playerGrid }
        guard !playerPathHistory.isEmpty else { return playerGrid }
        let delayedIndex = max(0, playerPathHistory.count - 1 - chaserTrailDelaySteps)
        return playerPathHistory[delayedIndex]
    }

    private func chaserCanEnter(_ point: GridPoint) -> Bool {
        guard let tile = tileAt(point) else { return false }
        if tile == "#" { return false }
        if movingBlockOccupiedTiles.contains(point) { return false }
        if tile == "E", exitRequiresKey && !exitIsUnlocked { return false }
        if tile == "X", !switchActivated { return false }
        if tile == "B", !isBreakableDestroyed(at: point) { return false }
        if tile == "G", !gateIsOpen { return false }
        return true
    }

    private func chaserAdvanceOutcome(from point: GridPoint, direction: MoveDirection) -> (destination: GridPoint, usedTeleporter: Bool)? {
        let next = point.moved(by: direction)
        guard chaserCanEnter(next) else { return nil }
        if let teleported = teleporterMap[next] {
            guard chaserCanEnter(teleported) else { return nil }
            return (teleported, true)
        }
        return (next, false)
    }

    private func availableChaserDirections(from point: GridPoint) -> [MoveDirection] {
        if let forced = oneWayDirections[point], chaserAdvanceOutcome(from: point, direction: forced) != nil {
            return [forced]
        }
        return MoveDirection.allCases.filter { chaserAdvanceOutcome(from: point, direction: $0) != nil }
    }

    private func nextChaserDirection(from point: GridPoint) -> MoveDirection? {
        let target = currentChaserTarget()
        guard point != target else { return nil }

        let initialDirections = availableChaserDirections(from: point)
        var queue: [(GridPoint, MoveDirection)] = []
        var visited = Set<GridPoint>([point])
        var index = 0

        for direction in initialDirections {
            guard let outcome = chaserAdvanceOutcome(from: point, direction: direction) else { continue }
            if visited.insert(outcome.destination).inserted {
                queue.append((outcome.destination, direction))
            }
        }

        while index < queue.count {
            let (candidate, firstMove) = queue[index]
            index += 1
            if candidate == target {
                return firstMove
            }
            for direction in availableChaserDirections(from: candidate) {
                guard let outcome = chaserAdvanceOutcome(from: candidate, direction: direction) else { continue }
                if visited.insert(outcome.destination).inserted {
                    queue.append((outcome.destination, firstMove))
                }
            }
        }

        return initialDirections.min { lhs, rhs in
            let lhsPoint = chaserAdvanceOutcome(from: point, direction: lhs)?.destination ?? point
            let rhsPoint = chaserAdvanceOutcome(from: point, direction: rhs)?.destination ?? point
            let lhsDistance = abs(lhsPoint.row - target.row) + abs(lhsPoint.col - target.col)
            let rhsDistance = abs(rhsPoint.row - target.row) + abs(rhsPoint.col - target.col)
            return lhsDistance < rhsDistance
        }
    }

    private func updateChaser(now: TimeInterval) {
        guard currentGameState == .playing, let chaser = chaserNode, !chaserCaughtPlayer else { return }
        guard currentMaze?.chaserSpawn != nil else { return }
        guard !chaserIsMoving else { return }

        if now < chaserStartAt {
            return
        }

        if chaser.alpha < 0.96 {
            chaser.run(.fadeAlpha(to: 0.96, duration: 0.12), withKey: "chaserWake")
        }
        playChaserTargetLockCue()

        guard now >= chaserNextStepTime else { return }

        if chaserCurrentDirection == nil || now >= chaserNextRepathTime {
            chaserCurrentDirection = nextChaserDirection(from: chaserGrid)
            chaserNextRepathTime = now + chaserRepathDelay
        }

        guard let direction = chaserCurrentDirection,
              let outcome = chaserAdvanceOutcome(from: chaserGrid, direction: direction) else {
            chaserCurrentDirection = nil
            chaserNextStepTime = now + 0.08
            return
        }

        chaserIsMoving = true
        chaserNextStepTime = now + chaserStepDuration()
        let destination = chaserPositionFor(outcome.destination)
        let move = SKAction.move(to: destination, duration: chaserStepDuration())
        move.timingMode = .linear
        chaser.run(.sequence([
            move,
            .run { [weak self] in
                self?.handleChaserArrival(at: outcome.destination, usedTeleporter: outcome.usedTeleporter)
            }
        ]), withKey: "chaserStep")
    }

    private func handleChaserArrival(at point: GridPoint, usedTeleporter: Bool) {
        chaserIsMoving = false
        chaserGrid = point
        if usedTeleporter {
            SoundFX.playTeleport(on: self)
            chaserNode?.run(.sequence([
                .scale(to: 0.84, duration: 0.05),
                .scale(to: 1.0, duration: 0.05)
            ]), withKey: "chaserTeleportPulse")
        }
        if point == playerGrid {
            handleChaserCaughtPlayer()
        }
    }

    private func handleChaserCaughtPlayer() {
        guard currentGameState == .playing,
              !chaserCaughtPlayer,
              chaserNode != nil,
              currentMaze?.chaserSpawn != nil else { return }
        chaserCaughtPlayer = true
        playerNode?.removeAllActions()
        botNode?.removeAllActions()
        chaserNode?.removeAllActions()
        cameraNode.removeAllActions()
        stopSliding(reason: .manual)
        SoundFX.playBlocked(on: self)
        playerNode?.run(.sequence([
            .group([
                timed(.fadeAlpha(to: 0.38, duration: 0.08), mode: .easeOut),
                timed(.scale(to: 0.82, duration: 0.08), mode: .easeOut)
            ]),
            .group([
                timed(.fadeAlpha(to: 1.0, duration: 0.12), mode: .easeOut),
                timed(.scale(to: 1.0, duration: 0.12), mode: .easeOut)
            ])
        ]), withKey: "chaserCatchFlash")
        if let playerPosition = playerNode?.position {
            let burst = SKShapeNode(circleOfRadius: tileSize * 0.16)
            burst.position = playerPosition
            burst.strokeColor = ArcadeStyle.Color.accentMagenta.withAlphaComponent(0.95)
            burst.lineWidth = 2.6
            burst.glowWidth = 9
            burst.fillColor = ArcadeStyle.Color.accentMagenta.withAlphaComponent(0.08)
            burst.zPosition = 26
            worldNode.addChild(burst)
            burst.run(.sequence([
                .group([
                    timed(.scale(to: 2.2, duration: 0.18), mode: .easeOut),
                    timed(.fadeOut(withDuration: 0.18), mode: .easeOut)
                ]),
                .removeFromParent()
            ]))
        }

        if isChallengeMode {
            finishChallengeRun()
            return
        }

        setGameState(.levelCompleted)
        applyGameplayCameraScale()
        showResultOverlay(
            stars: nil,
            headline: "CAUGHT!",
            timeText: "Your Time: \(formattedClockTime(displayedElapsedTime()))",
            detailLines: ["The chaser reached you. Keep more distance and read the route earlier."],
            nextEnabled: false
        )
    }

    private func updateBreakableVisual(at point: GridPoint, animated: Bool) {
        guard let node = breakableNodes[point] else { return }
        let hits = breakableHits[point] ?? 0
        let destroyed = hits >= 3
        let damageProgress = CGFloat(min(3, hits)) / 3.0

        if let base = node.childNode(withName: "base") as? SKSpriteNode {
            base.color = destroyed
                ? ArcadeStyle.Color.accentCyan
                : SKColor(
                    red: 1.0,
                    green: 0.84 - damageProgress * 0.28,
                    blue: 0.22,
                    alpha: 1.0
                )
            base.colorBlendFactor = destroyed ? 0.18 : 0.42 + damageProgress * 0.16
            base.alpha = destroyed ? 0.12 : 0.94
        }
        if let halo = node.childNode(withName: "halo") as? SKShapeNode {
            let haloColor = destroyed ? ArcadeStyle.Color.accentCyan : ArcadeStyle.Color.accentYellow
            halo.fillColor = haloColor.withAlphaComponent(destroyed ? 0.03 : 0.10 + damageProgress * 0.06)
            halo.strokeColor = haloColor.withAlphaComponent(destroyed ? 0.06 : 0.16 + damageProgress * 0.08)
            halo.alpha = destroyed ? 0.12 : 0.22 + damageProgress * 0.12
        }
        if let panel = node.childNode(withName: "panel") as? SKShapeNode {
            panel.fillColor = destroyed
                ? SKColor(red: 0.06, green: 0.12, blue: 0.15, alpha: 0.55)
                : SKColor(
                    red: 0.22 + damageProgress * 0.10,
                    green: 0.16 - damageProgress * 0.04,
                    blue: 0.08,
                    alpha: 0.94
                )
            panel.strokeColor = destroyed
                ? ArcadeStyle.Color.accentCyan.withAlphaComponent(0.18)
                : SKColor(red: 1.0, green: 0.82, blue: 0.38, alpha: 0.26 + damageProgress * 0.18)
        }
        if let frame = node.childNode(withName: "frame") as? SKShapeNode {
            frame.strokeColor = destroyed
                ? ArcadeStyle.Color.accentCyan.withAlphaComponent(0.5)
                : SKColor(red: 1.0, green: 0.9 - damageProgress * 0.14, blue: 0.3, alpha: 0.95)
            frame.alpha = destroyed ? 0.45 : 1.0
            frame.glowWidth = destroyed ? 1.5 : 2.5 + damageProgress * 1.5
        }
        for braceName in ["brace_left", "brace_right"] {
            if let brace = node.childNode(withName: braceName) as? SKShapeNode {
                brace.alpha = destroyed ? 0.12 : 0.34 - damageProgress * 0.12
            }
        }

        for index in 0..<3 {
            if let pip = node.childNode(withName: "hp_\(index)") as? SKShapeNode {
                pip.alpha = index < (3 - min(3, hits)) ? 1.0 : 0.18
            }
            if let crack = node.childNode(withName: "crack_\(index + 1)") as? SKShapeNode {
                crack.alpha = hits > index ? (destroyed ? 0.12 : 0.9) : 0.0
            }
        }

        if animated {
            node.removeAction(forKey: "breakablePulse")
            node.run(.sequence([
                .scale(to: destroyed ? 1.06 : 0.95, duration: 0.05),
                .scale(to: destroyed ? 0.88 : 1.0, duration: destroyed ? 0.18 : 0.14)
            ]), withKey: "breakablePulse")
        } else {
            node.setScale(destroyed ? 0.88 : 1.0)
        }
    }

    private func updateAllBreakableVisuals(animated: Bool) {
        for point in orderedBreakablePoints {
            updateBreakableVisual(at: point, animated: animated)
        }
    }

    @discardableResult
    private func registerBreakableHit(at point: GridPoint, triggeredByBot: Bool) -> Bool {
        guard canHitBreakable(at: point) else { return false }
        let nextHits = min(3, (breakableHits[point] ?? 0) + 1)
        breakableHits[point] = nextHits
        updateBreakableVisual(at: point, animated: false)
        animateBreakableImpact(at: point, hitCount: nextHits)
        if nextHits >= 3 {
            SoundFX.playUnlock(on: self)
        } else if !triggeredByBot {
            SoundFX.playBlocked(on: self)
        }
        invalidateHardBotDirectionCacheForDynamicStateChange()
        return true
    }

    private func animateBreakableImpact(at point: GridPoint, hitCount: Int) {
        guard let node = breakableNodes[point] else { return }
        let destroyed = hitCount >= 3
        let worldPosition = node.position
        let intensity = min(1.0, CGFloat(hitCount) / 3.0)

        let squashX: CGFloat
        let squashY: CGFloat
        let overshoot: CGFloat
        let shakeDistance: CGFloat
        let ringScale: CGFloat
        let ringDuration: TimeInterval
        let shardCount: Int
        let shardDistance: CGFloat
        let shardSize = CGSize(width: destroyed ? 12 : (hitCount == 2 ? 9 : 7), height: destroyed ? 4 : 3)
        let effectColor: SKColor

        switch hitCount {
        case 1:
            squashX = 1.03
            squashY = 0.90
            overshoot = 1.01
            shakeDistance = tileSize * 0.05
            ringScale = 1.22
            ringDuration = 0.14
            shardCount = 4
            shardDistance = tileSize * 0.22
            effectColor = ArcadeStyle.Color.accentYellow
        case 2:
            squashX = 1.05
            squashY = 0.84
            overshoot = 1.03
            shakeDistance = tileSize * 0.09
            ringScale = 1.42
            ringDuration = 0.18
            shardCount = 7
            shardDistance = tileSize * 0.32
            effectColor = SKColor(red: 1.0, green: 0.72, blue: 0.24, alpha: 1.0)
        default:
            squashX = 1.08
            squashY = 0.78
            overshoot = 1.06
            shakeDistance = tileSize * 0.12
            ringScale = 1.82
            ringDuration = 0.26
            shardCount = 10
            shardDistance = tileSize * 0.50
            effectColor = SKColor(red: 1.0, green: 0.82, blue: 0.36, alpha: 1.0)
        }

        if let halo = node.childNode(withName: "halo") as? SKShapeNode {
            halo.removeAction(forKey: "breakableHaloPulse")
            halo.run(.sequence([
                .group([
                    .fadeAlpha(to: destroyed ? 0.54 : 0.28 + intensity * 0.2, duration: 0.05),
                    .scale(to: destroyed ? 1.24 : 1.04 + intensity * 0.12, duration: 0.05)
                ]),
                .group([
                    .fadeAlpha(to: destroyed ? 0.10 : 0.16 + intensity * 0.06, duration: destroyed ? 0.30 : 0.16),
                    .scale(to: 1.0, duration: destroyed ? 0.30 : 0.16)
                ])
            ]), withKey: "breakableHaloPulse")
        }

        node.removeAction(forKey: "breakableImpact")
        let settle = SKAction.run {
            node.xScale = destroyed ? 0.84 : 1.0
            node.yScale = destroyed ? 0.84 : 1.0
            node.position = self.snap(worldPosition)
            node.zRotation = 0
        }
        let impactSequence: [SKAction]
        if hitCount == 2 {
            impactSequence = [
                .group([
                    timed(.scaleX(to: squashX, duration: 0.05), mode: .easeOut),
                    timed(.scaleY(to: squashY, duration: 0.05), mode: .easeOut),
                    timed(.moveBy(x: -shakeDistance, y: 0, duration: 0.05), mode: .easeOut),
                    timed(.rotate(toAngle: -0.045, duration: 0.05), mode: .easeOut)
                ]),
                .group([
                    timed(.scaleX(to: 0.94, duration: 0.04), mode: .easeInEaseOut),
                    timed(.scaleY(to: 1.04, duration: 0.04), mode: .easeInEaseOut),
                    timed(.moveBy(x: shakeDistance * 2.0, y: 0, duration: 0.04), mode: .easeInEaseOut),
                    timed(.rotate(toAngle: 0.038, duration: 0.04), mode: .easeInEaseOut)
                ]),
                .group([
                    timed(.scaleX(to: overshoot, duration: 0.07), mode: .easeOut),
                    timed(.scaleY(to: 0.98, duration: 0.07), mode: .easeOut),
                    timed(.move(to: worldPosition, duration: 0.07), mode: .easeOut),
                    timed(.rotate(toAngle: 0.0, duration: 0.07), mode: .easeOut)
                ]),
                settle
            ]
        } else {
            impactSequence = [
                .group([
                    timed(.scaleX(to: squashX, duration: 0.05), mode: .easeOut),
                    timed(.scaleY(to: squashY, duration: 0.05), mode: .easeOut)
                ]),
                .group([
                    timed(.scaleX(to: overshoot, duration: destroyed ? 0.09 : 0.06), mode: .easeOut),
                    timed(.scaleY(to: destroyed ? 0.88 : 0.98, duration: destroyed ? 0.09 : 0.06), mode: .easeOut)
                ]),
                settle
            ]
        }
        node.run(.sequence(impactSequence), withKey: "breakableImpact")

        let ring = SKShapeNode(rectOf: snapSize(CGSize(width: tileSize * 0.56, height: tileSize * 0.56)), cornerRadius: 7)
        ring.position = worldPosition
        ring.strokeColor = effectColor.withAlphaComponent(0.94)
        ring.lineWidth = destroyed ? 2.6 : (hitCount == 2 ? 2.2 : 1.6)
        ring.glowWidth = destroyed ? 6 : (hitCount == 2 ? 4 : 2.5)
        ring.fillColor = .clear
        ring.zPosition = 22
        worldNode.addChild(ring)
        ring.run(.sequence([
            .group([
                timed(.scale(to: ringScale, duration: ringDuration), mode: .easeOut),
                timed(.fadeOut(withDuration: ringDuration), mode: .easeOut)
            ]),
            .removeFromParent()
        ]))

        for index in 0..<shardCount {
            let shard = SKSpriteNode(color: effectColor.withAlphaComponent(destroyed ? 0.96 : 0.78 + intensity * 0.12), size: shardSize)
            shard.position = worldPosition
            shard.zPosition = 23
            shard.blendMode = .add
            worldNode.addChild(shard)
            let angle = CGFloat(index) / CGFloat(shardCount) * .pi * 2
            let wobble = CGFloat((index % 2 == 0 ? 1 : -1)) * 0.12
            let target = CGPoint(
                x: worldPosition.x + cos(angle + wobble) * shardDistance,
                y: worldPosition.y + sin(angle + wobble) * shardDistance
            )
            shard.zRotation = angle
            shard.run(.sequence([
                .group([
                    timed(.move(to: target, duration: ringDuration), mode: .easeOut),
                    timed(.fadeOut(withDuration: ringDuration), mode: .easeOut),
                    timed(.scale(to: destroyed ? 0.12 : 0.2, duration: ringDuration), mode: .easeOut)
                ]),
                .removeFromParent()
            ]))
        }

        if hitCount >= 2 {
            let dust = SKShapeNode(circleOfRadius: destroyed ? tileSize * 0.2 : tileSize * 0.14)
            dust.position = worldPosition
            dust.fillColor = SKColor(red: 0.16, green: 0.11, blue: 0.06, alpha: destroyed ? 0.32 : 0.22)
            dust.strokeColor = .clear
            dust.zPosition = 21
            worldNode.addChild(dust)
            dust.run(.sequence([
                .group([
                    timed(.scale(to: destroyed ? 1.9 : 1.45, duration: destroyed ? 0.28 : 0.18), mode: .easeOut),
                    timed(.fadeOut(withDuration: destroyed ? 0.28 : 0.18), mode: .easeOut)
                ]),
                .removeFromParent()
            ]))
        }
    }

    private func toggleSwitchIfNeeded(at point: GridPoint) {
        guard switchNodes[point] != nil else { return }
        switchActivated.toggle()
        SoundFX.playStateChange(on: self, enabled: switchActivated)
        updateSwitchTriggerVisuals(animated: true)
        updateSwitchBlockVisuals(animated: true)
        animateSwitchSignal(from: point)
        // Avoid full-state hard-bot prewarming here. A switch only flips one boolean,
        // so invalidating the cache and letting the next route query rebuild lazily
        // removes the visible hitch on toggle without changing pathing semantics.
        invalidateHardBotDirectionCacheForDynamicStateChange()
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
        formattedTime(time)
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

    private func currentChallengeTimeLimit() -> TimeInterval? {
        guard let challengeDuration else { return nil }
        return challengeDuration.seconds + challengeBonusTime
    }

    private func updateTimerLabel() {
        let text: String
        if let challengeLimit = currentChallengeTimeLimit() {
            let remaining = max(0, challengeLimit - displayedElapsedTime())
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
        let point = GridPoint(row: row, col: col)
        guard let tile = tileAt(point) else { return false }
        if tile == "#" { return false }
        if movingBlockOccupiedTiles.contains(point) { return false }
        if tile == "E" && exitRequiresKey && !exitIsUnlocked { return false }
        if tile == "X" && !switchActivated { return false }
        if tile == "B" && !isBreakableDestroyed(at: point) { return false }
        if tile == "G" && !gateIsOpen { return false }
        return true
    }

    private func canAttemptMove(into point: GridPoint) -> Bool {
        if isWalkable(point.row, point.col) {
            return true
        }
        return canHitBreakable(at: point)
    }

    private func tileAt(_ point: GridPoint) -> Character? {
        currentMaze?.tile(at: point)
    }

    private func canHitBreakable(at point: GridPoint) -> Bool {
        guard tileAt(point) == "B" else { return false }
        return (breakableHits[point] ?? 0) < 3
    }

    private func isBreakableDestroyed(at point: GridPoint) -> Bool {
        (breakableHits[point] ?? 0) >= 3
    }

    private func breakHitsVector() -> [UInt8] {
        orderedBreakablePoints.map { UInt8(min(3, breakableHits[$0] ?? 0)) }
    }

    private func routeHintCanTraverse(_ point: GridPoint) -> Bool {
        guard let tile = tileAt(point) else { return false }
        if tile == "#" { return false }
        if tile == "X" && !switchActivated { return false }
        if tile == "B" && !isBreakableDestroyed(at: point) { return false }
        if tile == "G" && !gateIsOpen { return false }
        return true
    }

    private func routeHintAdvance(from point: GridPoint, direction: MoveDirection) -> RouteHintStep? {
        let next = point.moved(by: direction)
        guard routeHintCanTraverse(next) else { return nil }
        if let teleported = teleporterMap[next], routeHintCanTraverse(teleported) {
            return RouteHintStep(destination: teleported, touchedPoints: [next, teleported])
        }
        return RouteHintStep(destination: next, touchedPoints: [next])
    }

    private func routeHintDirections(from point: GridPoint) -> [MoveDirection] {
        if let forced = oneWayDirections[point], routeHintAdvance(from: point, direction: forced) != nil {
            return [forced]
        }
        return MoveDirection.allCases.filter { routeHintAdvance(from: point, direction: $0) != nil }
    }

    private func shortestRouteHintPath(from start: GridPoint, to goal: GridPoint) -> [GridPoint]? {
        guard start != goal else { return [start] }

        var queue: [GridPoint] = [start]
        var visited = Set<GridPoint>([start])
        var previous: [GridPoint: GridPoint] = [:]
        var index = 0

        while index < queue.count {
            let point = queue[index]
            index += 1

            for direction in routeHintDirections(from: point) {
                guard let step = routeHintAdvance(from: point, direction: direction) else { continue }
                if visited.insert(step.destination).inserted {
                    previous[step.destination] = point
                    if step.destination == goal {
                        var path: [GridPoint] = [goal]
                        var cursor = goal
                        while let parent = previous[cursor] {
                            path.append(parent)
                            cursor = parent
                        }
                        return path.reversed()
                    }
                    queue.append(step.destination)
                }
            }
        }

        return nil
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
        return canAttemptMove(into: next)
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
        dismissSwipeHintIfNeeded(markShown: !isChallengeMode)
        if currentGameState == .idle {
            if isChallengeMode, runStartTime == nil {
                mazeMechanicStartTime = now
                chaserStartAt = now + chaserStartDelay
                chaserNextStepTime = chaserStartAt
                chaserNextRepathTime = chaserStartAt
                updateMovingBlocks(now: now)
            }
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
            if registerBreakableHit(at: next, triggeredByBot: false) {
                stopSliding(reason: .breakableHit)
                return
            }
            let tile = tileAt(next)
            if movingBlockOccupiedTiles.contains(next) {
                SoundFX.playBlocked(on: self)
                stopSliding(reason: .manual)
            } else if tile == "E" && exitRequiresKey && !exitIsUnlocked {
                pulseLockedExit()
                stopSliding(reason: .manual)
            } else if tile == "G" {
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
        playerPathHistory.append(landing.point)
        if playerPathHistory.count > 160 {
            playerPathHistory.removeFirst(playerPathHistory.count - 160)
        }
        if chaserNode != nil, currentMaze?.chaserSpawn != nil, landing.point == chaserGrid {
            handleChaserCaughtPlayer()
            return
        }
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
        let scaleUp: CGFloat = style == .pulseTrail || style == .energyBurst || style == .phaseStream ? 1.18 : 1.05
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
        guard style == .classicNeon || style == .electricSparks || style == .pixelTrail || style == .pulseTrail || style == .energyBurst || style == .orbitTrail || style == .smoothLight || style == .phaseStream else { return }
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
        case breakableHit
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

        toggleSwitchIfNeeded(at: currentPoint)

        if let keyNode = keyNodes.removeValue(forKey: currentPoint) {
            keyCount += 1
            SoundFX.playUnlock(on: self)
            let keyOrigin = keyNode.position
            attachCollectedKeyFollower(from: keyNode)
            updateExitLockVisuals(animated: true)
            if let exitMarkerNode {
                spawnKeyUnlockLink(from: keyOrigin, to: exitMarkerNode.position)
            }
            showRouteHintToExit(from: currentPoint, duration: 2.5)
            invalidateHardBotDirectionCacheForDynamicStateChange()
        }

        if let bonusNode = timeBonusNodes.removeValue(forKey: currentPoint) {
            grantChallengeTimeBonus(from: bonusNode, at: currentPoint)
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

        toggleSwitchIfNeeded(at: currentPoint)

        if let keyNode = keyNodes.removeValue(forKey: currentPoint) {
            keyCount += 1
            keyNode.removeFromParent()
            keyFollowerNode?.removeFromParent()
            keyFollowerNode = nil
            updateExitLockVisuals(animated: true)
            invalidateHardBotDirectionCacheForDynamicStateChange()
        }

        botGrid = currentPoint
        if currentPoint == currentMaze?.exit {
            finishBotRace(winner: .bot)
            return BotLandingResult(point: currentPoint, forcedDirection: forced, reachedExit: true)
        }

        return BotLandingResult(point: currentPoint, forcedDirection: forced, reachedExit: false)
    }

    private func teleportPlayer(to point: GridPoint) {
        let source = playerNode?.position ?? positionFor(playerGrid)
        playerGrid = point
        let destination = positionFor(point)
        SoundFX.playTeleport(on: self)
        spawnTeleportWarp(at: source, color: currentTheme.palette.accentPink, scale: 1.0)
        playerNode?.position = destination
        playerNode?.run(.sequence([
            .group([
                .scale(to: 0.74, duration: 0.05),
                .fadeAlpha(to: 0.52, duration: 0.05)
            ]),
            .group([
                .scale(to: 1.04, duration: 0.06),
                .fadeAlpha(to: 1.0, duration: 0.06)
            ]),
            .scale(to: 1.0, duration: 0.08)
        ]))
        spawnTeleportWarp(at: destination, color: currentTheme.palette.accentCyan, scale: 1.05)
        updateCameraPosition(animated: false, targetWorldPosition: destination)
    }

    private func teleportBot(to point: GridPoint) {
        let source = botNode?.position ?? botPositionFor(botGrid)
        botGrid = point
        let destination = botPositionFor(point)
        SoundFX.playTeleport(on: self)
        spawnTeleportWarp(at: source, color: ArcadeStyle.Color.accentMagenta, scale: 0.9)
        botNode?.position = destination
        botNode?.run(.sequence([
            .group([
                .scale(to: 0.72, duration: 0.05),
                .fadeAlpha(to: 0.55, duration: 0.05)
            ]),
            .group([
                .scale(to: 1.03, duration: 0.06),
                .fadeAlpha(to: 1.0, duration: 0.06)
            ]),
            .scale(to: 1.0, duration: 0.08)
        ]))
        spawnTeleportWarp(at: destination, color: ArcadeStyle.Color.accentCyan, scale: 0.92)
    }

    private func collectOrb(at position: CGPoint) {
        score += 10
        if !isChallengeMode {
            CoinStore.shared.add(1)
            updateCoinHud()
        }
        spawnOrbCollectBurst(at: position)
        let popSize = snapSize(CGSize(width: tileSize * 0.4, height: tileSize * 0.4))
        let pop = SKSpriteNode(texture: TextureFactory.shared.orbTexture(size: popSize))
        pop.position = position
        pop.alpha = 0.78
        pop.zPosition = 25
        pop.blendMode = .add
        worldNode.addChild(pop)
        pop.run(.sequence([
            .group([
                .fadeOut(withDuration: 0.22),
                .scale(to: 1.26, duration: 0.22)
            ]),
            .removeFromParent()
        ]))
    }

    private func challengeTimeBonusPerPickup() -> TimeInterval {
        guard let duration = challengeDuration else { return 0 }
        switch duration {
        case .oneMinute:
            return 5
        case .twoMinutes:
            return 6
        case .threeMinutes:
            return 7
        }
    }

    private func grantChallengeTimeBonus(from node: SKNode, at point: GridPoint) {
        let bonusSeconds = challengeTimeBonusPerPickup()
        guard bonusSeconds > 0 else { return }

        challengeBonusTime += bonusSeconds
        SoundFX.playReward(on: self)

        let pickupPosition = node.position
        node.removeFromParent()
        spawnTimeBonusPickupBurst(at: pickupPosition)
        showChallengeTimeBonusFeedback(at: pickupPosition, seconds: bonusSeconds)
        updateTimerLabel()
        pulseChallengeTimerBonus()

        if point == playerGrid {
            updateCameraPosition(animated: false)
        }
    }

    private func showChallengeTimeBonusFeedback(at position: CGPoint, seconds: TimeInterval) {
        let worldLabel = SKLabelNode(fontNamed: ArcadeFont.digits)
        worldLabel.text = String(format: "TIME +%.0fs", seconds)
        worldLabel.fontSize = 22
        worldLabel.fontColor = ArcadeStyle.Color.accentYellow
        worldLabel.alpha = 0
        worldLabel.zPosition = 30
        worldLabel.position = snap(position)
        let worldShadow = SKLabelNode(fontNamed: ArcadeFont.digits)
        worldShadow.text = worldLabel.text
        worldShadow.fontSize = worldLabel.fontSize
        worldShadow.fontColor = .black
        worldShadow.alpha = 0.34
        worldShadow.position = snap(CGPoint(x: 1, y: -1))
        worldShadow.zPosition = 29
        worldLabel.addChild(worldShadow)
        worldNode.addChild(worldLabel)

        worldLabel.run(.sequence([
            .group([
                .fadeIn(withDuration: 0.04),
                .scale(to: 1.08, duration: 0.08)
            ]),
            .group([
                timed(.moveBy(x: 0, y: tileSize * 0.56, duration: 0.7), mode: .easeOut),
                timed(.fadeOut(withDuration: 0.7), mode: .easeOut),
                timed(.scale(to: 1.0, duration: 0.7), mode: .easeOut)
            ]),
            .removeFromParent()
        ]))

        guard let timerCard else { return }
        let chip = SKSpriteNode(texture: TextureFactory.shared.cardTexture(size: snapSize(CGSize(width: 92, height: 28)), style: .shellFeature))
        chip.size = snapSize(CGSize(width: 92, height: 28))
        chip.alpha = 0
        chip.zPosition = 219
        chip.position = snap(CGPoint(
            x: timerCard.position.x + timerCard.size.width / 2 - 42,
            y: timerCard.position.y + timerCard.size.height / 2 + 14
        ))
        hudNode.addChild(chip)

        let hudLabel = SKLabelNode(fontNamed: ArcadeFont.digits)
        hudLabel.text = String(format: "+%.0fs", seconds)
        hudLabel.fontSize = 14
        hudLabel.fontColor = ArcadeStyle.Color.accentYellow
        hudLabel.verticalAlignmentMode = .center
        hudLabel.position = snap(CGPoint(x: 0, y: -1))
        hudLabel.zPosition = 220
        chip.addChild(hudLabel)

        chip.run(.sequence([
            .group([
                timed(.fadeIn(withDuration: 0.05), mode: .easeOut),
                timed(.scale(to: 1.05, duration: 0.08), mode: .easeOut)
            ]),
            .group([
                timed(.moveBy(x: 0, y: 15, duration: 0.7), mode: .easeOut),
                timed(.fadeOut(withDuration: 0.7), mode: .easeOut),
                timed(.scale(to: 1.0, duration: 0.7), mode: .easeOut)
            ]),
            .removeFromParent()
        ]))
    }

    private func pulseChallengeTimerBonus() {
        guard let timerCard else { return }
        timerCard.removeAction(forKey: "timeBonusPulse")
        timerCard.run(.sequence([
            .group([
                timed(.scale(to: 1.065, duration: 0.08), mode: .easeOut),
                timed(.colorize(with: ArcadeStyle.Color.accentYellow, colorBlendFactor: 0.32, duration: 0.08), mode: .easeOut)
            ]),
            .group([
                timed(.moveBy(x: -2, y: 0, duration: 0.03), mode: .easeOut),
                timed(.scale(to: 1.02, duration: 0.03), mode: .easeOut)
            ]),
            .group([
                timed(.moveBy(x: 4, y: 0, duration: 0.05), mode: .easeOut),
                timed(.scale(to: 1.04, duration: 0.05), mode: .easeOut)
            ]),
            .group([
                timed(.moveBy(x: -2, y: 0, duration: 0.04), mode: .easeOut),
                timed(.scale(to: 1.0, duration: 0.18), mode: .easeOut),
                timed(.colorize(withColorBlendFactor: 0.0, duration: 0.18), mode: .easeOut)
            ])
        ]), withKey: "timeBonusPulse")
    }

    private func spawnTimeBonusPickupBurst(at position: CGPoint) {
        let ring = SKShapeNode(circleOfRadius: tileSize * 0.16)
        ring.lineWidth = 2.4
        ring.strokeColor = ArcadeStyle.Color.accentYellow
        ring.glowWidth = 7
        ring.fillColor = .clear
        ring.position = position
        ring.alpha = 0.92
        ring.zPosition = 26
        worldNode.addChild(ring)

        ring.run(.sequence([
            .group([
                timed(.scale(to: 2.8, duration: 0.28), mode: .easeOut),
                timed(.fadeOut(withDuration: 0.28), mode: .easeOut)
            ]),
            .removeFromParent()
        ]))

        let flash = SKShapeNode(circleOfRadius: tileSize * 0.18)
        flash.fillColor = ArcadeStyle.Color.accentYellow.withAlphaComponent(0.92)
        flash.strokeColor = .clear
        flash.glowWidth = 10
        flash.position = position
        flash.alpha = 0.0
        flash.zPosition = 25.5
        worldNode.addChild(flash)
        flash.run(.sequence([
            .group([
                timed(.fadeAlpha(to: 0.8, duration: 0.04), mode: .easeOut),
                timed(.scale(to: 0.9, duration: 0.04), mode: .easeOut)
            ]),
            .group([
                timed(.fadeOut(withDuration: 0.2), mode: .easeOut),
                timed(.scale(to: 1.35, duration: 0.2), mode: .easeOut)
            ]),
            .removeFromParent()
        ]))
    }

    private func runLevelStartEntrance(startMarker: SKSpriteNode, exitMarker: SKSpriteNode) {
        let hudEntrants: [SKNode] = [topHudBar, starsCard, centerHudPanel, timerCard, pauseButton, coinChipNode].compactMap { $0 }
        for (index, node) in hudEntrants.enumerated() {
            animateEntrance(node, delay: Double(index) * 0.03, offsetY: 10, scaleFrom: 0.985)
        }

        let worldEntrants: [SKNode] = [startMarker, exitMarker, playerNode].compactMap { $0 }
        for (index, node) in worldEntrants.enumerated() {
            animateEntrance(node, delay: 0.04 + Double(index) * 0.04, offsetY: 8, scaleFrom: 0.92)
        }
    }

    private func animateEntrance(_ node: SKNode, delay: TimeInterval, offsetY: CGFloat, scaleFrom: CGFloat) {
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
        ]), withKey: "entrance")
    }

    private func spawnOrbCollectBurst(at position: CGPoint) {
        let ring = SKShapeNode(circleOfRadius: tileSize * 0.14)
        ring.position = position
        ring.strokeColor = ArcadeStyle.Color.accentYellow
        ring.lineWidth = 2
        ring.glowWidth = 4
        ring.fillColor = .clear
        ring.zPosition = 24
        worldNode.addChild(ring)
        ring.run(.sequence([
            .group([
                timed(.scale(to: 2.0, duration: 0.22), mode: .easeOut),
                timed(.fadeOut(withDuration: 0.22), mode: .easeOut)
            ]),
            .removeFromParent()
        ]))

        for index in 0..<6 {
            let particle = SKSpriteNode(texture: TextureFactory.shared.trailParticleTexture(size: CGSize(width: 8, height: 8), style: .classicNeon))
            particle.position = position
            particle.alpha = 0.95
            particle.zPosition = 25
            particle.blendMode = .add
            worldNode.addChild(particle)
            let angle = CGFloat(index) / 6 * .pi * 2
            let distance = tileSize * 0.34
            let target = CGPoint(x: position.x + cos(angle) * distance, y: position.y + sin(angle) * distance)
            particle.run(.sequence([
                .group([
                    timed(.move(to: target, duration: 0.24), mode: .easeOut),
                    timed(.fadeOut(withDuration: 0.24), mode: .easeOut),
                    timed(.scale(to: 0.2, duration: 0.24), mode: .easeOut)
                ]),
                .removeFromParent()
            ]))
        }
    }

    private func spawnTeleportWarp(at position: CGPoint, color: SKColor, scale: CGFloat) {
        let ring = SKShapeNode(circleOfRadius: tileSize * 0.16 * scale)
        ring.position = position
        ring.strokeColor = color.withAlphaComponent(0.95)
        ring.lineWidth = 2.5
        ring.glowWidth = 6
        ring.fillColor = color.withAlphaComponent(0.05)
        ring.zPosition = 26
        worldNode.addChild(ring)
        ring.run(.sequence([
            .group([
                timed(.scale(to: 2.1, duration: 0.18), mode: .easeOut),
                timed(.fadeOut(withDuration: 0.18), mode: .easeOut)
            ]),
            .removeFromParent()
        ]))

        let flash = SKSpriteNode(color: color.withAlphaComponent(0.18), size: CGSize(width: tileSize * 0.9, height: tileSize * 0.9))
        flash.position = position
        flash.blendMode = .add
        flash.zPosition = 25
        worldNode.addChild(flash)
        flash.run(.sequence([
            .group([
                timed(.fadeOut(withDuration: 0.16), mode: .easeOut),
                timed(.scale(to: 1.3, duration: 0.16), mode: .easeOut)
            ]),
            .removeFromParent()
        ]))
    }

    private func spawnExitActivationWave(unlocked: Bool) {
        guard let exitMarkerNode else { return }
        let color = unlocked ? ArcadeStyle.Color.accentGreen : SKColor(red: 1.0, green: 0.45, blue: 0.3, alpha: 1.0)
        let ring = SKShapeNode(circleOfRadius: tileSize * 0.18)
        ring.position = exitMarkerNode.position
        ring.strokeColor = color.withAlphaComponent(0.95)
        ring.lineWidth = 2.2
        ring.glowWidth = 7
        ring.fillColor = .clear
        ring.zPosition = 7
        worldNode.addChild(ring)
        ring.run(.sequence([
            .group([
                timed(.scale(to: unlocked ? 2.4 : 1.7, duration: unlocked ? 0.24 : 0.18), mode: .easeOut),
                timed(.fadeOut(withDuration: unlocked ? 0.24 : 0.18), mode: .easeOut)
            ]),
            .removeFromParent()
        ]))
    }

    private func animateSwitchSignal(from point: GridPoint) {
        guard let originNode = switchNodes[point] else { return }
        originNode.run(.sequence([
            .group([
                timed(.scale(to: 1.08, duration: 0.08), mode: .easeOut),
                timed(.fadeAlpha(to: 1.0, duration: 0.08), mode: .easeOut)
            ]),
            timed(.scale(to: 1.0, duration: 0.14), mode: .easeInEaseOut)
        ]), withKey: "switchPress")

        let origin = originNode.position
        for (index, point) in orderedSwitchBlockPoints.enumerated() {
            guard let blockNode = switchBlockNodes[point] else { continue }
            let destination = blockNode.position
            let path = CGMutablePath()
            path.move(to: origin)
            let control = CGPoint(x: (origin.x + destination.x) * 0.5, y: max(origin.y, destination.y) + tileSize * 0.18)
            path.addQuadCurve(to: destination, control: control)
            let beam = SKShapeNode(path: path)
            beam.strokeColor = (switchActivated ? ArcadeStyle.Color.accentYellow : ArcadeStyle.Color.accentMagenta).withAlphaComponent(0.62)
            beam.lineWidth = 2.0
            beam.glowWidth = 5
            beam.alpha = 0
            beam.zPosition = 23
            worldNode.addChild(beam)
            beam.run(.sequence([
                .wait(forDuration: Double(index) * 0.03),
                .fadeAlpha(to: 0.92, duration: 0.06),
                .fadeOut(withDuration: 0.16),
                .removeFromParent()
            ]))

            let pulse = SKSpriteNode(color: switchActivated ? ArcadeStyle.Color.accentCyan : ArcadeStyle.Color.accentMagenta, size: CGSize(width: 8, height: 8))
            pulse.position = origin
            pulse.alpha = 0.88
            pulse.zPosition = 24
            pulse.blendMode = .add
            worldNode.addChild(pulse)

            pulse.run(.sequence([
                .wait(forDuration: Double(index) * 0.03),
                .group([
                    timed(.move(to: destination, duration: 0.18), mode: .easeInEaseOut),
                    timed(.fadeOut(withDuration: 0.18), mode: .easeInEaseOut),
                    timed(.scale(to: 0.22, duration: 0.18), mode: .easeInEaseOut)
                ]),
                .removeFromParent()
            ]))

            blockNode.run(.sequence([
                .wait(forDuration: 0.14 + Double(index) * 0.03),
                .group([
                    timed(.scale(to: 1.06, duration: 0.08), mode: .easeOut),
                    timed(.fadeAlpha(to: 1.0, duration: 0.08), mode: .easeOut)
                ]),
                timed(.scale(to: 1.0, duration: 0.16), mode: .easeInEaseOut)
            ]), withKey: "switchSignalPulse")
        }
    }

    private func spawnKeyUnlockLink(from source: CGPoint, to destination: CGPoint) {
        let path = CGMutablePath()
        path.move(to: source)
        let control = CGPoint(x: (source.x + destination.x) * 0.5, y: max(source.y, destination.y) + tileSize * 0.34)
        path.addQuadCurve(to: destination, control: control)

        let beam = SKShapeNode(path: path)
        beam.strokeColor = ArcadeStyle.Color.accentYellow.withAlphaComponent(0.92)
        beam.lineWidth = 2.2
        beam.glowWidth = 8
        beam.fillColor = .clear
        beam.zPosition = 24
        worldNode.addChild(beam)
        beam.run(.sequence([
            .fadeOut(withDuration: 0.28),
            .removeFromParent()
        ]))

        let pulse = SKSpriteNode(color: ArcadeStyle.Color.accentYellow, size: CGSize(width: 10, height: 10))
        pulse.position = source
        pulse.alpha = 0.94
        pulse.blendMode = .add
        pulse.zPosition = 25
        worldNode.addChild(pulse)
        pulse.run(.sequence([
            .group([
                timed(.move(to: destination, duration: 0.22), mode: .easeInEaseOut),
                timed(.fadeOut(withDuration: 0.22), mode: .easeInEaseOut),
                timed(.scale(to: 0.24, duration: 0.22), mode: .easeInEaseOut)
            ]),
            .removeFromParent()
        ]))
    }

    private func showRouteHintToExit(from start: GridPoint, duration: TimeInterval) {
        routeHintNode?.removeAllActions()
        routeHintNode?.removeFromParent()
        routeHintNode = nil

        guard let maze = currentMaze,
              let path = shortestRouteHintPath(from: start, to: maze.exit),
              path.count > 1 else { return }

        let container = SKNode()
        container.zPosition = 18
        worldNode.addChild(container)
        routeHintNode = container
        let hintColor = SKColor(red: 1.0, green: 0.81, blue: 0.2, alpha: 1.0)
        let hintHighlightColor = SKColor(red: 1.0, green: 0.92, blue: 0.56, alpha: 1.0)

        let curve = CGMutablePath()
        curve.move(to: positionFor(path[0]))
        for point in path.dropFirst() {
            curve.addLine(to: positionFor(point))
        }

        let baseLine = SKShapeNode(path: curve)
        baseLine.strokeColor = hintColor.withAlphaComponent(0.58)
        baseLine.lineWidth = max(3.0, tileSize * 0.1)
        baseLine.lineCap = .round
        baseLine.lineJoin = .round
        baseLine.glowWidth = 5
        baseLine.alpha = 0.0
        container.addChild(baseLine)

        let dustCount = min(18, max(8, path.count * 2))
        for index in 0..<dustCount {
            let particle = SKShapeNode(circleOfRadius: max(1.8, tileSize * 0.045))
            let ratio = CGFloat(index) / CGFloat(max(1, dustCount - 1))
            let sampleIndex = min(path.count - 1, Int(round(ratio * CGFloat(path.count - 1))))
            let basePosition = positionFor(path[sampleIndex])
            let jitterX = CGFloat.random(in: -tileSize * 0.08...tileSize * 0.08)
            let jitterY = CGFloat.random(in: -tileSize * 0.08...tileSize * 0.08)
            particle.position = snap(CGPoint(x: basePosition.x + jitterX, y: basePosition.y + jitterY))
            particle.fillColor = hintColor.withAlphaComponent(0.84)
            particle.strokeColor = hintHighlightColor.withAlphaComponent(0.46)
            particle.lineWidth = 0.5
            particle.glowWidth = 3
            particle.alpha = 0.0
            container.addChild(particle)

            let pulseDelay = Double(index) * 0.035
            particle.run(.repeatForever(.sequence([
                .wait(forDuration: pulseDelay),
                .group([
                    timed(.fadeAlpha(to: 0.62, duration: 0.18), mode: .easeOut),
                    timed(.scale(to: 1.28, duration: 0.18), mode: .easeOut)
                ]),
                .group([
                    timed(.fadeAlpha(to: 0.18, duration: 0.24), mode: .easeInEaseOut),
                    timed(.scale(to: 0.88, duration: 0.24), mode: .easeInEaseOut)
                ])
            ])), withKey: "hintDust_\(index)")
        }

        let fadeIn = SKAction.group([
            timed(.fadeAlpha(to: 0.86, duration: 0.16), mode: .easeOut),
            timed(.scale(to: 1.0, duration: 0.16), mode: .easeOut)
        ])
        let hold = SKAction.wait(forDuration: max(0.8, duration - 0.44))
        let fadeOut = SKAction.group([
            timed(.fadeOut(withDuration: 0.28), mode: .easeInEaseOut),
            timed(.scale(to: 1.04, duration: 0.28), mode: .easeInEaseOut)
        ])
        container.alpha = 0.0
        container.setScale(0.98)
        container.run(.sequence([
            fadeIn,
            hold,
            fadeOut,
            .run { [weak self, weak container] in
                container?.removeFromParent()
                if self?.routeHintNode === container {
                    self?.routeHintNode = nil
                }
            }
        ]), withKey: "routeHintLife")
    }

    private func tintedTexture(from texture: SKTexture, assetName: String, color: SKColor) -> SKTexture {
        #if os(iOS) || os(tvOS)
        guard let image = UIImage(named: assetName)?.cgImage else {
            return texture
        }
        let width = image.width
        let height = image.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return texture
        }

        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.clip(to: rect, mask: image)
        context.setFillColor(color.cgColor)
        context.fill(rect)

        guard let tinted = context.makeImage() else {
            return texture
        }
        return SKTexture(cgImage: tinted)
        #else
        return texture
        #endif
    }

    private func mixedColor(_ a: SKColor, _ b: SKColor, ratio: CGFloat) -> SKColor {
        let clamped = max(0, min(1, ratio))
        let inverse = 1 - clamped
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
        return SKColor(
            red: ar * inverse + br * clamped,
            green: ag * inverse + bg * clamped,
            blue: ab * inverse + bb * clamped,
            alpha: aa * inverse + ba * clamped
        )
    }

    private func timed(_ action: SKAction, mode: SKActionTimingMode) -> SKAction {
        action.timingMode = mode
        return action
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
        let previousBestTime = ProgressStore.shared.progress(for: levelDefinition.id).bestTime
        let updatedProgress = ProgressStore.shared.update(levelId: levelDefinition.id, time: finalTime, stars: stars)
        AdService.shared.registerCompletedStoryRun()
        let flowBonus = flowSystem.pointsThisRun * 15
        if flowBonus > 0 {
            score += flowBonus
        }
        if let bestTime = updatedProgress.bestTime,
           previousBestTime == nil || bestTime < (previousBestTime ?? .greatestFiniteMagnitude) {
            let scope = LeaderboardScope.storyLevel(levelDefinition.id)
            let leaderboardScore = leaderboardScoreForStoryTime(bestTime)
            LeaderboardProfileStore.shared.registerNewLocalBest(scope: scope, score: leaderboardScore)
            Task {
                await LeaderboardSyncCoordinator.shared.submitPendingScoresIfPossible(for: [scope])
            }
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
            if let theme = ThemeUnlocker.unlockTheme(for: levelDefinition.id) {
                ThemeProgress.shared.unlock(theme)
                showThemeUnlock(theme: theme)
            }
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
                let bestText = registration.bestTime.map { formattedClockTime($0) } ?? "--.--s"
                let rewardText: String
                let rewardAccentColor: SKColor
                let rewardClaimed: Bool
                if registration.awardedCoins > 0 {
                    rewardText = "+\(registration.awardedCoins) COINS"
                    rewardAccentColor = ArcadeStyle.Color.accentYellow
                    rewardClaimed = false
                    SoundFX.playReward(on: self)
                } else {
                    rewardText = "REWARD CLAIMED"
                    rewardAccentColor = ArcadeStyle.Color.accentCyan
                    rewardClaimed = true
                    SoundFX.playWin(on: self)
                }
                let finishPosition = playerNode?.position ?? (currentMaze.map { positionFor($0.exit) } ?? .zero)
                playEquippedWinAnimation(at: finishPosition) { [weak self] in
                    guard let self else { return }
                    self.showDailyResultOverlay(
                        difficultyText: self.botDifficulty.title.uppercased() + " BOT",
                        playerTime: self.formattedClockTime(finalTime),
                        bestTime: bestText,
                        rewardText: rewardText,
                        rewardAccentColor: rewardAccentColor,
                        isNewBest: registration.isNewBest,
                        rewardClaimed: rewardClaimed
                    )
                }
                return
            }
            let stars = starsForTime(finalTime)
            let previousBestTime = ProgressStore.shared.progress(for: levelDefinition.id).bestTime
            let updatedProgress = ProgressStore.shared.update(levelId: levelDefinition.id, time: finalTime, stars: stars)
            AdService.shared.registerCompletedStoryRun()
            let flowBonus = flowSystem.pointsThisRun * 15
            if flowBonus > 0 {
                score += flowBonus
            }
            if let bestTime = updatedProgress.bestTime,
               previousBestTime == nil || bestTime < (previousBestTime ?? .greatestFiniteMagnitude) {
                let scope = LeaderboardScope.storyLevel(levelDefinition.id)
                let leaderboardScore = leaderboardScoreForStoryTime(bestTime)
                LeaderboardProfileStore.shared.registerNewLocalBest(scope: scope, score: leaderboardScore)
                Task {
                    await LeaderboardSyncCoordinator.shared.submitPendingScoresIfPossible(for: [scope])
                }
            }
            showLevelResultOverlay(time: finalTime, stars: stars, headline: "LEVEL COMPLETE")
        case .bot:
            if isDailyMode, let dailyDescriptor {
                let bestText = DailyChallengeStore.shared.bestTime(for: dailyDescriptor).map { formattedClockTime($0) } ?? "--.--s"
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
            detail: theme.displayName,
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
            guard let overlay else {
                self?.rewardUnlockOverlay = nil
                onContinue()
                return
            }
            overlay.animateOut { [weak self, weak overlay] in
                overlay?.removeFromParent()
                self?.rewardUnlockOverlay = nil
                onContinue()
            }
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
        case .timeFreezeShatter:
            totalDuration = 0.52
            let freeze = SKShapeNode(rectOf: CGSize(width: tileSize * 0.92, height: tileSize * 0.92), cornerRadius: tileSize * 0.16)
            freeze.strokeColor = SKColor(hex: 0xB8F4FF)
            freeze.fillColor = SKColor(hex: 0xB8F4FF).withAlphaComponent(0.08)
            freeze.lineWidth = 2.5
            freeze.glowWidth = tileSize * 0.16
            container.addChild(freeze)

            for index in 0..<6 {
                let shard = SKShapeNode(rectOf: CGSize(width: tileSize * 0.12, height: tileSize * 0.12), cornerRadius: 2)
                shard.fillColor = SKColor(hex: 0xDFFBFF)
                shard.strokeColor = .clear
                shard.alpha = 0.9
                shard.position = .zero
                shard.zRotation = CGFloat(index) * (.pi / 6)
                container.addChild(shard)
                let angle = CGFloat(index) / 6 * .pi * 2
                shard.run(.sequence([
                    .wait(forDuration: 0.18),
                    .group([
                        .moveBy(x: cos(angle) * tileSize * 0.52, y: sin(angle) * tileSize * 0.52, duration: 0.28),
                        .fadeOut(withDuration: 0.28),
                        .scale(to: 0.2, duration: 0.28)
                    ]),
                    .removeFromParent()
                ]))
            }

            freeze.run(.sequence([
                .group([.fadeAlpha(to: 1.0, duration: 0.14), .scale(to: 1.04, duration: 0.14)]),
                .wait(forDuration: 0.04),
                .group([.fadeOut(withDuration: 0.34), .scale(to: 1.18, duration: 0.34)]),
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
            nextEnabled: nextEnabled,
            storyLeaderboardLevelId: levelDefinition.id
        )
    }

    private func showResultOverlay(
        stars: Int?,
        headline: String,
        timeText: String,
        detailLines: [String],
        requirementRows: [ResultOverlayNode.RequirementRow] = [],
        nextEnabled: Bool? = nil,
        storyLeaderboardLevelId: Int? = nil
    ) {
        clearCompletionOverlays()
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
        if let storyLeaderboardLevelId {
            overlay.setLeaderboardVisible(true, title: "BEST TIMES")
            overlay.onLeaderboard = { [weak self] in
                self?.openStoryLeaderboard(levelId: storyLeaderboardLevelId)
            }
        } else {
            overlay.setLeaderboardVisible(false)
            overlay.onLeaderboard = nil
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
        clearCompletionOverlays()
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

    private func showDailyResultOverlay(
        difficultyText: String,
        playerTime: String,
        bestTime: String,
        rewardText: String,
        rewardAccentColor: SKColor,
        isNewBest: Bool,
        rewardClaimed: Bool
    ) {
        clearCompletionOverlays()
        rewardUnlockOverlay?.removeFromParent()
        rewardUnlockOverlay = nil
        let safeTop = size.height / 2 - safeAreaInsets.top
        let safeBottom = -size.height / 2 + safeAreaInsets.bottom
        let overlay = DailyResultOverlayNode(
            size: size,
            safeTop: safeTop,
            safeBottom: safeBottom,
            difficultyText: difficultyText,
            timeText: playerTime,
            bestText: bestTime,
            rewardText: rewardText,
            rewardAccentColor: rewardAccentColor,
            isNewBest: isNewBest,
            rewardClaimed: rewardClaimed
        )
        overlay.position = snap(.zero)
        overlay.zPosition = 10000
        overlay.onRetry = { [weak self] in
            self?.retryLevel()
        }
        overlay.onMenu = { [weak self] in
            self?.goToLevelSelect()
        }
        dailyResultOverlay = overlay
        hudNode.addChild(overlay)
    }

    private func clearCompletionOverlays() {
        storyLeaderboardFetchTask?.cancel()
        storyLeaderboardFetchTask = nil
        teardownLeaderboardTextField()
        leaderboardNameOverlay?.removeFromParent()
        leaderboardNameOverlay = nil
        requiresLeaderboardNamePrompt = false
        pendingStoryLeaderboardLevelId = nil
        storyLeaderboardOverlay?.removeFromParent()
        storyLeaderboardOverlay = nil
        resultOverlay?.removeFromParent()
        resultOverlay = nil
        challengeResultOverlay?.removeFromParent()
        challengeResultOverlay = nil
        dailyResultOverlay?.removeFromParent()
        dailyResultOverlay = nil
    }

    private func openStoryLeaderboard(levelId: Int) {
        guard storyLeaderboardOverlay == nil else { return }
        pendingStoryLeaderboardLevelId = levelId
        let safeTop = size.height / 2 - safeAreaInsets.top
        let safeBottom = -size.height / 2 + safeAreaInsets.bottom
        let overlay = StoryLevelLeaderboardOverlayNode(
            size: size,
            safeTop: safeTop,
            safeBottom: safeBottom,
            levelId: levelId,
            levelName: levelDefinition.name,
            playerName: LeaderboardProfileStore.shared.playerName
        )
        overlay.position = snap(.zero)
        overlay.zPosition = 10020
        overlay.onClose = { [weak self] in
            self?.dismissStoryLeaderboard()
        }
        storyLeaderboardOverlay = overlay
        hudNode.addChild(overlay)
        if LeaderboardProfileStore.shared.playerName == nil {
            presentLeaderboardNamePrompt(required: true)
        }
        loadStoryLeaderboard(levelId: levelId)
    }

    private func dismissStoryLeaderboard(immediate: Bool = false) {
        storyLeaderboardFetchTask?.cancel()
        storyLeaderboardFetchTask = nil
        dismissLeaderboardNamePrompt(immediate: immediate)
        pendingStoryLeaderboardLevelId = nil
        guard let overlay = storyLeaderboardOverlay else { return }
        storyLeaderboardOverlay = nil
        if immediate {
            overlay.removeFromParent()
            return
        }
        overlay.animateOut {
            overlay.removeFromParent()
        }
    }

    private func loadStoryLeaderboard(levelId: Int) {
        guard let overlay = storyLeaderboardOverlay else { return }
        overlay.updatePlayerName(LeaderboardProfileStore.shared.playerName)
        overlay.setLoading()
        storyLeaderboardFetchTask?.cancel()
        storyLeaderboardFetchTask = Task { [weak self] in
            do {
                let entries = try await LeaderboardService.shared.fetchLeaderboard(scope: .storyLevel(levelId))
                await MainActor.run {
                    self?.storyLeaderboardOverlay?.setEntries(entries)
                }
            } catch {
                let localizedMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't load leaderboard."
                await MainActor.run {
                    self?.storyLeaderboardOverlay?.setError(localizedMessage)
                }
            }
        }
    }

    private func presentLeaderboardNamePrompt(required: Bool) {
        requiresLeaderboardNamePrompt = required
        guard leaderboardNameOverlay == nil else {
            layoutLeaderboardTextField()
            leaderboardTextField?.becomeFirstResponder()
            return
        }
        let safeTop = size.height / 2 - safeAreaInsets.top
        let safeBottom = -size.height / 2 + safeAreaInsets.bottom
        let overlay = LeaderboardNamePromptOverlayNode(size: size, safeTop: safeTop, safeBottom: safeBottom)
        overlay.position = snap(.zero)
        overlay.zPosition = 10030
        overlay.onCancel = { [weak self] in
            self?.cancelLeaderboardNamePrompt()
        }
        overlay.onConfirm = { [weak self] in
            self?.confirmLeaderboardNamePrompt()
        }
        leaderboardNameOverlay = overlay
        hudNode.addChild(overlay)
        SoundFX.playModalOpen(on: self)
        setupLeaderboardTextField()
        leaderboardTextField?.text = LeaderboardProfileStore.shared.playerName
        overlay.setValidationMessage(nil)
        updateLeaderboardConfirmState()
        leaderboardTextField?.becomeFirstResponder()
    }

    private func dismissLeaderboardNamePrompt(immediate: Bool = false, completion: (() -> Void)? = nil) {
        teardownLeaderboardTextField()
        guard let overlay = leaderboardNameOverlay else {
            completion?()
            return
        }
        leaderboardNameOverlay = nil
        if immediate {
            overlay.removeFromParent()
            completion?()
            return
        }
        SoundFX.playModalClose(on: self)
        overlay.animateOut {
            overlay.removeFromParent()
            completion?()
        }
    }

    private func cancelLeaderboardNamePrompt() {
        let hadName = LeaderboardProfileStore.shared.playerName != nil
        dismissLeaderboardNamePrompt { [weak self] in
            guard let self else { return }
            if self.requiresLeaderboardNamePrompt && !hadName {
                self.dismissStoryLeaderboard()
            }
            self.requiresLeaderboardNamePrompt = false
        }
    }

    private func confirmLeaderboardNamePrompt() {
        guard let rawName = leaderboardTextField?.text,
              let sanitized = LeaderboardProfileStore.shared.setPlayerName(rawName) else {
            leaderboardNameOverlay?.setValidationMessage("Enter a valid name.")
            updateLeaderboardConfirmState()
            return
        }

        requiresLeaderboardNamePrompt = false
        storyLeaderboardOverlay?.updatePlayerName(sanitized)
        dismissLeaderboardNamePrompt { [weak self] in
            guard let self else { return }
            Task {
                await LeaderboardSyncCoordinator.shared.submitPendingScoresIfPossible()
            }
            if let levelId = self.pendingStoryLeaderboardLevelId {
                self.loadStoryLeaderboard(levelId: levelId)
            }
        }
    }

    #if os(iOS) || os(tvOS)
    private func setupLeaderboardTextField() {
        guard leaderboardTextField == nil, let view else { return }

        let field = UITextField(frame: .zero)
        field.autocapitalizationType = .words
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.clearButtonMode = .never
        field.returnKeyType = .done
        field.enablesReturnKeyAutomatically = true
        field.delegate = self
        field.keyboardAppearance = .dark
        field.textColor = UIColor.white
        field.tintColor = UIColor(red: 0.0, green: 0.83, blue: 1.0, alpha: 1.0)
        field.font = UIFont.monospacedSystemFont(ofSize: 18, weight: .bold)
        field.textAlignment = .center
        field.placeholder = "YOUR NAME"
        field.attributedPlaceholder = NSAttributedString(
            string: "YOUR NAME",
            attributes: [.foregroundColor: UIColor(white: 0.68, alpha: 1.0)]
        )
        field.backgroundColor = .clear
        field.addTarget(self, action: #selector(handleLeaderboardTextChanged(_:)), for: .editingChanged)
        view.addSubview(field)
        leaderboardTextField = field
        layoutLeaderboardTextField()
    }

    private func teardownLeaderboardTextField() {
        leaderboardTextField?.resignFirstResponder()
        leaderboardTextField?.removeFromSuperview()
        leaderboardTextField = nil
    }

    private func layoutLeaderboardTextField() {
        guard let overlay = leaderboardNameOverlay, let field = leaderboardTextField else { return }
        let sceneRect = overlay.inputFrame(in: self)
        field.frame = viewFrame(fromSceneRect: sceneRect).insetBy(dx: 14, dy: 10)
    }

    private func viewFrame(fromSceneRect rect: CGRect) -> CGRect {
        guard let view else { return .zero }
        let topLeft = CGPoint(x: rect.minX, y: rect.maxY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.minY)
        let viewTopLeft = view.convert(topLeft, from: self)
        let viewBottomRight = view.convert(bottomRight, from: self)
        return CGRect(
            x: min(viewTopLeft.x, viewBottomRight.x),
            y: min(viewTopLeft.y, viewBottomRight.y),
            width: abs(viewBottomRight.x - viewTopLeft.x),
            height: abs(viewBottomRight.y - viewTopLeft.y)
        )
    }

    @objc private func handleLeaderboardTextChanged(_ textField: UITextField) {
        updateLeaderboardConfirmState()
        if let sanitized = LeaderboardProfileStore.shared.sanitize(name: textField.text ?? ""), !sanitized.isEmpty {
            leaderboardNameOverlay?.setValidationMessage(nil)
        }
    }
    #else
    private func setupLeaderboardTextField() {}
    private func teardownLeaderboardTextField() {}
    private func layoutLeaderboardTextField() {}
    #endif

    private func updateLeaderboardConfirmState() {
        let isValid = LeaderboardProfileStore.shared.sanitize(name: leaderboardTextField?.text ?? "") != nil
        leaderboardNameOverlay?.setConfirmEnabled(isValid)
    }

    private func advanceChallengeRun() {
        guard let challengeDuration else { return }
        let now = CACurrentMediaTime()
        updateTimer(now: now)
        updateTimerLabel()
        if let challengeLimit = currentChallengeTimeLimit(), displayedElapsedTime() >= challengeLimit {
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
        keyFollowerNode = nil
        routeHintNode = nil
        tileMapNode = nil
        currentMaze = nil
        currentStarBenchmarks = nil
        orbNodes.removeAll()
        timeBonusNodes.removeAll()
        keyNodes.removeAll()
        switchNodes.removeAll()
        switchBlockNodes.removeAll()
        orderedSwitchBlockPoints.removeAll()
        breakableNodes.removeAll()
        breakableHits.removeAll()
        orderedBreakablePoints.removeAll()
        gateNodes.removeAll()
        gateTiles.removeAll()
        teleporterNodes.removeAll()
        movingBlockDefinitions.removeAll()
        movingBlockTracks.removeAll()
        movingBlockNodes.removeAll()
        movingBlockOccupiedTiles.removeAll()
        teleporterMap.removeAll()
        oneWayDirections.removeAll()
        exitMarkerNode = nil
        exitGlowNode = nil
        exitLockNode = nil
        chaserNode?.removeAllActions()
        chaserNode?.removeFromParent()
        chaserNode = nil
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
        playerPathHistory.removeAll()
        chaserCurrentDirection = nil
        chaserBehavior = nil
        chaserIsMoving = false
        chaserCaughtPlayer = false
        chaserRevealPlayed = false
        chaserTargetLockPlayed = false
        chaserThreatLevel = 0
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
        if isNewRecord {
            let scope = LeaderboardScope.timeChallenge(duration)
            LeaderboardProfileStore.shared.registerNewLocalBest(scope: scope, score: challengeCompletedMazes)
            Task {
                await LeaderboardSyncCoordinator.shared.submitPendingScoresIfPossible(for: [scope])
            }
        }
        AdService.shared.registerCompletedTimeChallengeRun()
        let best = max(previousBest, challengeCompletedMazes)
        showChallengeResultOverlay(duration: duration, completedMazes: challengeCompletedMazes, bestMazes: best, isNewRecord: isNewRecord)
    }

    private func retryLevel() {
        guard !isTransitioning else { return }
        if currentGameState == .levelCompleted, isChallengeMode {
            presentDueInterstitialIfNeeded(for: .timeChallenge) { [weak self] in
                self?.retryLevelImmediate()
            }
            return
        }
        retryLevelImmediate()
    }

    private func retryLevelImmediate() {
        cameraNode.removeAllActions()
        applyGameplayCameraScale()
        clearCompletionOverlays()
        rewardUnlockOverlay?.removeFromParent()
        rewardUnlockOverlay = nil
        hideTutorialOverlay()
        resetGameAndReloadLevel()
    }

    private func goToNextLevel() {
        guard !isTransitioning else { return }
        guard !isChallengeMode else {
            retryLevelImmediate()
            return
        }
        if currentGameState == .levelCompleted, !isDailyMode {
            presentDueInterstitialIfNeeded(for: .story) { [weak self] in
                self?.goToNextLevelImmediate()
            }
            return
        }
        goToNextLevelImmediate()
    }

    private func goToNextLevelImmediate() {
        cameraNode.removeAllActions()
        applyGameplayCameraScale()
        clearCompletionOverlays()
        if levelIndex < LevelStore.levels.count - 1 {
            resetGameAndReloadLevel(targetLevelIndex: levelIndex + 1)
        } else {
            goToLevelSelect()
        }
    }

    private func goToLevelSelect() {
        guard !isTransitioning else { return }
        if currentGameState == .levelCompleted {
            if isChallengeMode {
                presentDueInterstitialIfNeeded(for: .timeChallenge) { [weak self] in
                    self?.transitionToLevelSelect()
                }
                return
            }
            if !isDailyMode {
                presentDueInterstitialIfNeeded(for: .story) { [weak self] in
                    self?.transitionToLevelSelect()
                }
                return
            }
        }
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
        formattedTime(time)
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

    private func pendingTutorial() -> PendingTutorial? {
        guard !isChallengeMode, !isDailyMode else { return nil }
        if levelDefinition.id == 1, !StartTutorialStore.shared.hasShown {
            return .basics
        }

        let mechanics = levelConfig.enabledMechanics.sorted { tutorialPriority(for: $0) < tutorialPriority(for: $1) }
        guard let mechanic = mechanics.first(where: { !MechanicTutorialStore.shared.hasShown($0) }) else {
            return nil
        }
        return .mechanic(mechanic)
    }

    private func showTutorialOverlay(for tutorial: PendingTutorial) {
        tutorialOverlay?.removeFromParent()
        let safeTop = size.height / 2 - safeAreaInsets.top
        let safeBottom = -size.height / 2 + safeAreaInsets.bottom
        let content: MechanicTutorialOverlayNode.Content
        switch tutorial {
        case .basics:
            content = .basics
        case let .mechanic(mechanic):
            content = .mechanic(mechanic)
        }
        let overlay = MechanicTutorialOverlayNode(size: size, safeTop: safeTop, safeBottom: safeBottom, content: content)
        overlay.position = snap(.zero)
        overlay.zPosition = 9500
        overlay.onContinue = { [weak self, weak overlay] in
            guard let self, let overlay else { return }
            SoundFX.playButtonTap(on: self.hudNode)
            if let mechanic = overlay.mechanic {
                MechanicTutorialStore.shared.markShown(mechanic)
            } else {
                StartTutorialStore.shared.markShown()
            }
            self.hideTutorialOverlay()
        }
        tutorialOverlay = overlay
        hudNode.addChild(overlay)
    }

    private func tutorialPriority(for mechanic: Mechanic) -> Int {
        switch mechanic {
        case .oneWay:
            return 0
        case .breakableWalls:
            return 1
        case .teleporters:
            return 2
        case .switchBlocks:
            return 3
        case .keysDoors:
            return 4
        case .fog:
            return 5
        case .timingGates:
            return 6
        case .movingBlocks:
            return 7
        case .chaserEnemy:
            return 8
        }
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
        let resumeState: GameState = runStartTime == nil ? .idle : .playing
        setGameState(resumeState)
        lastTimerUpdate = now
        hidePauseOverlay()
        if resumeState == .playing, botRaceEnabled, botHasStarted, botFinishTime == nil {
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
        guard let overlay = pauseOverlay else { return }
        pauseOverlay = nil
        overlay.animateOut {
            overlay.removeFromParent()
        }
    }

    private func goToLevelSelectFromPause() {
        transitionToLevelSelect()
    }

    private func restartLevel() {
        resetGameAndReloadLevel()
    }

    private func presentLevelSelect() {
        guard let view = view else { return }
        SoundFX.playScreenBack(on: self)
        let scene: SKScene
        if isChallengeMode {
            scene = ChallengeSelectScene(size: size)
        } else if isDailyMode {
            scene = DailyChallengeScene(size: size)
        } else {
            scene = LevelSelectScene(size: size)
        }
        scene.scaleMode = .resizeFill
        view.presentScene(scene, transition: ShellMotion.screenTransition(.backward))
    }

    private func transitionToLevelSelect() {
        guard !isTransitioning else { return }
        isTransitioning = true
        hideTutorialOverlay()
        hidePauseOverlay()
        rewardUnlockOverlay?.removeFromParent()
        rewardUnlockOverlay = nil
        clearCompletionOverlays()
        closeOverview()
        cleanupBeforeSceneTransition()
        presentLevelSelect()
    }

    private func presentDueInterstitialIfNeeded(for context: AdInterstitialContext, completion: @escaping () -> Void) {
        guard !isTransitioning else { return }
        isTransitioning = true
        activeButton?.setPressed(false)
        activeButton = nil
        let presenter = view?.window?.rootViewController
        AdService.shared.presentInterstitialIfDue(for: context, from: presenter) { [weak self] in
            guard let self else { return }
            self.isTransitioning = false
            completion()
        }
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
        chaserNode?.removeAllActions()
        chaserNode = nil
        tileMapNode = nil
        currentMaze = nil
        currentStarBenchmarks = nil
        isMoving = false
        botIsMoving = false
        chaserIsMoving = false
        botHasStarted = false
        botCurrentDirection = nil
        botForcedDirection = nil
        botFinishTime = nil
        chaserCurrentDirection = nil
        chaserBehavior = nil
        chaserCaughtPlayer = false
        easyBotLoopTracker = MazeSolvability.EasyBotLoopTracker()
        queuedDirection = nil
        queuedTimestamp = nil
        currentDirection = nil
        forcedDirection = nil
        keyFollowerNode?.removeFromParent()
        keyFollowerNode = nil
        routeHintNode?.removeAllActions()
        routeHintNode?.removeFromParent()
        routeHintNode = nil
        timeBonusNodes.values.forEach { $0.removeFromParent() }
        timeBonusNodes.removeAll()
        challengeBonusTime = 0
        isInOverviewMode = false
        overviewOverlay?.removeFromParent()
        overviewOverlay = nil
        clearCompletionOverlays()
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
        playerPathHistory.removeAll()
        movingBlockDefinitions.removeAll()
        movingBlockTracks.removeAll()
        movingBlockNodes.removeAll()
        movingBlockOccupiedTiles.removeAll()
        worldNode.removeAllChildren()
        hudNode.removeAllChildren()
    }

    private func presentNextLevel() {
        guard let view = view else { return }
        let nextIndex = levelIndex + 1
        if nextIndex < LevelStore.levels.count {
            SoundFX.playScreenAdvance(on: self)
            let scene = GameScene(size: size, levelIndex: nextIndex)
            scene.scaleMode = .resizeFill
            view.presentScene(scene, transition: ShellMotion.screenTransition(.forward))
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
            clearCompletionOverlays()
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
            SoundFX.playScreenAdvance(on: self)
            let scene = GameScene(size: size, levelIndex: targetIndex)
            scene.scaleMode = .resizeFill
            view.presentScene(scene, transition: ShellMotion.screenTransition(.forward))
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
        keyFollowerNode?.removeFromParent()
        keyFollowerNode = nil
        routeHintNode?.removeAllActions()
        routeHintNode?.removeFromParent()
        routeHintNode = nil
        comboSystem.reset()
        flowSystem.resetRun()
        score = 0
        addedOverviewPenalty = 0
        runStartTime = nil
        isInOverviewMode = false
        keyCount = 0
        switchActivated = false
        breakableHits.removeAll()
        orderedBreakablePoints.removeAll()
        gateIsOpen = true
        oneWayDirections.removeAll()
        teleporterMap.removeAll()
        gateTiles.removeAll()
        orbNodes.removeAll()
        keyNodes.removeAll()
        timeBonusNodes.values.forEach { $0.removeFromParent() }
        timeBonusNodes.removeAll()
        keyFollowerNode = nil
        routeHintNode = nil
        switchNodes.removeAll()
        switchBlockNodes.removeAll()
        breakableNodes.removeAll()
        gateNodes.removeAll()
        teleporterNodes.removeAll()
        movingBlockDefinitions.removeAll()
        movingBlockTracks.removeAll()
        movingBlockNodes.removeAll()
        movingBlockOccupiedTiles.removeAll()

        elapsedTime = 0
        challengeBonusTime = 0
        lastTimerUpdate = nil
        accumulatedPausedTime = 0
        pauseStartTime = nil
        activeButton = nil
        swipeStart = nil
        isMiniMapTouch = false

        pauseOverlay?.removeFromParent()
        pauseOverlay = nil
        clearCompletionOverlays()
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
        playerPathHistory.removeAll()
        chaserCurrentDirection = nil
        chaserBehavior = nil
        chaserIsMoving = false
        chaserCaughtPlayer = false
        chaserRevealPlayed = false
        chaserTargetLockPlayed = false
        chaserThreatLevel = 0
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
        let now = CACurrentMediaTime()
        guard currentGameState == .playing else {
            if !(isChallengeMode && currentGameState == .idle) {
                updateMovingBlocks(now: now)
            }
            if chaserThreatLevel != 0 {
                chaserThreatLevel = 0
                timerCard?.removeAction(forKey: "chaserThreat")
                timerCard?.run(timed(.colorize(withColorBlendFactor: 0.0, duration: 0.16), mode: .easeOut))
            }
            lastTimerUpdate = nil
            return
        }
        updateTimer(now: now)
        updateTimerLabel()
        if let challengeLimit = currentChallengeTimeLimit(), displayedElapsedTime() >= challengeLimit {
            finishChallengeRun()
            return
        }
        if needsExplorationRefresh, now - lastExplorationRefreshTime >= Tuning.explorationRefreshInterval {
            refreshExplorationPresentation()
            needsExplorationRefresh = false
            lastExplorationRefreshTime = now
        }
        updateGateState(now: now)
        updateMovingBlocks(now: now)
        updateChaser(now: now)
        updateChaserThreatFeedback()
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
        updateCollectedKeyFollower()
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
        if let overlay = leaderboardNameOverlay {
            if let button = overlay.button(at: point, in: self) {
                overlay.handleTap(button: button)
            }
            return
        }
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
                } else if let overlay = dailyResultOverlay, button.inParentHierarchy(overlay) {
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
        if let overlay = leaderboardNameOverlay, let button = overlay.button(at: point, in: self) {
            return button
        }
        if leaderboardNameOverlay != nil {
            return nil
        }
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
        if let overlay = storyLeaderboardOverlay,
           let button = overlay.button(at: point, in: self),
           button.isEnabled {
            return button
        }
        let targets: Set<String> = ["btn_next", "btn_retry", "btn_levelselect", "btn_story_leaderboard"]
        if let overlay = challengeResultOverlay {
            if let button = overlay.button(at: point, in: self),
               button.isEnabled,
               let name = button.name,
               targets.contains(name) {
                return button
            }
        }
        if let overlay = dailyResultOverlay {
            if let button = overlay.button(at: point, in: self),
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
        }
        return nil
    }

    private func handlePauseOverlayTap(at point: CGPoint) -> Bool {
        guard let overlay = pauseOverlay else { return false }
        if let button = overlay.button(at: point, in: self) {
            overlay.handleTap(button: button)
            return true
        }
        return false
    }

    private func handleCompletedOverlayTap(_ button: ArcadeButtonNode) {
        if let overlay = storyLeaderboardOverlay, button.inParentHierarchy(overlay) {
            overlay.handleTap(button: button)
        } else if let overlay = challengeResultOverlay, button.inParentHierarchy(overlay) {
            overlay.handleTap(button: button)
        } else if let overlay = dailyResultOverlay, button.inParentHierarchy(overlay) {
            overlay.handleTap(button: button)
        } else if let overlay = resultOverlay {
            overlay.handleTap(button: button)
        }
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

    @discardableResult
    private func commitSwipeIfNeeded(at location: CGPoint) -> Bool {
        guard currentGameState == .playing || currentGameState == .idle else { return false }
        guard !isMiniMapTouch else { return false }
        guard activeButton == nil else { return false }
        guard let start = swipeStart, let direction = swipeDirection(from: start, to: location) else { return false }
        handleSwipe(direction)
        swipeConsumed = true
        swipeStart = nil
        return true
    }

    #if os(iOS) || os(tvOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }
        swipeConsumed = false
        if leaderboardNameOverlay != nil {
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
        if resultOverlay != nil || challengeResultOverlay != nil || dailyResultOverlay != nil {
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
        if let overlay = leaderboardNameOverlay {
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
                swipeStart = nil
            }
            return
        }
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
        if resultOverlay != nil || challengeResultOverlay != nil || dailyResultOverlay != nil {
            activeButton?.setPressed(false)
            activeButton = nil
            swipeStart = nil
            if let button = overlayButton(at: location) {
                handleCompletedOverlayTap(button)
                return
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
                } else if let overlay = dailyResultOverlay, button.inParentHierarchy(overlay) {
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
            if swipeConsumed {
                swipeStart = nil
                swipeConsumed = false
                return
            }
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
        if leaderboardNameOverlay != nil {
            if let button = activeButton, let location = touches.first?.location(in: self) {
                let localPoint = localPoint(for: button, scenePoint: location)
                button.setPressed(button.contains(localPoint))
            }
            return
        }
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
        if resultOverlay != nil || challengeResultOverlay != nil || dailyResultOverlay != nil {
            return
        }
        if let location = touches.first?.location(in: self), commitSwipeIfNeeded(at: location) {
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
        swipeConsumed = false
        if leaderboardNameOverlay != nil {
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
        if let overlay = leaderboardNameOverlay {
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
                swipeStart = nil
            }
            return
        }
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
                    handleCompletedOverlayTap(button)
                }
            } else if let button = overlayButton(at: location) {
                handleCompletedOverlayTap(button)
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
                } else if let overlay = dailyResultOverlay, button.inParentHierarchy(overlay) {
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
            if swipeConsumed {
                swipeStart = nil
                swipeConsumed = false
                return
            }
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
        if leaderboardNameOverlay != nil {
            if let button = activeButton {
                let location = event.location(in: self)
                let localPoint = localPoint(for: button, scenePoint: location)
                button.setPressed(button.contains(localPoint))
            }
            return
        }
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
        let location = event.location(in: self)
        if commitSwipeIfNeeded(at: location) {
            return
        }
        guard let button = activeButton else { return }
        let localPoint = localPoint(for: button, scenePoint: location)
        button.setPressed(button.contains(localPoint))
    }

    #endif
}

#if os(iOS) || os(tvOS)
extension GameScene: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        confirmLeaderboardNamePrompt()
        return false
    }
}
#endif
