import Foundation

enum Mechanic: String, Codable, CaseIterable, Hashable {
    case oneWay
    case breakableWalls
    case switchBlocks
    case keysDoors
    case teleporters
    case timingGates
    case fog
    case movingBlocks
    case chaserEnemy
}

enum ChaserBehavior: String, Codable, CaseIterable, Hashable {
    case direct
    case delayed
}

struct LevelConfig: Codable, Hashable {
    let levelIndex: Int
    let mazeSize: Int
    let loopFactor: Double
    let branchFactor: Double
    let orbCount: Int
    let enabledMechanics: Set<Mechanic>
    let fogRadius: Int
    let gatePeriod: Double
    let teleporterPairs: Int
    let doorCount: Int
    let keyCount: Int
    let switchCount: Int
    let breakableCount: Int
    let switchBlockCount: Int
    let oneWayDensity: Double
    let movingBlockCount: Int
    let chaserBehavior: ChaserBehavior?

    var mazeParameters: MazeParameters {
        let size = max(5, mazeSize | 1)
        return MazeParameters(rows: size, cols: size, loopFactor: loopFactor, branchFactor: branchFactor, orbCount: orbCount)
    }
}

enum ChallengeMazeRole: Hashable {
    case progression
    case reward
}

enum ChallengeVariationProfile: Int, CaseIterable, Hashable {
    case corridor
    case branchy
    case compact
    case deceptive
    case open
}

struct ChallengeGenerationPlan: Hashable {
    let mazeNumber: Int
    let blockIndex: Int
    let cycleIndex: Int
    let role: ChallengeMazeRole
    let profile: ChallengeVariationProfile
    let config: LevelConfig
    let shortestPathRange: ClosedRange<Int>
    let branchDensityRange: ClosedRange<Double>
    let deadEndDensityRange: ClosedRange<Double>
    let directnessRange: ClosedRange<Double>
    let decisionDensityRange: ClosedRange<Double>

    var isRewardMaze: Bool {
        role == .reward
    }
}

struct MechanicTutorialDescriptor {
    let mechanic: Mechanic
    let title: String
    let message: String
}

struct StoryChapterDescriptor {
    let tag: String
    let title: String
    let summary: String
}

struct StoryChapterDefinition: Hashable {
    let id: Int
    let tag: String
    let title: String
    let summary: String
    let shortCode: String
    let levelRange: ClosedRange<Int>
    let mechanics: Set<Mechanic>

    var levelCount: Int {
        levelRange.upperBound - levelRange.lowerBound + 1
    }

    func contains(levelIndex: Int) -> Bool {
        levelRange.contains(levelIndex)
    }

    func localLevelIndex(for levelIndex: Int) -> Int {
        max(1, min(levelCount, levelIndex - levelRange.lowerBound + 1))
    }
}

private struct StoryMechanicPlan {
    let base: Set<Mechanic>
    let comboOrder: [Mechanic]
}

