import Foundation

enum Mechanic: String, Codable, CaseIterable, Hashable {
    case oneWay
    case switchDoors
    case keysDoors
    case teleporters
    case timingGates
    case fog
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
    let oneWayDensity: Double

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

func introMechanic(for levelIndex: Int) -> Mechanic? {
    switch levelIndex {
    case 6:
        return .oneWay
    case 11:
        return .fog
    case 16:
        return .teleporters
    case 21:
        return .switchDoors
    case 26:
        return .keysDoors
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
    case .switchDoors:
        return MechanicTutorialDescriptor(
            mechanic: mechanic,
            title: "SWITCHES",
            message: "Trigger switches to unlock blocked routes and open the maze."
        )
    case .keysDoors:
        return MechanicTutorialDescriptor(
            mechanic: mechanic,
            title: "KEYS & DOORS",
            message: "Collect keys first, then use them to pass through locked doors."
        )
    case .timingGates:
        return MechanicTutorialDescriptor(
            mechanic: mechanic,
            title: "TIMING GATES",
            message: "Watch the rhythm and move when the gate is open."
        )
    }
}

func storyChapterDescriptor(for levelIndex: Int) -> StoryChapterDescriptor {
    switch max(1, min(30, levelIndex)) {
    case 1...5:
        return StoryChapterDescriptor(
            tag: "SECTOR 01",
            title: "NEON CORE",
            summary: "Learn the flow, read the maze, build your baseline speed."
        )
    case 6...10:
        return StoryChapterDescriptor(
            tag: "SECTOR 02",
            title: "ONE-WAY CIRCUITS",
            summary: "Arrows start simple, then force sharper route reading."
        )
    case 11...15:
        return StoryChapterDescriptor(
            tag: "SECTOR 03",
            title: "FOG SECTOR",
            summary: "Memory matters now. Read less, trust more."
        )
    case 16...20:
        return StoryChapterDescriptor(
            tag: "SECTOR 04",
            title: "PORTAL LAB",
            summary: "Teleporters bend the route and hide the fast line."
        )
    case 21...25:
        return StoryChapterDescriptor(
            tag: "SECTOR 05",
            title: "SWITCH GRID",
            summary: "Trigger logic opens the maze. Order starts to matter."
        )
    default:
        return StoryChapterDescriptor(
            tag: "SECTOR 06",
            title: "FINAL CIRCUITS",
            summary: "Keys, doors and mixed systems push the full skill check."
        )
    }
}

func storyChapterShortCode(for levelIndex: Int) -> String {
    switch max(1, min(30, levelIndex)) {
    case 1...5:
        return "CORE"
    case 6...10:
        return "ARROW"
    case 11...15:
        return "FOG"
    case 16...20:
        return "PORTAL"
    case 21...25:
        return "SWITCH"
    default:
        return "FINAL"
    }
}

func makeLevelConfig(levelIndex: Int) -> LevelConfig {
    let idx = max(1, min(30, levelIndex))
    let block = (idx - 1) / 5
    let step = (idx - 1) % 5

    let sizeTracks: [[Int]] = [
        [15, 15, 17, 17, 19],
        [17, 17, 19, 19, 21],
        [17, 19, 19, 21, 23],
        [19, 19, 21, 23, 23],
        [19, 21, 21, 23, 25],
        [21, 21, 23, 25, 27]
    ]
    let size = sizeTracks[min(block, sizeTracks.count - 1)][step] | 1
    let loop = min(0.2, 0.03 + Double(block) * 0.018 + Double(step) * 0.01)
    let branch = min(0.18, 0.045 + Double(block) * 0.014 + Double(step) * 0.008)
    let orbs = min(22, 7 + block * 2 + step)

    var mechanics: Set<Mechanic> = []
    var fogRadius = 0
    let gatePeriod = 0.0
    var teleporterPairs = 0
    var doorCount = 0
    var keyCount = 0
    var switchCount = 0
    var oneWayDensity = 0.0

    switch idx {
    case 1...5:
        mechanics = []

    case 6...10:
        mechanics = [.oneWay]
        let densities: [Double] = [0.02, 0.03, 0.04, 0.05, 0.06]
        oneWayDensity = densities[step]

    case 11...15:
        mechanics = [.fog]
        let radii = [4, 4, 3, 3, 2]
        fogRadius = radii[step]

    case 16...20:
        mechanics = [.teleporters]
        let pairs = [1, 1, 2, 2, 3]
        teleporterPairs = pairs[step]

    case 21...25:
        mechanics = [.switchDoors]
        let doors = [1, 1, 2, 2, 3]
        let switches = [1, 1, 1, 1, 1]
        doorCount = doors[step]
        switchCount = switches[step]
        if idx >= 24 {
            mechanics.insert(.teleporters)
            teleporterPairs = idx == 24 ? 1 : 2
        }
        if idx == 25 {
            mechanics.insert(.fog)
            fogRadius = 3
        }

    default:
        mechanics = [.keysDoors]
        let doors = [1, 2, 2, 3, 3]
        let keys = [1, 1, 1, 2, 2]
        doorCount = doors[step]
        keyCount = keys[step]

        if idx >= 27 {
            mechanics.insert(.oneWay)
            oneWayDensity = [0.03, 0.04, 0.045, 0.05, 0.055][step]
        }
        if idx >= 28 {
            mechanics.insert(.fog)
            fogRadius = idx == 28 ? 3 : 2
        }
        if idx >= 29 {
            mechanics.insert(.teleporters)
            teleporterPairs = idx == 29 ? 1 : 2
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
        oneWayDensity: oneWayDensity
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

    let fogRadius = 0
    var gatePeriod = 0.0
    var teleporterPairs = 0
    var doorCount = 0
    var keyCount = 0
    let switchCount = 0
    var oneWayDensity = 0.0

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
        doorCount = role == .reward ? 1 : min(2, 1 + (blockIndex + progressiveStep) / 4)
        keyCount = 1
    }

    if mechanics.contains(.oneWay) {
        let baseDensity = role == .reward
            ? 0.015 + blockScale * 0.002
            : 0.02 + blockScale * 0.004 + Double(progressiveStep) * 0.008
        let profileBoost: Double = profile == .deceptive ? 0.01 : (profile == .corridor ? -0.004 : 0.0)
        oneWayDensity = max(0.012, min(0.085, baseDensity + profileBoost))
    }

    let config = LevelConfig(
        levelIndex: idx,
        mazeSize: size,
        loopFactor: loop,
        branchFactor: branch,
        orbCount: 0,
        enabledMechanics: mechanics,
        fogRadius: fogRadius,
        gatePeriod: gatePeriod,
        teleporterPairs: teleporterPairs,
        doorCount: doorCount,
        keyCount: keyCount,
        switchCount: switchCount,
        oneWayDensity: oneWayDensity
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
    let wrapped = ((dayIndex % 25) + 25) % 25
    return 6 + wrapped
}

func makeDailyLevelConfig(dayIndex: Int) -> LevelConfig {
    makeLevelConfig(levelIndex: dailyReferenceLevelId(for: dayIndex))
}