private let storyChapterDefinitions: [StoryChapterDefinition] = [
    StoryChapterDefinition(
        id: 1,
        tag: "CHAPTER 01",
        title: "MAZE BASICS",
        summary: "Pure route reading. Learn flow, speed and clean line-finding with no gimmicks.",
        shortCode: "CORE",
        levelRange: 1...10,
        mechanics: []
    ),
    StoryChapterDefinition(
        id: 2,
        tag: "CHAPTER 02",
        title: "ONE-WAY SYSTEM",
        summary: "Arrows turn clean movement into route commitment. Read before you swipe.",
        shortCode: "ARROW",
        levelRange: 11...20,
        mechanics: [.oneWay]
    ),
    StoryChapterDefinition(
        id: 3,
        tag: "CHAPTER 03",
        title: "BREAKABLE PATHS",
        summary: "Use controlled impacts to open the route. Commit to the right breach point.",
        shortCode: "BREACH",
        levelRange: 21...30,
        mechanics: [.breakableWalls]
    ),
    StoryChapterDefinition(
        id: 4,
        tag: "CHAPTER 04",
        title: "TELEPORT NETWORK",
        summary: "Portals bend the maze. Learn to read linked spaces and hidden shortcuts.",
        shortCode: "PORTAL",
        levelRange: 31...40,
        mechanics: [.teleporters]
    ),
    StoryChapterDefinition(
        id: 5,
        tag: "CHAPTER 05",
        title: "SWITCH LOGIC",
        summary: "Flip the floor switch and re-route the maze. Read cause and effect cleanly.",
        shortCode: "SWITCH",
        levelRange: 41...50,
        mechanics: [.switchBlocks]
    ),
    StoryChapterDefinition(
        id: 6,
        tag: "CHAPTER 06",
        title: "KEY SYSTEM",
        summary: "The exit stays locked until you grab the key. Plan the route around that detour.",
        shortCode: "KEY",
        levelRange: 51...60,
        mechanics: [.keysDoors]
    ),
    StoryChapterDefinition(
        id: 7,
        tag: "CHAPTER 07",
        title: "FOG ZONE",
        summary: "Darkness limits vision. Trust memory, landmarks and short-term route control.",
        shortCode: "FOG",
        levelRange: 61...70,
        mechanics: [.fog]
    ),
    StoryChapterDefinition(
        id: 8,
        tag: "CHAPTER 08",
        title: "VECTOR SHIFT",
        summary: "One-way lanes and portals combine into fast commitment puzzles with warped routing.",
        shortCode: "SHIFT",
        levelRange: 71...80,
        mechanics: [.oneWay, .teleporters]
    ),
    StoryChapterDefinition(
        id: 9,
        tag: "CHAPTER 09",
        title: "BREACH CONTROL",
        summary: "Switch timing and deliberate wall breaks combine into mechanical route planning.",
        shortCode: "CTRL",
        levelRange: 81...90,
        mechanics: [.switchBlocks, .breakableWalls]
    ),
    StoryChapterDefinition(
        id: 10,
        tag: "CHAPTER 10",
        title: "BLACKOUT PORTALS",
        summary: "Fog and teleporters test orientation under pressure. Read less, remember more.",
        shortCode: "VOID",
        levelRange: 91...100,
        mechanics: [.fog, .teleporters]
    )
]

func allStoryChapters() -> [StoryChapterDefinition] {
    storyChapterDefinitions
}

func storyChapter(for levelIndex: Int) -> StoryChapterDefinition {
    let clampedLevelIndex = max(1, min(storyChapterDefinitions.last?.levelRange.upperBound ?? 1, levelIndex))
    return storyChapterDefinitions.first(where: { $0.contains(levelIndex: clampedLevelIndex) }) ?? storyChapterDefinitions[0]
}

func storyLocalLevelIndex(for levelIndex: Int) -> Int {
    let chapter = storyChapter(for: levelIndex)
    return chapter.localLevelIndex(for: levelIndex)
}

func introMechanic(for levelIndex: Int) -> Mechanic? {
    switch levelIndex {
    case 11:
        return .oneWay
    case 21:
        return .breakableWalls
    case 31:
        return .teleporters
    case 41:
        return .switchBlocks
    case 51:
        return .keysDoors
    case 61:
        return .fog
    default:
        return nil
    }
}

func tutorialDescriptor(for mechanic: Mechanic) -> MechanicTutorialDescriptor {
    switch mechanic {
    case .oneWay:
        return MechanicTutorialDescriptor(
            mechanic: mechanic,
            title: "ONE-WAY TILES",
            message: "Arrows only allow movement in their marked direction."
        )
    case .breakableWalls:
        return MechanicTutorialDescriptor(
            mechanic: mechanic,
            title: "BREAK BLOCKS",
            message: "Crash into cracked blocks three times to break them and force the route open."
        )
    case .fog:
        return MechanicTutorialDescriptor(
            mechanic: mechanic,
            title: "FOG MODE",
            message: "Only explored areas stay visible. Learn the maze as you move."
        )
    case .teleporters:
        return MechanicTutorialDescriptor(
            mechanic: mechanic,
            title: "TELEPORTERS",
            message: "Use paired portals to reach routes that are hidden from normal paths."
        )
    case .switchBlocks:
        return MechanicTutorialDescriptor(
            mechanic: mechanic,
            title: "SWITCH BLOCKS",
            message: "Step on a switch to deactivate the lit blocks. Step again to bring them back."
        )
    case .keysDoors:
        return MechanicTutorialDescriptor(
            mechanic: mechanic,
            title: "LOCKED EXIT",
            message: "Collect a key first. The goal stays locked until you have one."
        )
    case .timingGates:
        return MechanicTutorialDescriptor(
            mechanic: mechanic,
            title: "TIMING GATES",
            message: "Watch the rhythm and move when the gate is open."
        )
    case .movingBlocks:
        return MechanicTutorialDescriptor(
            mechanic: mechanic,
            title: "MOVING BLOCKS",
            message: "Watch the pattern, then cross when the lane opens."
        )
    case .chaserEnemy:
        return MechanicTutorialDescriptor(
            mechanic: mechanic,
            title: "CHASER",
            message: "Stay ahead. It follows your route, but it is slower than you."
        )
    }
}

func storyChapterDescriptor(for levelIndex: Int) -> StoryChapterDescriptor {
    let chapter = storyChapter(for: levelIndex)
    return StoryChapterDescriptor(tag: chapter.tag, title: chapter.title, summary: chapter.summary)
}

func storyChapterShortCode(for levelIndex: Int) -> String {
    storyChapter(for: levelIndex).shortCode
}

private func storyMechanicPlan(for chapter: StoryChapterDefinition) -> StoryMechanicPlan {
    switch chapter.id {
    case 1:
        return StoryMechanicPlan(base: [], comboOrder: [])
    case 2:
        return StoryMechanicPlan(base: [.oneWay], comboOrder: [])
    case 3:
        return StoryMechanicPlan(base: [.breakableWalls], comboOrder: [.oneWay])
    case 4:
        return StoryMechanicPlan(base: [.teleporters], comboOrder: [.oneWay, .breakableWalls])
    case 5:
        return StoryMechanicPlan(base: [.switchBlocks], comboOrder: [.breakableWalls, .oneWay, .teleporters])
    case 6:
        return StoryMechanicPlan(base: [.keysDoors], comboOrder: [.oneWay, .teleporters, .breakableWalls])
    case 7:
        return StoryMechanicPlan(base: [.fog], comboOrder: [.teleporters, .oneWay, .keysDoors])
    case 8:
        return StoryMechanicPlan(base: [.oneWay, .teleporters], comboOrder: [.breakableWalls, .fog])
    case 9:
        return StoryMechanicPlan(base: [.switchBlocks, .breakableWalls], comboOrder: [.oneWay, .keysDoors])
    default:
        return StoryMechanicPlan(base: [.fog, .teleporters], comboOrder: [.oneWay, .switchBlocks])
    }
}

private func storyCombinationStage(for localLevelIndex: Int) -> Int {
    switch localLevelIndex {
    case 1...2:
        return 0
    case 3...4:
        return 1
    case 5...7:
        return 2
    default:
        return 3
    }
}

private func enabledStoryMechanics(for chapter: StoryChapterDefinition, localLevelIndex: Int) -> Set<Mechanic> {
    let plan = storyMechanicPlan(for: chapter)
    var enabled = plan.base

    switch localLevelIndex {
    case 1...2:
        break
    case 3...4:
        if let mechanic = plan.comboOrder.first {
            enabled.insert(mechanic)
        }
    case 5...7:
        if let mechanic = plan.comboOrder.first {
            enabled.insert(mechanic)
        }
        if plan.comboOrder.count > 1, localLevelIndex >= 6 {
            enabled.insert(plan.comboOrder[1])
        }
    default:
        if let mechanic = plan.comboOrder.first {
            enabled.insert(mechanic)
        }
        if plan.comboOrder.count > 1 {
            enabled.insert(plan.comboOrder[1])
        }
        if plan.comboOrder.count > 2, localLevelIndex >= 10 {
            enabled.insert(plan.comboOrder[2])
        }
    }

    return enabled
}

func makeLevelConfig(levelIndex: Int) -> LevelConfig {
    let maxStoryLevel = storyChapterDefinitions.last?.levelRange.upperBound ?? 1
    let idx = max(1, min(maxStoryLevel, levelIndex))
    let chapter = storyChapter(for: idx)
    let localLevelIndex = storyLocalLevelIndex(for: idx)
    let step = localLevelIndex - 1
    let combinationStage = storyCombinationStage(for: localLevelIndex)
    let mechanics = enabledStoryMechanics(for: chapter, localLevelIndex: localLevelIndex)
    let primaryMechanics = storyMechanicPlan(for: chapter).base
    let chapterScale = min(chapter.id - 1, 7)

    let sizeTrack = [15, 15, 17, 17, 19, 19, 21, 21, 23, 25]
    let size = min(39, (sizeTrack[step] + chapterScale * 2)) | 1
    let loop = min(0.22, 0.02 + Double(chapterScale) * 0.012 + Double(step) * 0.007)
    let branch = min(0.2, 0.03 + Double(chapterScale) * 0.011 + Double(step) * 0.008)
    let orbs = min(24, 6 + chapter.id + step)

    var fogRadius = 0
    let gatePeriod = 0.0
    var teleporterPairs = 0
    var doorCount = 0
    var keyCount = 0
    var switchCount = 0
    var breakableCount = 0
    var switchBlockCount = 0
    var oneWayDensity = 0.0
    let movingBlockCount = 0
    let chaserBehavior: ChaserBehavior? = nil

    if mechanics.contains(.oneWay) {
        let primaryTrack: [Double] = [0.018, 0.022, 0.026, 0.03, 0.036, 0.042, 0.048, 0.056, 0.064, 0.072]
        let supportTrack: [Double] = [0.014, 0.015, 0.017, 0.019, 0.022, 0.025, 0.029, 0.033, 0.037, 0.041]
        oneWayDensity = (primaryMechanics.contains(.oneWay) ? primaryTrack : supportTrack)[step]
    }

    if mechanics.contains(.breakableWalls) {
        let primaryTrack = [1, 1, 1, 1, 2, 2, 2, 3, 3, 4]
        let supportTrack = [1, 1, 1, 1, 1, 2, 2, 2, 2, 3]
        breakableCount = (primaryMechanics.contains(.breakableWalls) ? primaryTrack : supportTrack)[step]
    }

    if mechanics.contains(.teleporters) {
        let primaryTrack = [1, 1, 1, 1, 2, 2, 2, 2, 3, 3]
        let supportTrack = [1, 1, 1, 1, 1, 2, 2, 2, 2, 2]
        teleporterPairs = (primaryMechanics.contains(.teleporters) ? primaryTrack : supportTrack)[step]
    }

    if mechanics.contains(.switchBlocks) {
        let primarySwitches = [1, 1, 1, 1, 1, 1, 1, 2, 2, 2]
        let primaryBlocks = [1, 1, 1, 2, 2, 2, 3, 3, 4, 4]
        let supportSwitches = [1, 1, 1, 1, 1, 1, 1, 1, 2, 2]
        let supportBlocks = [1, 1, 1, 1, 2, 2, 2, 3, 3, 3]
        let isPrimarySwitchChapter = primaryMechanics.contains(.switchBlocks)
        switchCount = (isPrimarySwitchChapter ? primarySwitches : supportSwitches)[step]
        switchBlockCount = (isPrimarySwitchChapter ? primaryBlocks : supportBlocks)[step]
    }

    if mechanics.contains(.keysDoors) {
        doorCount = 0
        keyCount = 1
    }

    if mechanics.contains(.fog) {
        let primaryTrack = [5, 5, 4, 4, 4, 3, 3, 3, 2, 2]
        let supportTrack = [5, 5, 5, 4, 4, 4, 3, 3, 3, 3]
        fogRadius = (primaryMechanics.contains(.fog) ? primaryTrack : supportTrack)[step]
    }

    if chapter.id == 1 {
        oneWayDensity = 0.0
        breakableCount = 0
        teleporterPairs = 0
        switchCount = 0
        switchBlockCount = 0
        keyCount = 0
        fogRadius = 0
    }

    if combinationStage == 0 {
        switchBlockCount = min(switchBlockCount, primaryMechanics.contains(.switchBlocks) ? 2 : switchBlockCount)
    }

    if chapter.id >= 8 {
        let lateChapterOrbBoost = combinationStage >= 2 ? 2 : 0
        if mechanics.contains(.teleporters) {
            teleporterPairs = min(3, teleporterPairs + (combinationStage >= 3 ? 1 : 0))
        }
        if mechanics.contains(.breakableWalls) {
            breakableCount = min(4, breakableCount + lateChapterOrbBoost / 2)
        }
    }

    return LevelConfig(
        levelIndex: idx,
        mazeSize: size,
        loopFactor: loop,
        branchFactor: branch,
        orbCount: orbs,
        enabledMechanics: mechanics,
        fogRadius: fogRadius,
        gatePeriod: gatePeriod,
        teleporterPairs: teleporterPairs,
        doorCount: doorCount,
        keyCount: keyCount,
        switchCount: switchCount,
        breakableCount: breakableCount,
        switchBlockCount: switchBlockCount,
        oneWayDensity: oneWayDensity,
        movingBlockCount: movingBlockCount,
        chaserBehavior: chaserBehavior
    )
}

func makeChallengeGenerationPlan(mazeNumber: Int, variationOffset: Int = 0) -> ChallengeGenerationPlan {
    let idx = max(1, mazeNumber)
    let blockIndex = (idx - 1) / 5
    let cycleIndex = (idx - 1) % 5
    let role: ChallengeMazeRole = cycleIndex == 4 ? .reward : .progression
    let progressiveStep = min(cycleIndex, 3)

    let progressionProfiles: [ChallengeVariationProfile] = [.corridor, .branchy, .compact, .deceptive, .open]
    let rewardProfiles: [ChallengeVariationProfile] = [.compact, .corridor, .open]
    let profilePool = role == .reward ? rewardProfiles : progressionProfiles
    let profile = profilePool[(blockIndex * 2 + cycleIndex + max(0, variationOffset)) % profilePool.count]

    let blockScale = Double(min(blockIndex, 8))
    let rewardSize = min(31, (13 + min(blockIndex, 5) * 2) | 1)
    let progressiveSize = min(39, (15 + blockIndex * 2 + progressiveStep * 2) | 1)
    var size = role == .reward ? rewardSize : progressiveSize

    var loop = (role == .reward ? 0.018 : 0.028) + blockScale * (role == .reward ? 0.007 : 0.011) + Double(progressiveStep) * 0.015
    var branch = (role == .reward ? 0.024 : 0.045) + blockScale * (role == .reward ? 0.006 : 0.010) + Double(progressiveStep) * 0.018

    switch profile {
    case .corridor:
        loop -= 0.008
        branch -= 0.022
    case .branchy:
        loop += 0.012
        branch += 0.038
    case .compact:
        size = max(11, size - 2)
        loop += 0.004
        branch += 0.006
    case .deceptive:
        loop += 0.018
        branch += 0.02
    case .open:
        loop += 0.026
        branch -= 0.004
    }

    loop = max(0.012, min(0.24, loop))
    branch = max(0.02, min(0.23, branch))

    var mechanics: Set<Mechanic> = []
    if idx >= 6 { mechanics.insert(.oneWay) }
    if idx >= 9 { mechanics.insert(.teleporters) }
    if idx >= 12 { mechanics.insert(.timingGates) }
    if idx >= 15 { mechanics.insert(.keysDoors) }
    if idx >= 18 { mechanics.insert(.movingBlocks) }
    if idx >= 28 { mechanics.insert(.chaserEnemy) }
    if mechanics.contains(.chaserEnemy) {
        mechanics.remove(.timingGates)
    }

    let fogRadius = 0
    var gatePeriod = 0.0
    var teleporterPairs = 0
    var doorCount = 0
    var keyCount = 0
    let switchCount = 0
    let breakableCount = 0
    let switchBlockCount = 0
    var oneWayDensity = 0.0
    var movingBlockCount = 0
    var chaserBehavior: ChaserBehavior?

    if mechanics.contains(.timingGates) {
        let baseGatePeriod = role == .reward ? 1.14 : 1.02
        let cyclePressure = role == .reward ? 0.0 : Double(progressiveStep) * 0.04
        gatePeriod = max(0.76, baseGatePeriod - blockScale * 0.03 - cyclePressure)
    }

    if mechanics.contains(.teleporters) {
        teleporterPairs = role == .reward
            ? min(2, 1 + blockIndex / 3)
            : min(3, 1 + blockIndex / 2 + (progressiveStep >= 2 ? 1 : 0))
    }

    if mechanics.contains(.keysDoors) {
        doorCount = 0
        keyCount = 1
    }

    if mechanics.contains(.oneWay) {
        let baseDensity = role == .reward
            ? 0.015 + blockScale * 0.002
            : 0.02 + blockScale * 0.004 + Double(progressiveStep) * 0.008
        let profileBoost: Double = profile == .deceptive ? 0.01 : (profile == .corridor ? -0.004 : 0.0)
        oneWayDensity = max(0.012, min(0.085, baseDensity + profileBoost))
    }

    if mechanics.contains(.movingBlocks) {
        movingBlockCount = role == .reward
            ? 1
            : min(2, 1 + blockIndex / 4 + (progressiveStep >= 2 ? 1 : 0))
    }

    if mechanics.contains(.chaserEnemy) {
        chaserBehavior = idx >= 33 ? .delayed : .direct
    }

    let timeBonusPickupCount = role == .reward ? 2 : min(2, idx >= 10 ? 2 : 1)

    let config = LevelConfig(
        levelIndex: idx,
        mazeSize: size,
        loopFactor: loop,
        branchFactor: branch,
        orbCount: timeBonusPickupCount,
        enabledMechanics: mechanics,
        fogRadius: fogRadius,
        gatePeriod: gatePeriod,
        teleporterPairs: teleporterPairs,
        doorCount: doorCount,
        keyCount: keyCount,
        switchCount: switchCount,
        breakableCount: breakableCount,
        switchBlockCount: switchBlockCount,
        oneWayDensity: oneWayDensity,
        movingBlockCount: movingBlockCount,
        chaserBehavior: chaserBehavior
    )

    let shortestPathCenter: Int = {
        let base = role == .reward
            ? 22 + blockIndex * 3
            : [28, 36, 44, 54][progressiveStep] + blockIndex * 4
        switch profile {
        case .corridor:
            return base + 6
        case .branchy:
            return base + 2
        case .compact:
            return base - 7
        case .deceptive:
            return base + 4
        case .open:
            return base
        }
    }()

    let branchDensityCenter: Double = {
        let base = role == .reward
            ? 0.07 + blockScale * 0.008
            : [0.085, 0.105, 0.125, 0.145][progressiveStep] + blockScale * 0.01
        switch profile {
        case .corridor:
            return base - 0.03
        case .branchy:
            return base + 0.05
        case .compact:
            return base + 0.01
        case .deceptive:
            return base + 0.025
        case .open:
            return base - 0.01
        }
    }()

    let deadEndDensityCenter: Double = {
        let base = role == .reward
            ? 0.12 + blockScale * 0.012
            : [0.15, 0.18, 0.21, 0.24][progressiveStep] + blockScale * 0.012
        switch profile {
        case .corridor:
            return base - 0.04
        case .branchy:
            return base + 0.02
        case .compact:
            return base - 0.015
        case .deceptive:
            return base + 0.045
        case .open:
            return base - 0.035
        }
    }()

    let directnessCenter: Double = {
        let base = role == .reward
            ? 1.85 + blockScale * 0.06
            : [2.0, 2.2, 2.4, 2.65][progressiveStep] + blockScale * 0.08
        switch profile {
        case .corridor:
            return base - 0.18
        case .branchy:
            return base + 0.05
        case .compact:
            return base - 0.16
        case .deceptive:
            return base + 0.28
        case .open:
            return base - 0.06
        }
    }()

    let decisionDensityCenter: Double = {
        let base = role == .reward
            ? 0.08 + blockScale * 0.006
            : [0.10, 0.12, 0.14, 0.16][progressiveStep] + blockScale * 0.008
        switch profile {
        case .corridor:
            return base - 0.02
        case .branchy:
            return base + 0.03
        case .compact:
            return base + 0.01
        case .deceptive:
            return base + 0.02
        case .open:
            return base - 0.01
        }
    }()

    return ChallengeGenerationPlan(
        mazeNumber: idx,
        blockIndex: blockIndex,
        cycleIndex: cycleIndex,
        role: role,
        profile: profile,
        config: config,
        shortestPathRange: max(14, shortestPathCenter - 8)...max(18, shortestPathCenter + 10),
        branchDensityRange: max(0.03, branchDensityCenter - 0.035)...min(0.28, branchDensityCenter + 0.04),
        deadEndDensityRange: max(0.05, deadEndDensityCenter - 0.05)...min(0.38, deadEndDensityCenter + 0.05),
        directnessRange: max(1.35, directnessCenter - 0.35)...min(3.75, directnessCenter + 0.4),
        decisionDensityRange: max(0.05, decisionDensityCenter - 0.03)...min(0.26, decisionDensityCenter + 0.035)
    )
}

func makeChallengeLevelConfig(mazeNumber: Int) -> LevelConfig {
    makeChallengeGenerationPlan(mazeNumber: mazeNumber).config
}

func dailyReferenceLevelId(for dayIndex: Int) -> Int {
    let totalLevels = allStoryChapters().last?.levelRange.upperBound ?? 1
    let firstAdvancedLevel = min(totalLevels, 11)
    let availableCount = max(1, totalLevels - firstAdvancedLevel + 1)
    let wrapped = ((dayIndex % availableCount) + availableCount) % availableCount
    return min(totalLevels, firstAdvancedLevel + wrapped)
}

func makeDailyLevelConfig(dayIndex: Int) -> LevelConfig {
    makeLevelConfig(levelIndex: dailyReferenceLevelId(for: dayIndex))
}
