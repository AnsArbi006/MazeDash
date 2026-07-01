import Foundation
import SpriteKit
#if os(iOS) || os(tvOS)
import UIKit
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif
#if canImport(GoogleUserMessagingPlatform)
import UserMessagingPlatform
#endif
#endif

struct GridPoint: Hashable, Codable {
    let row: Int
    let col: Int

    func moved(by direction: MoveDirection) -> GridPoint {
        GridPoint(row: row + direction.deltaRow, col: col + direction.deltaCol)
    }
}

enum MoveDirection: CaseIterable, Hashable, Codable {
    case up
    case down
    case left
    case right

    var deltaRow: Int {
        switch self {
        case .up:
            return -1
        case .down:
            return 1
        case .left, .right:
            return 0
        }
    }

    var deltaCol: Int {
        switch self {
        case .left:
            return -1
        case .right:
            return 1
        case .up, .down:
            return 0
        }
    }
}

struct LevelDefinition {
    let id: Int
    let name: String
    let params: MazeParameters

    var rows: Int { params.rows }
    var cols: Int { params.cols }
}

struct LevelProgress: Codable {
    var bestTime: Double?
    var stars: Int
}

struct LevelBenchmarkData: Codable, Equatable {
    let easyBotTime: TimeInterval
    let hardBotTime: TimeInterval
    let oneStarTime: TimeInterval
    let twoStarTime: TimeInterval
    let threeStarTime: TimeInterval

    static func make(easyBotTime: TimeInterval, hardBotTime: TimeInterval) -> LevelBenchmarkData {
        let clampedEasy = max(MazeTiming.stepDuration, easyBotTime)
        let clampedHard = max(MazeTiming.stepDuration, hardBotTime)
        let oneStarCandidate = clampedEasy
        let twoStarCandidate = clampedHard + 0.55 * max(0, clampedEasy - clampedHard)
        let threeStarCandidate = clampedHard * 1.15
        let ordered = [oneStarCandidate, twoStarCandidate, threeStarCandidate].sorted(by: >)
        return LevelBenchmarkData(
            easyBotTime: clampedEasy,
            hardBotTime: clampedHard,
            oneStarTime: ordered[0],
            twoStarTime: ordered[1],
            threeStarTime: ordered[2]
        )
    }

    func stars(for playerTime: TimeInterval) -> Int {
        let time = max(0, playerTime)
        if time > oneStarTime { return 0 }
        if time <= threeStarTime { return 3 }
        if time <= twoStarTime { return 2 }
        return 1
    }
}

final class ProgressStore {
    static let shared = ProgressStore()

    private let storageKey = "neonMazeStarsProgress"
    private let lastPlayedKey = "neonMazeStarsLastPlayedLevel"
    private var data: [String: LevelProgress] = [:]
    private(set) var lastPlayedLevelId: Int?

    private init() {
        load()
    }

    func progress(for levelId: Int) -> LevelProgress {
        let key = String(levelId)
        return data[key] ?? LevelProgress(bestTime: nil, stars: 0)
    }

    @discardableResult
    func update(levelId: Int, time: TimeInterval, stars: Int) -> LevelProgress {
        let key = String(levelId)
        var current = data[key] ?? LevelProgress(bestTime: nil, stars: 0)
        if let best = current.bestTime {
            current.bestTime = min(best, time)
        } else {
            current.bestTime = time
        }
        current.stars = max(current.stars, stars)
        data[key] = current
        save()
        return current
    }

    var completedLevelCount: Int {
        data.values.filter { $0.stars > 0 || $0.bestTime != nil }.count
    }

    var totalStars: Int {
        data.values.reduce(0) { $0 + $1.stars }
    }

    var threeStarLevelCount: Int {
        data.values.filter { $0.stars >= 3 }.count
    }

    var bestRecordedTime: TimeInterval? {
        data.values.compactMap(\.bestTime).min()
    }

    var nextPlayableLevelId: Int {
        min(LevelStore.levels.count, max(1, completedLevelCount + 1))
    }

    var continueLevelId: Int {
        guard let lastPlayedLevelId else { return nextPlayableLevelId }
        return min(LevelStore.levels.count, max(1, lastPlayedLevelId))
    }

    func markLastPlayed(levelId: Int) {
        let safeLevelId = min(LevelStore.levels.count, max(1, levelId))
        lastPlayedLevelId = safeLevelId
        UserDefaults.standard.set(safeLevelId, forKey: lastPlayedKey)
    }

    private func load() {
        if let storedLastPlayed = UserDefaults.standard.object(forKey: lastPlayedKey) as? Int {
            lastPlayedLevelId = min(LevelStore.levels.count, max(1, storedLastPlayed))
        } else {
            lastPlayedLevelId = nil
        }
        guard let stored = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([String: LevelProgress].self, from: stored)
            data = decoded
        } catch {
            data = [:]
        }
    }

    private func save() {
        do {
            let encoded = try JSONEncoder().encode(data)
            UserDefaults.standard.set(encoded, forKey: storageKey)
        } catch {
            return
        }
    }
}

final class MazeBenchmarkStore {
    static let shared = MazeBenchmarkStore()

    private let storagePrefix = "mazeDashBenchmark_v4_"
    private let queue = DispatchQueue(label: "maze.benchmark.store")
    private var memory: [String: LevelBenchmarkData] = [:]

    private init() {}

    func cachedBenchmarks(levelId: Int, maze: MazeData) -> LevelBenchmarkData? {
        let key = cacheKey(levelId: levelId, maze: maze)
        var cached: LevelBenchmarkData?
        queue.sync {
            if let memoryValue = memory[key] {
                cached = memoryValue
                return
            }
            if let stored = loadFromDisk(key: key) {
                memory[key] = stored
                cached = stored
            }
        }
        return cached
    }

    func benchmarks(levelId: Int, maze: MazeData) -> LevelBenchmarkData {
        if let cached = cachedBenchmarks(levelId: levelId, maze: maze) {
            return cached
        }

        let computed = computeBenchmarks(for: maze)
        let key = cacheKey(levelId: levelId, maze: maze)
        queue.sync {
            memory[key] = computed
            saveToDisk(key: key, benchmarks: computed)
        }
        return computed
    }

    func prefetch(levelId: Int, maze: MazeData) {
        let key = cacheKey(levelId: levelId, maze: maze)
        var shouldCompute = true
        queue.sync {
            if memory[key] != nil || loadFromDisk(key: key) != nil {
                shouldCompute = false
            }
        }
        guard shouldCompute else { return }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let computed = self.computeBenchmarks(for: maze)
            self.queue.async {
                self.memory[key] = computed
                self.saveToDisk(key: key, benchmarks: computed)
            }
        }
    }

    private func computeBenchmarks(for maze: MazeData) -> LevelBenchmarkData {
        let hardSteps = MazeSolvability.shortestCompletionSteps(grid: maze.grid, start: maze.start, exit: maze.exit) ?? max(maze.shortestPath, 1)
        let fallbackEasySteps = max(hardSteps + max(maze.rows, maze.cols), hardSteps * 2)
        let easySteps = MazeSolvability.easyBotCompletionSteps(grid: maze.grid, start: maze.start, exit: maze.exit) ?? fallbackEasySteps
        return LevelBenchmarkData.make(
            easyBotTime: Double(easySteps) * MazeTiming.stepDuration,
            hardBotTime: Double(hardSteps) * MazeTiming.stepDuration
        )
    }

    private func loadFromDisk(key: String) -> LevelBenchmarkData? {
        let storageKey = storagePrefix + key
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(LevelBenchmarkData.self, from: data)
    }

    private func saveToDisk(key: String, benchmarks: LevelBenchmarkData) {
        let storageKey = storagePrefix + key
        if let data = try? JSONEncoder().encode(benchmarks) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func cacheKey(levelId: Int, maze: MazeData) -> String {
        let signature = mazeSignature(maze)
        return "lvl\(levelId)_\(signature)"
    }

    private func mazeSignature(_ maze: MazeData) -> String {
        var hash: UInt64 = 1469598103934665603
        func mix(_ value: UInt64) {
            hash ^= value
            hash &*= 1099511628211
        }

        mix(UInt64(maze.rows))
        mix(UInt64(maze.cols))
        mix(UInt64(maze.start.row &* 31 &+ maze.start.col))
        mix(UInt64(maze.exit.row &* 31 &+ maze.exit.col))
        for row in maze.grid {
            for scalar in row.unicodeScalars {
                mix(UInt64(scalar.value))
            }
            mix(257)
        }
        for movingBlock in maze.movingBlocks {
            mix(UInt64(movingBlock.start.row &* 31 &+ movingBlock.start.col))
            mix(UInt64(movingBlock.end.row &* 31 &+ movingBlock.end.col))
            mix(UInt64((movingBlock.speedMultiplier * 1000).rounded()))
            mix(UInt64((movingBlock.phaseOffset * 1000).rounded()))
        }
        if let chaserSpawn = maze.chaserSpawn {
            mix(UInt64(chaserSpawn.spawn.row &* 31 &+ chaserSpawn.spawn.col))
            for scalar in chaserSpawn.behavior.rawValue.unicodeScalars {
                mix(UInt64(scalar.value))
            }
            mix(UInt64((chaserSpawn.startDelay * 1000).rounded()))
            mix(UInt64((chaserSpawn.repathDelay * 1000).rounded()))
            mix(UInt64((chaserSpawn.speedMultiplier * 1000).rounded()))
            mix(UInt64(chaserSpawn.trailDelaySteps))
        }
        return String(hash, radix: 16)
    }
}

struct LevelStore {
    static let levels: [LevelDefinition] = {
        let lastLevel = allStoryChapters().last?.levelRange.upperBound ?? 1
        return (1...lastLevel).map { index in
            let config = makeLevelConfig(levelIndex: index)
            return LevelDefinition(
                id: index,
                name: "Level \(storyLocalLevelIndex(for: index))",
                params: config.mazeParameters
            )
        }
    }()
}

final class ThemeProgress {
    static let shared = ThemeProgress()
    private let storageKey = "neonMazeThemeUnlocks"
    private var unlocked: Set<Int>

    private init() {
        if let stored = UserDefaults.standard.array(forKey: storageKey) as? [Int] {
            unlocked = Set(stored)
        } else {
            unlocked = [MazeTheme.defaultTheme.rawValue]
        }
    }

    func isUnlocked(_ theme: MazeTheme) -> Bool {
        unlocked.contains(theme.rawValue)
    }

    func unlock(_ theme: MazeTheme) {
        unlocked.insert(theme.rawValue)
        UserDefaults.standard.set(Array(unlocked), forKey: storageKey)
    }

    var unlockedCount: Int {
        unlocked.count
    }
}

final class SettingsStore {
    static let shared = SettingsStore()

    private enum Key {
        static let masterVolume = "neonMazeMasterVolume"
        static let effectsEnabled = "neonMazeEffectsEnabled"
        static let musicEnabled = "neonMazeMusicEnabled"
        static let vibrationEnabled = "neonMazeVibrationEnabled"
        static let legacySoundEnabled = "neonMazeSoundEnabled"
    }

    private let defaults = UserDefaults.standard
    private(set) var masterVolume: Float
    private(set) var isEffectsEnabled: Bool
    private(set) var isMusicEnabled: Bool
    private(set) var isVibrationEnabled: Bool

    var isEffectsPlaybackEnabled: Bool {
        isEffectsEnabled && masterVolume > 0.001
    }

    var isMusicPlaybackEnabled: Bool {
        isMusicEnabled && masterVolume > 0.001
    }

    var isSoundEnabled: Bool {
        isEffectsPlaybackEnabled || isMusicPlaybackEnabled
    }

    private init() {
        if defaults.object(forKey: Key.masterVolume) == nil {
            masterVolume = 0.76
        } else {
            masterVolume = defaults.float(forKey: Key.masterVolume)
        }

        let legacySoundEnabled: Bool
        if defaults.object(forKey: Key.legacySoundEnabled) == nil {
            legacySoundEnabled = true
        } else {
            legacySoundEnabled = defaults.bool(forKey: Key.legacySoundEnabled)
        }

        if defaults.object(forKey: Key.effectsEnabled) == nil {
            isEffectsEnabled = legacySoundEnabled
        } else {
            isEffectsEnabled = defaults.bool(forKey: Key.effectsEnabled)
        }

        if defaults.object(forKey: Key.musicEnabled) == nil {
            isMusicEnabled = legacySoundEnabled
        } else {
            isMusicEnabled = defaults.bool(forKey: Key.musicEnabled)
        }

        if defaults.object(forKey: Key.vibrationEnabled) == nil {
            isVibrationEnabled = true
        } else {
            isVibrationEnabled = defaults.bool(forKey: Key.vibrationEnabled)
        }
    }

    func toggleSound() -> Bool {
        setSoundEnabled(!(isEffectsEnabled || isMusicEnabled))
        return isSoundEnabled
    }

    func setSoundEnabled(_ enabled: Bool) {
        if enabled && masterVolume <= 0.001 {
            setMasterVolume(0.76)
        }
        setEffectsEnabled(enabled)
        setMusicEnabled(enabled)
        defaults.set(enabled, forKey: Key.legacySoundEnabled)
    }

    func setMasterVolume(_ value: Float) {
        masterVolume = min(1, max(0, value))
        defaults.set(masterVolume, forKey: Key.masterVolume)
    }

    func setEffectsEnabled(_ enabled: Bool) {
        isEffectsEnabled = enabled
        defaults.set(enabled, forKey: Key.effectsEnabled)
        defaults.set(isEffectsEnabled || isMusicEnabled, forKey: Key.legacySoundEnabled)
    }

    func setMusicEnabled(_ enabled: Bool) {
        isMusicEnabled = enabled
        defaults.set(enabled, forKey: Key.musicEnabled)
        defaults.set(isEffectsEnabled || isMusicEnabled, forKey: Key.legacySoundEnabled)
    }

    func setVibrationEnabled(_ enabled: Bool) {
        isVibrationEnabled = enabled
        defaults.set(enabled, forKey: Key.vibrationEnabled)
    }
}

final class DailyPromptStore {
    static let shared = DailyPromptStore()

    private let storageKey = "neonMazeDailyPromptShownDay"
    private let calendar = Calendar.current

    func shouldShowPromptToday(date: Date = Date()) -> Bool {
        UserDefaults.standard.string(forKey: storageKey) != dayKey(for: date)
    }

    func markShownToday(date: Date = Date()) {
        UserDefaults.standard.set(dayKey(for: date), forKey: storageKey)
    }

    private func dayKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 1970, components.month ?? 1, components.day ?? 1)
    }
}

#if os(iOS) || os(tvOS)
enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard SettingsStore.shared.isVibrationEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}
#endif

final class MechanicTutorialStore {
    static let shared = MechanicTutorialStore()

    private let storageKey = "neonMazeShownMechanicTutorials"
    private var shownTutorials: Set<String>

    private init() {
        shownTutorials = Set(UserDefaults.standard.stringArray(forKey: storageKey) ?? [])
    }

    func hasShown(_ mechanic: Mechanic) -> Bool {
        shownTutorials.contains(mechanic.rawValue)
    }

    func markShown(_ mechanic: Mechanic) {
        shownTutorials.insert(mechanic.rawValue)
        UserDefaults.standard.set(Array(shownTutorials).sorted(), forKey: storageKey)
    }

    func resetAll() {
        shownTutorials.removeAll()
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}

final class StartTutorialStore {
    static let shared = StartTutorialStore()

    private let storageKey = "neonMazeDidShowStartTutorial"

    var hasShown: Bool {
        UserDefaults.standard.bool(forKey: storageKey)
    }

    func markShown() {
        UserDefaults.standard.set(true, forKey: storageKey)
    }

    func reset() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}

enum BotDifficulty: Int, CaseIterable, Codable {
    case off
    case easy
    case hard

    var title: String {
        switch self {
        case .off:
            return "Off"
        case .easy:
            return "Easy"
        case .hard:
            return "Hard"
        }
    }

    var buttonTitle: String {
        switch self {
        case .off:
            return "BOT OFF"
        case .easy:
            return "BOT EASY"
        case .hard:
            return "BOT HARD"
        }
    }
}

final class BotSettingsStore {
    static let shared = BotSettingsStore()

    private let storageKey = "neonMazeBotDifficulty"
    private(set) var difficulty: BotDifficulty

    private init() {
        let stored = UserDefaults.standard.integer(forKey: storageKey)
        difficulty = BotDifficulty(rawValue: stored) ?? .off
    }

    @discardableResult
    func cycleDifficulty() -> BotDifficulty {
        let allCases = BotDifficulty.allCases
        guard let currentIndex = allCases.firstIndex(of: difficulty) else {
            setDifficulty(.off)
            return difficulty
        }
        let nextIndex = allCases.index(after: currentIndex)
        let nextDifficulty = nextIndex < allCases.endIndex ? allCases[nextIndex] : allCases[allCases.startIndex]
        setDifficulty(nextDifficulty)
        return difficulty
    }

    func setDifficulty(_ newValue: BotDifficulty) {
        difficulty = newValue
        UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
    }
}

enum AchievementID: String, CaseIterable, Codable {
    case firstEscape
    case tripleStar
    case fiveClears
    case flowCollector
    case themeUnlocked
    case eliteRunner
}

struct AchievementDefinition {
    let id: AchievementID
    let title: String
    let detail: String
}

final class AchievementStore {
    static let shared = AchievementStore()

    private let storageKey = "neonMazeAchievementUnlocks"
    private var unlocked: Set<String>

    private init() {
        unlocked = Set(UserDefaults.standard.stringArray(forKey: storageKey) ?? [])
    }

    private let definitions: [AchievementDefinition] = [
        AchievementDefinition(id: .firstEscape, title: "FIRST ESCAPE", detail: "Clear your first maze."),
        AchievementDefinition(id: .tripleStar, title: "TRIPLE STAR", detail: "Earn 3 stars on any level."),
        AchievementDefinition(id: .fiveClears, title: "FIVE DOWN", detail: "Finish 5 different levels."),
        AchievementDefinition(id: .flowCollector, title: "FLOW COLLECTOR", detail: "Collect 8 Flow Orbs total."),
        AchievementDefinition(id: .themeUnlocked, title: "THEME SHIFT", detail: "Unlock a new maze theme."),
        AchievementDefinition(id: .eliteRunner, title: "ELITE RUNNER", detail: "Earn 3 stars on 3 levels.")
    ]

    var totalCount: Int {
        definitions.count
    }

    var unlockedCount: Int {
        unlocked.count
    }

    func isUnlocked(_ id: AchievementID) -> Bool {
        unlocked.contains(id.rawValue)
    }

    func nextLockedAchievement() -> AchievementDefinition? {
        definitions.first { !isUnlocked($0.id) }
    }

    @discardableResult
    func evaluateLatestUnlocks() -> [AchievementDefinition] {
        var newUnlocks: [AchievementDefinition] = []
        for definition in definitions where !isUnlocked(definition.id) {
            guard shouldUnlock(definition.id) else { continue }
            unlocked.insert(definition.id.rawValue)
            newUnlocks.append(definition)
        }
        if !newUnlocks.isEmpty {
            UserDefaults.standard.set(Array(unlocked), forKey: storageKey)
        }
        return newUnlocks
    }

    private func shouldUnlock(_ id: AchievementID) -> Bool {
        switch id {
        case .firstEscape:
            return ProgressStore.shared.completedLevelCount >= 1
        case .tripleStar:
            return ProgressStore.shared.threeStarLevelCount >= 1
        case .fiveClears:
            return ProgressStore.shared.completedLevelCount >= 5
        case .flowCollector:
            return FlowProgress.shared.totalPoints >= 8
        case .themeUnlocked:
            return ThemeProgress.shared.unlockedCount >= 2
        case .eliteRunner:
            return ProgressStore.shared.threeStarLevelCount >= 3
        }
    }
}

func formattedTime(_ time: TimeInterval) -> String {
    let clamped = max(0, time)
    if clamped < 60 {
        return String(format: "%.2fs", clamped)
    }

    let totalSeconds = Int(clamped)
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return "\(minutes)min \(String(format: "%02ds", seconds))"
}

func leaderboardScoreForStoryTime(_ time: TimeInterval) -> Int {
    max(1, Int((max(0, time) * 100).rounded()))
}

enum GameRunMode: Equatable {
    case normal
    case timeChallenge(TimeChallengeDuration)
    case dailyChallenge(BotDifficulty)
}

enum TimeChallengeDuration: Int, CaseIterable, Codable {
    case oneMinute = 60
    case twoMinutes = 120
    case threeMinutes = 180

    var seconds: TimeInterval {
        TimeInterval(rawValue)
    }

    var title: String {
        switch self {
        case .oneMinute:
            return "1 MINUTE"
        case .twoMinutes:
            return "2 MINUTES"
        case .threeMinutes:
            return "3 MINUTES"
        }
    }

    var compactTitle: String {
        switch self {
        case .oneMinute:
            return "1 MIN"
        case .twoMinutes:
            return "2 MIN"
        case .threeMinutes:
            return "3 MIN"
        }
    }

    var hudTitle: String {
        "\(rawValue) SEC"
    }

    var countdownTitle: String {
        switch self {
        case .oneMinute:
            return "01:00"
        case .twoMinutes:
            return "02:00"
        case .threeMinutes:
            return "03:00"
        }
    }

    var storageKey: String {
        "\(rawValue)"
    }

    var summaryLine: String {
        switch self {
        case .oneMinute:
            return "FAST BURST · SMALL MAZES · HOT START"
        case .twoMinutes:
            return "BALANCED RUN · CLEAN FLOW · HARDER PUSH"
        case .threeMinutes:
            return "LONG CLIMB · HIGH PRESSURE · BEST FOR RECORDS"
        }
    }
}

final class ChallengeStore {
    static let shared = ChallengeStore()

    private let storageKey = "neonMazeChallengeRecords"
    private var records: [String: Int] = [:]

    private init() {
        records = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: Int] ?? [:]
    }

    func best(for duration: TimeChallengeDuration) -> Int {
        records[duration.storageKey] ?? 0
    }

    @discardableResult
    func register(duration: TimeChallengeDuration, completedMazes: Int) -> Bool {
        let key = duration.storageKey
        let current = records[key] ?? 0
        guard completedMazes > current else { return false }
        records[key] = completedMazes
        save()
        return true
    }

    private func save() {
        UserDefaults.standard.set(records, forKey: storageKey)
    }
}

private struct LeaderboardProfileState: Codable {
    var playerName: String?
    var submittedBest: [String: Int]
    var pendingBest: [String: Int]
    var pendingRenameFromName: String?
    var pendingRenameScopes: Set<String>
}

struct PendingLeaderboardSubmission: Sendable {
    let scope: LeaderboardScope
    let score: Int
    let previousName: String?
}

final class LeaderboardProfileStore {
    static let shared = LeaderboardProfileStore()

    static let maximumNameLength = 16

    private let storageKey = "neonMazeLeaderboardProfile"
    private var state = LeaderboardProfileState(
        playerName: nil,
        submittedBest: [:],
        pendingBest: [:],
        pendingRenameFromName: nil,
        pendingRenameScopes: []
    )

    private init() {
        guard let stored = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(LeaderboardProfileState.self, from: stored) else {
            return
        }
        state = decoded
    }

    var playerName: String? {
        state.playerName
    }

    func sanitize(name: String) -> String? {
        let collapsed = name
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let normalized = collapsed
            .replacingOccurrences(
                of: #"[^A-Za-z0-9 _\.-]"#,
                with: "",
                options: .regularExpression
            )
        let sanitized = String(normalized.prefix(Self.maximumNameLength))
        guard sanitized.count >= 2 else { return nil }
        let blockedNameParts = [
            "fuck", "shit", "bitch", "cunt", "nigger", "nigga", "fag", "faggot", "whore", "slut",
            "rape", "rapist", "hitler", "nazi", "terror", "kkk", "porn", "sex", "anal", "penis",
            "vagina", "dick", "cock", "pussy", "asshole", "motherfucker"
        ]
        let lower = sanitized.lowercased()
        guard !blockedNameParts.contains(where: { lower.contains($0) }) else { return nil }
        return sanitized
    }

    @discardableResult
    func setPlayerName(_ name: String) -> String? {
        guard let sanitized = sanitize(name: name) else { return nil }
        let previousName = state.playerName
        state.playerName = sanitized
        if previousName == nil || previousName != sanitized {
            for duration in TimeChallengeDuration.allCases {
                let best = ChallengeStore.shared.best(for: duration)
                guard best > 0 else { continue }
                let scope = LeaderboardScope.timeChallenge(duration)
                let key = scope.storageKey
                let current = state.pendingBest[key]
                if scope.isBetter(best, than: current) {
                    state.pendingBest[key] = best
                }
            }
            for level in LevelStore.levels {
                guard let bestTime = ProgressStore.shared.progress(for: level.id).bestTime else { continue }
                let score = leaderboardScoreForStoryTime(bestTime)
                let scope = LeaderboardScope.storyLevel(level.id)
                let key = scope.storageKey
                let current = state.pendingBest[key]
                if scope.isBetter(score, than: current) {
                    state.pendingBest[key] = score
                }
            }
            if let previousName, previousName != sanitized {
                state.pendingRenameFromName = previousName
                state.pendingRenameScopes = Set(state.submittedBest.keys)
            }
        }
        save()
        return sanitized
    }

    func registerNewLocalBest(scope: LeaderboardScope, score: Int) {
        let key = scope.storageKey
        let pending = state.pendingBest[key]
        if scope.isBetter(score, than: pending) {
            state.pendingBest[key] = score
            save()
        }
    }

    func pendingSubmission(for scope: LeaderboardScope) -> PendingLeaderboardSubmission? {
        let key = scope.storageKey
        let pending = state.pendingBest[key]
        let submitted = state.submittedBest[key]
        let needsImprovedScore = pending.map { scope.isBetter($0, than: submitted) } ?? false
        let needsRenameMigration = state.pendingRenameFromName != nil && state.pendingRenameScopes.contains(key)

        let scoreToSubmit: Int?
        if needsImprovedScore, let pending {
            scoreToSubmit = pending
        } else if needsRenameMigration {
            scoreToSubmit = pending ?? submitted
        } else {
            scoreToSubmit = nil
        }

        guard let scoreToSubmit else { return nil }
        return PendingLeaderboardSubmission(
            scope: scope,
            score: scoreToSubmit,
            previousName: needsRenameMigration ? state.pendingRenameFromName : nil
        )
    }

    func pendingSubmissions() -> [PendingLeaderboardSubmission] {
        var scopes = TimeChallengeDuration.allCases.map { LeaderboardScope.timeChallenge($0) }
        scopes += LevelStore.levels.map { LeaderboardScope.storyLevel($0.id) }
        return scopes.compactMap { pendingSubmission(for: $0) }
    }

    func markSubmitted(scope: LeaderboardScope, score: Int) {
        let key = scope.storageKey
        let previous = state.submittedBest[key]
        if scope.isBetter(score, than: previous) {
            state.submittedBest[key] = score
        }
        if let pending = state.pendingBest[key], !scope.isBetter(pending, than: score) {
            state.pendingBest.removeValue(forKey: key)
        }
        state.pendingRenameScopes.remove(key)
        if state.pendingRenameScopes.isEmpty {
            state.pendingRenameFromName = nil
        }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

struct DailyChallengeDescriptor {
    let dayKey: String
    let dayIndex: Int
    let displayDate: String
    let referenceLevelId: Int
    let config: LevelConfig
    let cacheLevelIndex: Int
    let easyReward: Int
    let hardReward: Int
}

private struct DailyChallengeProgress: Codable {
    var bestTime: Double?
    var easyClaimed: Bool
    var hardClaimed: Bool
}

struct DailyChallengeRegistration {
    let awardedCoins: Int
    let rewardClaimed: Bool
    let isNewBest: Bool
    let bestTime: TimeInterval?
}

final class DailyChallengeStore {
    static let shared = DailyChallengeStore()

    private let storageKey = "neonMazeDailyChallengeProgress"
    private let completionAnimationKey = "neonMazeDailyChallengeCompletionAnimations"
    private var progressByDay: [String: DailyChallengeProgress] = [:]
    private var shownCompletionAnimations: Set<String> = []

    private lazy var calendar: Calendar = {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }()

    private lazy var displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = .autoupdatingCurrent
        formatter.locale = Locale.autoupdatingCurrent
        formatter.dateFormat = "EEE d MMM"
        return formatter
    }()

    private init() {
        shownCompletionAnimations = Set(UserDefaults.standard.stringArray(forKey: completionAnimationKey) ?? [])
        guard let stored = UserDefaults.standard.data(forKey: storageKey) else { return }
        progressByDay = (try? JSONDecoder().decode([String: DailyChallengeProgress].self, from: stored)) ?? [:]
    }

    func currentDescriptor(date: Date = Date()) -> DailyChallengeDescriptor {
        let startOfDay = calendar.startOfDay(for: date)
        let dayIndex = Int(startOfDay.timeIntervalSince1970 / 86_400)
        let displayDate = displayFormatter.string(from: startOfDay).uppercased()
        let dayKey = dayKey(for: startOfDay)
        let referenceLevelId = dailyReferenceLevelId(for: dayIndex)
        return DailyChallengeDescriptor(
            dayKey: dayKey,
            dayIndex: dayIndex,
            displayDate: displayDate,
            referenceLevelId: referenceLevelId,
            config: makeDailyLevelConfig(dayIndex: dayIndex),
            cacheLevelIndex: 20_000 + dayIndex,
            easyReward: 60,
            hardReward: 140
        )
    }

    func progress(for descriptor: DailyChallengeDescriptor) -> (bestTime: TimeInterval?, easyClaimed: Bool, hardClaimed: Bool) {
        let progress = progressByDay[descriptor.dayKey] ?? DailyChallengeProgress(bestTime: nil, easyClaimed: false, hardClaimed: false)
        return (progress.bestTime, progress.easyClaimed, progress.hardClaimed)
    }

    func bestTime(for descriptor: DailyChallengeDescriptor) -> TimeInterval? {
        progressByDay[descriptor.dayKey]?.bestTime
    }

    func rewardAmount(for difficulty: BotDifficulty, descriptor: DailyChallengeDescriptor) -> Int {
        switch difficulty {
        case .easy:
            return descriptor.easyReward
        case .hard:
            return descriptor.hardReward
        case .off:
            return 0
        }
    }

    func isRewardClaimed(_ difficulty: BotDifficulty, for descriptor: DailyChallengeDescriptor) -> Bool {
        let progress = progressByDay[descriptor.dayKey] ?? DailyChallengeProgress(bestTime: nil, easyClaimed: false, hardClaimed: false)
        switch difficulty {
        case .easy:
            return progress.easyClaimed
        case .hard:
            return progress.hardClaimed
        case .off:
            return false
        }
    }

    func shouldAnimateCompletionReveal(_ difficulty: BotDifficulty, for descriptor: DailyChallengeDescriptor) -> Bool {
        guard isRewardClaimed(difficulty, for: descriptor) else { return false }
        return !shownCompletionAnimations.contains(completionAnimationToken(for: difficulty, descriptor: descriptor))
    }

    func markCompletionRevealShown(_ difficulty: BotDifficulty, for descriptor: DailyChallengeDescriptor) {
        let token = completionAnimationToken(for: difficulty, descriptor: descriptor)
        guard !shownCompletionAnimations.contains(token) else { return }
        shownCompletionAnimations.insert(token)
        UserDefaults.standard.set(Array(shownCompletionAnimations).sorted(), forKey: completionAnimationKey)
    }

    @discardableResult
    func registerWin(for descriptor: DailyChallengeDescriptor, difficulty: BotDifficulty, time: TimeInterval) -> DailyChallengeRegistration {
        var progress = progressByDay[descriptor.dayKey] ?? DailyChallengeProgress(bestTime: nil, easyClaimed: false, hardClaimed: false)
        let currentBest = progress.bestTime
        let isNewBest: Bool
        if let currentBest {
            isNewBest = time < currentBest
            progress.bestTime = min(currentBest, time)
        } else {
            isNewBest = true
            progress.bestTime = time
        }

        let awardedCoins: Int
        let rewardClaimed: Bool
        switch difficulty {
        case .easy:
            rewardClaimed = !progress.easyClaimed
            awardedCoins = rewardClaimed ? descriptor.easyReward : 0
            progress.easyClaimed = true
        case .hard:
            rewardClaimed = !progress.hardClaimed
            awardedCoins = rewardClaimed ? descriptor.hardReward : 0
            progress.hardClaimed = true
        case .off:
            rewardClaimed = false
            awardedCoins = 0
        }

        progressByDay[descriptor.dayKey] = progress
        save()
        if awardedCoins > 0 {
            CoinStore.shared.add(awardedCoins)
        }

        return DailyChallengeRegistration(
            awardedCoins: awardedCoins,
            rewardClaimed: rewardClaimed,
            isNewBest: isNewBest,
            bestTime: progress.bestTime
        )
    }

    private func dayKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        let day = components.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(progressByDay) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    private func completionAnimationToken(for difficulty: BotDifficulty, descriptor: DailyChallengeDescriptor) -> String {
        "\(descriptor.dayKey)#\(difficulty.rawValue)"
    }
}

final class CoinStore {
    static let shared = CoinStore()

    private let storageKey = "neonMazeCoinTotal"
    private(set) var totalCoins: Int

    private init() {
        totalCoins = max(0, UserDefaults.standard.integer(forKey: storageKey))
    }

    func add(_ amount: Int) {
        guard amount > 0 else { return }
        totalCoins += amount
        save()
    }

    @discardableResult
    func spend(_ amount: Int) -> Bool {
        guard amount > 0, totalCoins >= amount else { return false }
        totalCoins -= amount
        save()
        return true
    }

    private func save() {
        UserDefaults.standard.set(totalCoins, forKey: storageKey)
    }
}

enum AdInterstitialContext: String, Codable {
    case story
    case timeChallenge
}

enum AdPresentationResult {
    case shown
    case unavailable
    case failed
}

enum RewardedAdPresentationResult {
    case rewarded
    case unavailable
    case failed
    case dismissed
}

enum RewardedShopAdOutcome {
    case rewarded(coins: Int)
    case unavailable
    case failed
    case dismissed
    case limitReached
}

private struct AdProgressState: Codable {
    var storyCompletedRuns: Int
    var storyInterstitialPending: Bool
    var challengeCompletedRuns: Int
    var challengeInterstitialPending: Bool
    var rewardedDayKey: String
    var rewardedClaimsUsed: Int

    static let empty = AdProgressState(
        storyCompletedRuns: 0,
        storyInterstitialPending: false,
        challengeCompletedRuns: 0,
        challengeInterstitialPending: false,
        rewardedDayKey: "",
        rewardedClaimsUsed: 0
    )
}

#if os(iOS) || os(tvOS)
private protocol AdPresenting: AnyObject {
    func configure()
    func preloadInterstitial()
    func preloadRewarded()
    func presentInterstitial(from presenter: UIViewController, context: AdInterstitialContext, completion: @escaping (AdPresentationResult) -> Void)
    func presentRewarded(from presenter: UIViewController, completion: @escaping (RewardedAdPresentationResult) -> Void)
}

private final class UnavailableAdPresenter: AdPresenting {
    func configure() {}
    func preloadInterstitial() {}
    func preloadRewarded() {}

    func presentInterstitial(from presenter: UIViewController, context: AdInterstitialContext, completion: @escaping (AdPresentationResult) -> Void) {
        completion(.unavailable)
    }

    func presentRewarded(from presenter: UIViewController, completion: @escaping (RewardedAdPresentationResult) -> Void) {
        completion(.unavailable)
    }
}

#if canImport(GoogleMobileAds)
private enum AdMobConfig {
    private static let sampleAppID = "ca-app-pub-3940256099942544~1458002511"
    private static let sampleInterstitialUnitID = "ca-app-pub-3940256099942544/4411468910"
    private static let sampleRewardedUnitID = "ca-app-pub-3940256099942544/1712485313"

    static var appID: String? {
        bundleValue(for: "GADApplicationIdentifier") ?? debugFallback(sampleAppID)
    }

    static var hasValidIdentifiers: Bool {
        guard let appID,
              let storyInterstitialUnitID = interstitialUnitID(for: .story),
              let timeChallengeInterstitialUnitID = interstitialUnitID(for: .timeChallenge),
              let rewardedUnitID
        else {
            return false
        }

        let values = [appID, storyInterstitialUnitID, timeChallengeInterstitialUnitID, rewardedUnitID]
        let sampleValues = [sampleAppID, sampleInterstitialUnitID, sampleRewardedUnitID]
        return values.allSatisfy { !sampleValues.contains($0) }
    }

    static func interstitialUnitID(for context: AdInterstitialContext) -> String? {
        switch context {
        case .story:
            return bundleValue(for: "MazeDashStoryInterstitialAdUnitID") ?? debugFallback(sampleInterstitialUnitID)
        case .timeChallenge:
            return bundleValue(for: "MazeDashTimeChallengeInterstitialAdUnitID") ?? debugFallback(sampleInterstitialUnitID)
        }
    }

    static var rewardedUnitID: String? {
        bundleValue(for: "MazeDashRewardedAdUnitID") ?? debugFallback(sampleRewardedUnitID)
    }

    private static func bundleValue(for key: String) -> String? {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
    }

    private static func debugFallback(_ sampleValue: String) -> String? {
        #if DEBUG
        sampleValue
        #else
        nil
        #endif
    }
}

private final class GoogleMobileAdsPresenter: NSObject, AdPresenting {
    private enum ActivePlacement {
        case interstitial(AdInterstitialContext)
        case rewarded
    }

    private var isConfigured = false
    private var interstitialAds: [AdInterstitialContext: InterstitialAd] = [:]
    private var interstitialLoadsInFlight: Set<AdInterstitialContext> = []
    private var rewardedAd: RewardedAd?
    private var rewardedLoadInFlight = false

    private var activePlacement: ActivePlacement?
    private var interstitialCompletion: ((AdPresentationResult) -> Void)?
    private var rewardedCompletion: ((RewardedAdPresentationResult) -> Void)?
    private var rewardedEarned = false
    private var hasStartedSDK = false

    func configure() {
        guard !isConfigured else { return }
        isConfigured = true
        startSDKIfNeeded()
    }

    func preloadInterstitial() {
        preloadInterstitial(for: .story)
        preloadInterstitial(for: .timeChallenge)
    }

    func preloadRewarded() {
        guard rewardedAd == nil, !rewardedLoadInFlight else { return }
        guard let rewardedUnitID = AdMobConfig.rewardedUnitID else { return }
        rewardedLoadInFlight = true
        RewardedAd.load(with: rewardedUnitID, request: Request()) { [weak self] ad, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.rewardedLoadInFlight = false
                guard let ad else { return }
                ad.fullScreenContentDelegate = self
                self.rewardedAd = ad
            }
        }
    }

    func presentInterstitial(from presenter: UIViewController, context: AdInterstitialContext, completion: @escaping (AdPresentationResult) -> Void) {
        guard activePlacement == nil else {
            completion(.failed)
            return
        }
        guard presenter.presentedViewController == nil else {
            completion(.failed)
            return
        }
        guard let ad = interstitialAds.removeValue(forKey: context) else {
            preloadInterstitial(for: context)
            completion(.unavailable)
            return
        }

        activePlacement = .interstitial(context)
        interstitialCompletion = completion
        ad.fullScreenContentDelegate = self
        ad.present(from: presenter)
        preloadInterstitial(for: context)
    }

    func presentRewarded(from presenter: UIViewController, completion: @escaping (RewardedAdPresentationResult) -> Void) {
        guard activePlacement == nil else {
            completion(.failed)
            return
        }
        guard presenter.presentedViewController == nil else {
            completion(.failed)
            return
        }
        guard let ad = rewardedAd else {
            preloadRewarded()
            completion(.unavailable)
            return
        }

        rewardedAd = nil
        rewardedEarned = false
        activePlacement = .rewarded
        rewardedCompletion = completion
        ad.fullScreenContentDelegate = self
        ad.present(from: presenter) { [weak self] in
            self?.rewardedEarned = true
        }
        preloadRewarded()
    }

    private func preloadInterstitial(for context: AdInterstitialContext) {
        guard interstitialAds[context] == nil, !interstitialLoadsInFlight.contains(context) else { return }
        guard let unitID = AdMobConfig.interstitialUnitID(for: context) else { return }
        interstitialLoadsInFlight.insert(context)
        InterstitialAd.load(with: unitID, request: Request()) { [weak self] ad, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.interstitialLoadsInFlight.remove(context)
                guard let ad else { return }
                ad.fullScreenContentDelegate = self
                self.interstitialAds[context] = ad
            }
        }
    }

    private func startSDKIfNeeded() {
        guard !hasStartedSDK else { return }
        hasStartedSDK = true
        MobileAds.shared.start(completionHandler: nil)
    }
}

extension GoogleMobileAdsPresenter: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        switch activePlacement {
        case let .interstitial(context):
            activePlacement = nil
            let completion = interstitialCompletion
            interstitialCompletion = nil
            preloadInterstitial(for: context)
            completion?(.shown)
        case .rewarded:
            activePlacement = nil
            let completion = rewardedCompletion
            rewardedCompletion = nil
            let outcome: RewardedAdPresentationResult = rewardedEarned ? .rewarded : .dismissed
            rewardedEarned = false
            preloadRewarded()
            completion?(outcome)
        case nil:
            break
        }
    }

    func ad(_ ad: any FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: any Error) {
        switch activePlacement {
        case let .interstitial(context):
            activePlacement = nil
            let completion = interstitialCompletion
            interstitialCompletion = nil
            preloadInterstitial(for: context)
            completion?(.failed)
        case .rewarded:
            activePlacement = nil
            let completion = rewardedCompletion
            rewardedCompletion = nil
            rewardedEarned = false
            preloadRewarded()
            completion?(.failed)
        case nil:
            break
        }
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}

#elseif DEBUG
private final class DebugAdPresenter: AdPresenting {
    func configure() {}
    func preloadInterstitial() {}
    func preloadRewarded() {}

    func presentInterstitial(from presenter: UIViewController, context: AdInterstitialContext, completion: @escaping (AdPresentationResult) -> Void) {
        guard presenter.presentedViewController == nil else {
            completion(.failed)
            return
        }

        let title = context == .story ? "SIMULATED STORY AD" : "SIMULATED TIME AD"
        let message = context == .story
            ? "Debug interstitial at a natural Story transition."
            : "Debug interstitial after a completed Time Challenge run."
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Close Ad", style: .default) { _ in
            completion(.shown)
        })
        presenter.present(alert, animated: true)
    }

    func presentRewarded(from presenter: UIViewController, completion: @escaping (RewardedAdPresentationResult) -> Void) {
        guard presenter.presentedViewController == nil else {
            completion(.failed)
            return
        }

        let alert = UIAlertController(
            title: "SIMULATED REWARDED AD",
            message: "Grant the 30-coin reward only when this full ad flow completes.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Complete Ad", style: .default) { _ in
            completion(.rewarded)
        })
        alert.addAction(UIAlertAction(title: "Close Early", style: .cancel) { _ in
            completion(.dismissed)
        })
        presenter.present(alert, animated: true)
    }
}
#endif

final class AdService {
    static let shared = AdService()

    static let adStateDidChangeNotification = Notification.Name("MazeDashAdStateDidChange")

    private let storageKey = "mazeDashAdProgressState"
    private let completionsPerInterstitial = 5
    private let rewardedCoinAmount = 30
    private let rewardedDailyLimit = 2

    private let defaults = UserDefaults.standard
    private var state: AdProgressState
    private var didConfigure = false
    private var consentFlowCompleted = false
    private var consentFlowInProgress = false

    private lazy var calendar: Calendar = {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }()

    private let presenter: AdPresenting = {
        #if canImport(GoogleMobileAds)
        #if DEBUG
        GoogleMobileAdsPresenter() as AdPresenting
        #else
        if AdMobConfig.hasValidIdentifiers {
            return GoogleMobileAdsPresenter() as AdPresenting
        }
        return UnavailableAdPresenter() as AdPresenting
        #endif
        #elseif DEBUG
        DebugAdPresenter() as AdPresenting
        #else
        UnavailableAdPresenter() as AdPresenting
        #endif
    }()

    private init() {
        if let stored = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(AdProgressState.self, from: stored) {
            state = decoded
        } else {
            state = .empty
        }
        refreshRewardedDayIfNeeded()
    }

    func configureIfNeeded() {
        guard !didConfigure else { return }
        guard canConfigureAds else { return }
        didConfigure = true
        presenter.configure()
        presenter.preloadInterstitial()
        presenter.preloadRewarded()
    }

    func requestConsentAndConfigureIfNeeded() {
        #if os(iOS)
        #if canImport(GoogleUserMessagingPlatform)
        guard !consentFlowInProgress else { return }
        if consentFlowCompleted {
            configureIfNeeded()
            return
        }

        consentFlowInProgress = true
        let parameters = RequestParameters()
        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                ConsentForm.loadAndPresentIfRequired(from: self.topViewController()) { [weak self] _ in
                    DispatchQueue.main.async {
                        guard let self else { return }
                        self.consentFlowInProgress = false
                        self.consentFlowCompleted = true
                        self.configureIfNeeded()
                    }
                }
            }
        }
        #else
        configureIfNeeded()
        #endif
        #else
        configureIfNeeded()
        #endif
    }

    private var canConfigureAds: Bool {
        #if canImport(GoogleUserMessagingPlatform)
        return consentFlowCompleted && ConsentInformation.shared.canRequestAds
        #else
        return true
        #endif
    }

    func registerCompletedStoryRun() {
        configureIfNeeded()
        refreshRewardedDayIfNeeded()
        state.storyCompletedRuns += 1
        if state.storyCompletedRuns >= completionsPerInterstitial {
            state.storyInterstitialPending = true
        }
        save()
        presenter.preloadInterstitial()
    }

    func registerCompletedTimeChallengeRun() {
        configureIfNeeded()
        refreshRewardedDayIfNeeded()
        state.challengeCompletedRuns += 1
        if state.challengeCompletedRuns >= completionsPerInterstitial {
            state.challengeInterstitialPending = true
        }
        save()
        presenter.preloadInterstitial()
    }

    func presentInterstitialIfDue(
        for context: AdInterstitialContext,
        from presenterViewController: UIViewController?,
        completion: @escaping () -> Void
    ) {
        configureIfNeeded()
        refreshRewardedDayIfNeeded()
        guard isInterstitialDue(for: context) else {
            completion()
            return
        }
        guard let presenterViewController = presenterViewController ?? topViewController() else {
            completion()
            return
        }

        presenter.presentInterstitial(from: presenterViewController, context: context) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else {
                    completion()
                    return
                }
                if result == .shown {
                    self.consumeInterstitial(for: context)
                } else {
                    self.presenter.preloadInterstitial()
                }
                completion()
            }
        }
    }

    func requestRewardedShopCoins(
        from presenterViewController: UIViewController?,
        completion: @escaping (RewardedShopAdOutcome) -> Void
    ) {
        configureIfNeeded()
        refreshRewardedDayIfNeeded()
        guard remainingRewardedClaimsToday > 0 else {
            completion(.limitReached)
            return
        }
        guard let presenterViewController = presenterViewController ?? topViewController() else {
            completion(.unavailable)
            return
        }

        presenter.presentRewarded(from: presenterViewController) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else {
                    completion(.failed)
                    return
                }

                switch result {
                case .rewarded:
                    self.refreshRewardedDayIfNeeded()
                    guard self.remainingRewardedClaimsToday > 0 else {
                        completion(.limitReached)
                        return
                    }
                    self.state.rewardedClaimsUsed += 1
                    self.save()
                    CoinStore.shared.add(self.rewardedCoinAmount)
                    self.presenter.preloadRewarded()
                    completion(.rewarded(coins: self.rewardedCoinAmount))
                case .unavailable:
                    self.presenter.preloadRewarded()
                    completion(.unavailable)
                case .failed:
                    self.presenter.preloadRewarded()
                    completion(.failed)
                case .dismissed:
                    self.presenter.preloadRewarded()
                    completion(.dismissed)
                }
            }
        }
    }

    var remainingRewardedClaimsToday: Int {
        refreshRewardedDayIfNeeded()
        return max(0, rewardedDailyLimit - state.rewardedClaimsUsed)
    }

    var rewardedAvailabilityText: String {
        "\(remainingRewardedClaimsToday)/\(rewardedDailyLimit) AVAILABLE"
    }

    func isInterstitialDue(for context: AdInterstitialContext) -> Bool {
        switch context {
        case .story:
            return state.storyInterstitialPending
        case .timeChallenge:
            return state.challengeInterstitialPending
        }
    }

    private func consumeInterstitial(for context: AdInterstitialContext) {
        switch context {
        case .story:
            state.storyCompletedRuns = 0
            state.storyInterstitialPending = false
        case .timeChallenge:
            state.challengeCompletedRuns = 0
            state.challengeInterstitialPending = false
        }
        save()
        presenter.preloadInterstitial()
    }

    private func refreshRewardedDayIfNeeded() {
        let dayKey = currentDayKey()
        guard state.rewardedDayKey != dayKey else { return }
        state.rewardedDayKey = dayKey
        state.rewardedClaimsUsed = 0
        save()
    }

    private func currentDayKey() -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", components.year ?? 1970, components.month ?? 1, components.day ?? 1)
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(state) {
            defaults.set(encoded, forKey: storageKey)
        }
        NotificationCenter.default.post(name: Self.adStateDidChangeNotification, object: nil)
    }

    private func topViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController
        return topMostViewController(from: root)
    }

    private func topMostViewController(from root: UIViewController?) -> UIViewController? {
        if let navigation = root as? UINavigationController {
            return topMostViewController(from: navigation.visibleViewController)
        }
        if let tab = root as? UITabBarController {
            return topMostViewController(from: tab.selectedViewController)
        }
        if let presented = root?.presentedViewController {
            return topMostViewController(from: presented)
        }
        return root
    }
}
#endif

enum CosmeticCategory: String, CaseIterable, Codable {
    case player
    case trail
    case winAnimation
    case teleporter

    var title: String {
        switch self {
        case .player:
            return "PLAYER"
        case .trail:
            return "TRAILS"
        case .winAnimation:
            return "WIN FX"
        case .teleporter:
            return "PORTALS"
        }
    }
}

enum PlayerSkinKind: String, Codable {
    case color
    case pattern

    var title: String {
        switch self {
        case .color:
            return "COLORS"
        case .pattern:
            return "PATTERNS"
        }
    }
}

enum ShopPurchaseResult {
    case purchased
    case selected
    case alreadySelected
    case insufficientCoins
    case rewardOnly
}

enum PlayerSkin: String, CaseIterable, Codable {
    case neonCyan
    case neonPink
    case electricPurple
    case toxicGreen
    case goldenPulse
    case voidCore
    case gridCore
    case pulseCore
    case glitchSkin
    case energyStripes
    case dualCore
    case quantumFracture

    static var shopCases: [PlayerSkin] {
        [
            .neonCyan,
            .neonPink,
            .toxicGreen,
            .electricPurple,
            .goldenPulse,
            .voidCore,
            .gridCore,
            .energyStripes,
            .pulseCore,
            .glitchSkin,
            .quantumFracture,
            .dualCore
        ]
    }

    var kind: PlayerSkinKind {
        switch self {
        case .neonCyan, .neonPink, .electricPurple, .toxicGreen, .goldenPulse, .voidCore:
            return .color
        case .gridCore, .pulseCore, .glitchSkin, .energyStripes, .dualCore, .quantumFracture:
            return .pattern
        }
    }

    var displayName: String {
        switch self {
        case .neonCyan:
            return "Neon Cyan"
        case .neonPink:
            return "Hot Pink"
        case .electricPurple:
            return "Electric Purple"
        case .toxicGreen:
            return "Toxic Lime"
        case .goldenPulse:
            return "Gilded Pulse"
        case .voidCore:
            return "Void Core"
        case .gridCore:
            return "Grid Core"
        case .pulseCore:
            return "Pulse Core"
        case .glitchSkin:
            return "Data Blocks"
        case .energyStripes:
            return "Energy Stripes"
        case .dualCore:
            return "Neural Grid"
        case .quantumFracture:
            return "Quantum Fracture"
        }
    }

    var detail: String {
        switch self {
        case .neonCyan:
            return "Clean Core Glow"
        case .neonPink:
            return "Sharp Neon Bloom"
        case .electricPurple:
            return "Deep Violet Charge"
        case .toxicGreen:
            return "Electric Acid Pulse"
        case .goldenPulse:
            return "Gold Voltage Flow"
        case .voidCore:
            return "Dark Energy Sink"
        case .gridCore:
            return "Clean Data Grid"
        case .pulseCore:
            return "Inner Pulse Light"
        case .glitchSkin:
            return "Broken Pixel Drift"
        case .energyStripes:
            return "Charged Line Flow"
        case .dualCore:
            return "Living Signal Web"
        case .quantumFracture:
            return "Split Reality Grid"
        }
    }

    var price: Int? {
        switch self {
        case .neonCyan:
            return 50
        case .neonPink:
            return 70
        case .electricPurple:
            return 120
        case .toxicGreen:
            return 90
        case .goldenPulse:
            return 500
        case .voidCore:
            return 700
        case .gridCore:
            return 80
        case .energyStripes:
            return 120
        case .pulseCore:
            return 140
        case .glitchSkin:
            return 160
        case .quantumFracture:
            return 600
        case .dualCore:
            return 800
        }
    }

    var rewardLevel: Int? {
        nil
    }

    var tintColor: SKColor { baseColor }

    var baseColor: SKColor {
        switch self {
        case .neonCyan:
            return SKColor(hex: 0x00D4FF)
        case .neonPink:
            return SKColor(hex: 0xFF2D9A)
        case .electricPurple:
            return SKColor(hex: 0xA855F7)
        case .toxicGreen:
            return SKColor(hex: 0x39FF14)
        case .goldenPulse:
            return SKColor(hex: 0xFFD84D)
        case .voidCore:
            return SKColor(hex: 0x1A1824)
        case .gridCore:
            return SKColor(hex: 0x00D4FF)
        case .pulseCore:
            return SKColor(hex: 0xFF2D9A)
        case .glitchSkin:
            return SKColor(hex: 0xA855F7)
        case .energyStripes:
            return SKColor(hex: 0x39FF14)
        case .dualCore:
            return SKColor(hex: 0x3FE7FF)
        case .quantumFracture:
            return SKColor(hex: 0x7A5CFF)
        }
    }

    var highlightColor: SKColor {
        switch self {
        case .neonCyan:
            return SKColor(hex: 0x66F2FF)
        case .neonPink:
            return SKColor(hex: 0xFF6BC1)
        case .electricPurple:
            return SKColor(hex: 0xD8B4FE)
        case .toxicGreen:
            return SKColor(hex: 0x8CFF7A)
        case .goldenPulse:
            return SKColor(hex: 0xFFF2A6)
        case .voidCore:
            return SKColor(hex: 0x74F7FF)
        case .gridCore:
            return SKColor(hex: 0x66F2FF)
        case .pulseCore:
            return SKColor(hex: 0xFF9DD8)
        case .glitchSkin:
            return SKColor(hex: 0xF0C3FF)
        case .energyStripes:
            return SKColor(hex: 0x9FFF7D)
        case .dualCore:
            return SKColor(hex: 0xC8FBFF)
        case .quantumFracture:
            return SKColor(hex: 0xE6D7FF)
        }
    }

    var deepColor: SKColor {
        switch self {
        case .neonCyan:
            return SKColor(hex: 0x0099CC)
        case .neonPink:
            return SKColor(hex: 0xC21874)
        case .electricPurple:
            return SKColor(hex: 0x7E22CE)
        case .toxicGreen:
            return SKColor(hex: 0x1FAF00)
        case .goldenPulse:
            return SKColor(hex: 0xFFB800)
        case .voidCore:
            return SKColor(hex: 0x05070D)
        case .gridCore:
            return SKColor(hex: 0x00708E)
        case .pulseCore:
            return SKColor(hex: 0xAD125F)
        case .glitchSkin:
            return SKColor(hex: 0x5E2B9C)
        case .energyStripes:
            return SKColor(hex: 0x168300)
        case .dualCore:
            return SKColor(hex: 0x0F5D77)
        case .quantumFracture:
            return SKColor(hex: 0x24144C)
        }
    }

    var accentColor: SKColor {
        switch self {
        case .goldenPulse:
            return ArcadeStyle.Color.accentYellow
        case .voidCore:
            return SKColor(hex: 0x7BF3FF)
        case .neonPink, .pulseCore:
            return ArcadeStyle.Color.accentMagenta
        case .dualCore:
            return SKColor(hex: 0x7BF3FF)
        case .quantumFracture:
            return SKColor(hex: 0xB691FF)
        default:
            return baseColor
        }
    }
}

enum TrailStyle: String, CaseIterable, Codable {
    case classicNeon
    case smoothLight
    case electricSparks
    case pixelTrail
    case pulseTrail
    case energyBurst
    case orbitTrail
    case phaseStream

    static var shopCases: [TrailStyle] {
        [
            .classicNeon,
            .smoothLight,
            .pixelTrail,
            .electricSparks,
            .orbitTrail,
            .phaseStream
        ]
    }

    var displayName: String {
        switch self {
        case .classicNeon:
            return "Classic Neon"
        case .smoothLight:
            return "Smooth Light"
        case .electricSparks:
            return "Electric Sparks"
        case .pixelTrail:
            return "Pixel Trail"
        case .pulseTrail:
            return "Smooth Light"
        case .energyBurst:
            return "Phase Stream"
        case .orbitTrail:
            return "Orbit Trail"
        case .phaseStream:
            return "Phase Stream"
        }
    }

    var detail: String {
        switch self {
        case .classicNeon:
            return "Clean Light Trace"
        case .smoothLight:
            return "Soft Motion Glow"
        case .electricSparks:
            return "Static Arc Scatter"
        case .pixelTrail:
            return "Pixel Dust Wake"
        case .pulseTrail:
            return "Soft Motion Glow"
        case .energyBurst:
            return "Shifted Motion Stream"
        case .orbitTrail:
            return "Rotating Light Wake"
        case .phaseStream:
            return "Shifted Motion Stream"
        }
    }

    var price: Int? {
        switch self {
        case .classicNeon:
            return 60
        case .smoothLight:
            return 90
        case .electricSparks:
            return 160
        case .pixelTrail:
            return 130
        case .pulseTrail:
            return nil
        case .energyBurst:
            return nil
        case .orbitTrail:
            return 500
        case .phaseStream:
            return 750
        }
    }

    var rewardLevel: Int? {
        nil
    }

    var accentColor: SKColor {
        switch self {
        case .classicNeon:
            return ArcadeStyle.Color.accentCyan
        case .smoothLight:
            return SKColor(hex: 0xA6F7FF)
        case .electricSparks:
            return ArcadeStyle.Color.accentYellow
        case .pixelTrail:
            return ArcadeStyle.Color.accentMagenta
        case .pulseTrail:
            return SKColor(hex: 0xA6F7FF)
        case .energyBurst:
            return SKColor(hex: 0xB691FF)
        case .orbitTrail:
            return SKColor(hex: 0xB691FF)
        case .phaseStream:
            return SKColor(hex: 0x9A8CFF)
        }
    }
}

enum WinAnimationStyle: String, CaseIterable, Codable {
    case neonExplosion
    case energyImplosion
    case pixelShatter
    case shockwaveRing
    case lightBeamFinish
    case timeFreezeShatter

    static var shopCases: [WinAnimationStyle] {
        [
            .neonExplosion,
            .shockwaveRing,
            .pixelShatter,
            .lightBeamFinish,
            .energyImplosion,
            .timeFreezeShatter
        ]
    }

    var displayName: String {
        switch self {
        case .neonExplosion:
            return "Neon Burst"
        case .energyImplosion:
            return "Supernova Collapse"
        case .pixelShatter:
            return "Pixel Break"
        case .shockwaveRing:
            return "Shockwave Ring"
        case .lightBeamFinish:
            return "Light Beam Finish"
        case .timeFreezeShatter:
            return "Time Freeze Shatter"
        }
    }

    var detail: String {
        switch self {
        case .neonExplosion:
            return "Fast Finish Burst"
        case .energyImplosion:
            return "Collapse Into Light"
        case .pixelShatter:
            return "Digital Break Flash"
        case .shockwaveRing:
            return "Ring Impact Pulse"
        case .lightBeamFinish:
            return "Vertical Exit Beam"
        case .timeFreezeShatter:
            return "Frozen World Break"
        }
    }

    var price: Int? {
        switch self {
        case .neonExplosion:
            return 100
        case .energyImplosion:
            return 600
        case .pixelShatter:
            return 180
        case .shockwaveRing:
            return 140
        case .lightBeamFinish:
            return 220
        case .timeFreezeShatter:
            return 900
        }
    }

    var rewardLevel: Int? {
        nil
    }

    var accentColor: SKColor {
        switch self {
        case .neonExplosion:
            return ArcadeStyle.Color.accentMagenta
        case .energyImplosion:
            return ArcadeStyle.Color.accentCyan
        case .pixelShatter:
            return ArcadeStyle.Color.accentYellow
        case .shockwaveRing:
            return SKColor(hex: 0x66F2FF)
        case .lightBeamFinish:
            return SKColor(hex: 0xFFF2A6)
        case .timeFreezeShatter:
            return SKColor(hex: 0xB8F4FF)
        }
    }
}

enum TeleporterSkinStyle: String, CaseIterable, Codable {
    case classicPortal
    case digitalGlitchPortal
    case energyVortex
    case splitPortal
    case quantumPortal

    var displayName: String {
        switch self {
        case .classicPortal:
            return "CLASSIC PORTAL"
        case .digitalGlitchPortal:
            return "DIGITAL GLITCH"
        case .energyVortex:
            return "ENERGY VORTEX"
        case .splitPortal:
            return "SPLIT PORTAL"
        case .quantumPortal:
            return "QUANTUM PORTAL"
        }
    }

    var detail: String {
        switch self {
        case .classicPortal:
            return "PURE CLEAN RING"
        case .digitalGlitchPortal:
            return "CONTROLLED DATA FLICKER"
        case .energyVortex:
            return "ROTATING ENERGY CORE"
        case .splitPortal:
            return "SEGMENTED ARC GATE"
        case .quantumPortal:
            return "PARTICLE-DRIVEN WARP FIELD"
        }
    }

    var price: Int? {
        switch self {
        case .classicPortal:
            return 0
        case .digitalGlitchPortal:
            return 72
        case .energyVortex:
            return 88
        case .splitPortal:
            return 104
        case .quantumPortal:
            return nil
        }
    }

    var rewardLevel: Int? {
        self == .quantumPortal ? 25 : nil
    }

    var accentColor: SKColor {
        switch self {
        case .classicPortal:
            return ArcadeStyle.Color.accentCyan
        case .digitalGlitchPortal:
            return ArcadeStyle.Color.accentMagenta
        case .energyVortex:
            return SKColor(hex: 0x7BF3FF)
        case .splitPortal:
            return SKColor(hex: 0xFFB1EB)
        case .quantumPortal:
            return SKColor(hex: 0xFFF2A6)
        }
    }
}

enum ShopTab: String, CaseIterable, Codable {
    case playerColors
    case playerPatterns
    case trails
    case winAnimations

    var title: String {
        switch self {
        case .playerColors:
            return "COLORS"
        case .playerPatterns:
            return "PATTERNS"
        case .trails:
            return "TRAILS"
        case .winAnimations:
            return "WIN FX"
        }
    }
}

enum ShopItem: Hashable {
    case player(PlayerSkin)
    case trail(TrailStyle)
    case win(WinAnimationStyle)
    case teleporter(TeleporterSkinStyle)

    var displayName: String {
        switch self {
        case let .player(item):
            return item.displayName
        case let .trail(item):
            return item.displayName
        case let .win(item):
            return item.displayName
        case let .teleporter(item):
            return item.displayName
        }
    }

    var detail: String {
        switch self {
        case let .player(item):
            return item.detail
        case let .trail(item):
            return item.detail
        case let .win(item):
            return item.detail
        case let .teleporter(item):
            return item.detail
        }
    }

    var accentColor: SKColor {
        switch self {
        case let .player(item):
            return item.accentColor
        case let .trail(item):
            return item.accentColor
        case let .win(item):
            return item.accentColor
        case let .teleporter(item):
            return item.accentColor
        }
    }

    var price: Int? {
        switch self {
        case let .player(item):
            return item.price
        case let .trail(item):
            return item.price
        case let .win(item):
            return item.price
        case let .teleporter(item):
            return item.price
        }
    }

    var rewardLevel: Int? {
        switch self {
        case let .player(item):
            return item.rewardLevel
        case let .trail(item):
            return item.rewardLevel
        case let .win(item):
            return item.rewardLevel
        case let .teleporter(item):
            return item.rewardLevel
        }
    }

    var shopTab: ShopTab {
        switch self {
        case let .player(item):
            return item.kind == .color ? .playerColors : .playerPatterns
        case .trail:
            return .trails
        case .win:
            return .winAnimations
        case .teleporter:
            return .winAnimations
        }
    }
}

struct StoryCosmeticReward {
    let milestoneLevel: Int
    let item: ShopItem
    let title: String
    let detail: String

    static func reward(for level: Int) -> StoryCosmeticReward? {
        switch level {
        case 10:
            return StoryCosmeticReward(
                milestoneLevel: 10,
                item: .player(.neonPink),
                title: "COLOR UNLOCKED",
                detail: "HOT PINK DROPS INTO YOUR LOADOUT."
            )
        case 20:
            return StoryCosmeticReward(
                milestoneLevel: 20,
                item: .player(.gridCore),
                title: "PATTERN UNLOCKED",
                detail: "GRID CORE IS NOW YOURS."
            )
        case 30:
            return StoryCosmeticReward(
                milestoneLevel: 30,
                item: .trail(.smoothLight),
                title: "TRAIL UNLOCKED",
                detail: "SMOOTH LIGHT JOINS YOUR RUN."
            )
        case 40:
            return StoryCosmeticReward(
                milestoneLevel: 40,
                item: .win(.shockwaveRing),
                title: "WIN FX UNLOCKED",
                detail: "SHOCKWAVE RING IS READY FOR FINISHES."
            )
        case 50:
            return StoryCosmeticReward(
                milestoneLevel: 50,
                item: .player(.toxicGreen),
                title: "COLOR UNLOCKED",
                detail: "TOXIC LIME HITS THE INVENTORY."
            )
        case 60:
            return StoryCosmeticReward(
                milestoneLevel: 60,
                item: .player(.glitchSkin),
                title: "PATTERN UNLOCKED",
                detail: "DATA BLOCKS BREAK INTO YOUR LOADOUT."
            )
        case 70:
            return StoryCosmeticReward(
                milestoneLevel: 70,
                item: .trail(.electricSparks),
                title: "TRAIL UNLOCKED",
                detail: "ELECTRIC SPARKS STARTS THROWING STATIC."
            )
        case 80:
            return StoryCosmeticReward(
                milestoneLevel: 80,
                item: .player(.goldenPulse),
                title: "PREMIUM COLOR UNLOCKED",
                detail: "GILDED PULSE LANDED FOR FREE."
            )
        case 90:
            return StoryCosmeticReward(
                milestoneLevel: 90,
                item: .player(.quantumFracture),
                title: "PREMIUM PATTERN UNLOCKED",
                detail: "QUANTUM FRACTURE SHIFTS INTO PLACE."
            )
        case 100:
            return StoryCosmeticReward(
                milestoneLevel: 100,
                item: .win(.timeFreezeShatter),
                title: "PREMIUM WIN FX UNLOCKED",
                detail: "TIME FREEZE SHATTER NOW CLOSES THE STORY."
            )
        default:
            return nil
        }
    }
}

struct StoryRewardUnlock {
    let reward: StoryCosmeticReward
    let wasAlreadyOwned: Bool
}

final class CosmeticsStore {
    static let shared = CosmeticsStore()

    private let ownedPlayerKey = "neonMazeOwnedPlayerCosmetics"
    private let equippedPlayerKey = "neonMazeEquippedPlayerCosmetic"
    private let ownedTrailKey = "neonMazeOwnedTrailCosmetics"
    private let equippedTrailKey = "neonMazeEquippedTrailCosmetic"
    private let ownedWinKey = "neonMazeOwnedWinCosmetics"
    private let equippedWinKey = "neonMazeEquippedWinCosmetic"
    private let ownedTeleporterKey = "neonMazeOwnedTeleporterCosmetics"
    private let equippedTeleporterKey = "neonMazeEquippedTeleporterCosmetic"
    private let claimedRewardLevelsKey = "neonMazeClaimedCosmeticRewards"

    private var ownedPlayerSkins: Set<String>
    private var ownedTrails: Set<String>
    private var ownedWinAnimations: Set<String>
    private var ownedTeleporterSkins: Set<String>
    private(set) var claimedRewardLevels: Set<Int>

    private(set) var selectedPlayerSkin: PlayerSkin
    private(set) var selectedTrail: TrailStyle
    private(set) var selectedWinAnimation: WinAnimationStyle
    private(set) var selectedTeleporterSkin: TeleporterSkinStyle

    private init() {
        ownedPlayerSkins = Set(UserDefaults.standard.stringArray(forKey: ownedPlayerKey) ?? [PlayerSkin.neonCyan.rawValue])
        ownedTrails = Set(UserDefaults.standard.stringArray(forKey: ownedTrailKey) ?? [TrailStyle.classicNeon.rawValue])
        ownedWinAnimations = Set(UserDefaults.standard.stringArray(forKey: ownedWinKey) ?? [WinAnimationStyle.neonExplosion.rawValue])
        ownedTeleporterSkins = Set(UserDefaults.standard.stringArray(forKey: ownedTeleporterKey) ?? [TeleporterSkinStyle.classicPortal.rawValue])
        claimedRewardLevels = Set(UserDefaults.standard.array(forKey: claimedRewardLevelsKey) as? [Int] ?? [])
        if ownedTrails.remove(TrailStyle.pulseTrail.rawValue) != nil {
            ownedTrails.insert(TrailStyle.smoothLight.rawValue)
        }
        if ownedTrails.remove(TrailStyle.energyBurst.rawValue) != nil {
            ownedTrails.insert(TrailStyle.phaseStream.rawValue)
        }

        if let raw = UserDefaults.standard.string(forKey: equippedPlayerKey),
           let item = PlayerSkin(rawValue: raw),
           ownedPlayerSkins.contains(raw) {
            selectedPlayerSkin = item
        } else {
            selectedPlayerSkin = .neonCyan
        }

        if let raw = UserDefaults.standard.string(forKey: equippedTrailKey),
           let item = TrailStyle(rawValue: raw),
           ownedTrails.contains(raw) {
            selectedTrail = item
        } else {
            selectedTrail = .classicNeon
        }

        if let raw = UserDefaults.standard.string(forKey: equippedWinKey),
           let item = WinAnimationStyle(rawValue: raw),
           ownedWinAnimations.contains(raw) {
            selectedWinAnimation = item
        } else {
            selectedWinAnimation = .neonExplosion
        }

        if let raw = UserDefaults.standard.string(forKey: equippedTeleporterKey),
           let item = TeleporterSkinStyle(rawValue: raw),
           ownedTeleporterSkins.contains(raw) {
            selectedTeleporterSkin = item
        } else {
            selectedTeleporterSkin = .classicPortal
        }
        if selectedTrail == .pulseTrail {
            selectedTrail = .smoothLight
        } else if selectedTrail == .energyBurst {
            selectedTrail = .phaseStream
        }

        persist()
    }

    func items(for tab: ShopTab) -> [ShopItem] {
        switch tab {
        case .playerColors:
            return PlayerSkin.shopCases.filter { $0.kind == .color }.map(ShopItem.player)
        case .playerPatterns:
            return PlayerSkin.shopCases.filter { $0.kind == .pattern }.map(ShopItem.player)
        case .trails:
            return TrailStyle.shopCases.map(ShopItem.trail)
        case .winAnimations:
            return WinAnimationStyle.shopCases.map(ShopItem.win)
        }
    }

    func ownedItems(for tab: ShopTab) -> [ShopItem] {
        items(for: tab).filter(isOwned)
    }

    func isOwned(_ item: ShopItem) -> Bool {
        switch item {
        case let .player(skin):
            return ownedPlayerSkins.contains(skin.rawValue)
        case let .trail(style):
            return ownedTrails.contains(style.rawValue)
        case let .win(style):
            return ownedWinAnimations.contains(style.rawValue)
        case let .teleporter(style):
            return ownedTeleporterSkins.contains(style.rawValue)
        }
    }

    func isEquipped(_ item: ShopItem) -> Bool {
        switch item {
        case let .player(skin):
            return selectedPlayerSkin == skin
        case let .trail(style):
            return selectedTrail == style
        case let .win(style):
            return selectedWinAnimation == style
        case let .teleporter(style):
            return selectedTeleporterSkin == style
        }
    }

    func statusText(for item: ShopItem) -> String {
        if isEquipped(item) {
            return "EQUIPPED"
        }
        if isOwned(item) {
            return "OWNED"
        }
        if let price = item.price {
            return "\(price) C"
        }
        return "LOCKED"
    }

    func purchaseOrEquip(_ item: ShopItem) -> ShopPurchaseResult {
        if isOwned(item) {
            if isEquipped(item) {
                return .alreadySelected
            }
            equip(item)
            return .selected
        }
        let purchaseResult = purchase(item)
        if purchaseResult == .purchased {
            equip(item)
        }
        return purchaseResult
    }

    func purchase(_ item: ShopItem) -> ShopPurchaseResult {
        if isOwned(item) {
            return isEquipped(item) ? .alreadySelected : .selected
        }
        guard let price = item.price else {
            return .rewardOnly
        }
        guard CoinStore.shared.spend(price) else {
            return .insufficientCoins
        }
        unlock(item)
        persist()
        return .purchased
    }

    func unlockStoryRewardIfNeeded(forLevel levelId: Int) -> StoryRewardUnlock? {
        guard let reward = StoryCosmeticReward.reward(for: levelId),
              !claimedRewardLevels.contains(levelId) else { return nil }

        let alreadyOwned = isOwned(reward.item)
        claimedRewardLevels.insert(levelId)
        unlock(reward.item)
        equip(reward.item)
        persist()
        return StoryRewardUnlock(reward: reward, wasAlreadyOwned: alreadyOwned)
    }

    func equip(_ item: ShopItem) {
        guard isOwned(item) else { return }
        switch item {
        case let .player(skin):
            selectedPlayerSkin = skin
        case let .trail(style):
            selectedTrail = style
        case let .win(style):
            selectedWinAnimation = style
        case let .teleporter(style):
            selectedTeleporterSkin = style
        }
        persist()
    }

    private func unlock(_ item: ShopItem) {
        switch item {
        case let .player(skin):
            ownedPlayerSkins.insert(skin.rawValue)
        case let .trail(style):
            ownedTrails.insert(style.rawValue)
        case let .win(style):
            ownedWinAnimations.insert(style.rawValue)
        case let .teleporter(style):
            ownedTeleporterSkins.insert(style.rawValue)
        }
    }

    private func persist() {
        UserDefaults.standard.set(Array(ownedPlayerSkins).sorted(), forKey: ownedPlayerKey)
        UserDefaults.standard.set(Array(ownedTrails).sorted(), forKey: ownedTrailKey)
        UserDefaults.standard.set(Array(ownedWinAnimations).sorted(), forKey: ownedWinKey)
        UserDefaults.standard.set(Array(ownedTeleporterSkins).sorted(), forKey: ownedTeleporterKey)
        UserDefaults.standard.set(selectedPlayerSkin.rawValue, forKey: equippedPlayerKey)
        UserDefaults.standard.set(selectedTrail.rawValue, forKey: equippedTrailKey)
        UserDefaults.standard.set(selectedWinAnimation.rawValue, forKey: equippedWinKey)
        UserDefaults.standard.set(selectedTeleporterSkin.rawValue, forKey: equippedTeleporterKey)
        UserDefaults.standard.set(Array(claimedRewardLevels).sorted(), forKey: claimedRewardLevelsKey)
    }
}

final class PlayerSkinStore {
    static let shared = PlayerSkinStore()

    var selectedSkin: PlayerSkin {
        CosmeticsStore.shared.selectedPlayerSkin
    }

    func isOwned(_ skin: PlayerSkin) -> Bool {
        CosmeticsStore.shared.isOwned(.player(skin))
    }

    func purchaseOrSelect(_ skin: PlayerSkin) -> ShopPurchaseResult {
        CosmeticsStore.shared.purchaseOrEquip(.player(skin))
    }

    func select(_ skin: PlayerSkin) {
        CosmeticsStore.shared.equip(.player(skin))
    }
}

enum CosmeticRenderer {
    static func applyPlayerSkin(_ skin: PlayerSkin, to sprite: SKSpriteNode, displayScale: CGFloat = 2.0) {
        TextureFactory.shared.displayScale = displayScale
        sprite.childNode(withName: "skin_overlay")?.removeFromParent()
        sprite.childNode(withName: "skin_border")?.removeFromParent()
        sprite.childNode(withName: "skin_aura")?.removeFromParent()

        sprite.texture = TextureFactory.shared.playerTexture(size: sprite.size)
        sprite.color = skin.baseColor
        sprite.colorBlendFactor = skin.kind == .color ? 0.5 : 0.42

        if let ambientGlow = sprite.childNode(withName: "playerAmbientGlow") as? SKShapeNode {
            ambientGlow.fillColor = skin.highlightColor.withAlphaComponent(0.36)
            ambientGlow.strokeColor = skin.highlightColor.withAlphaComponent(0.46)
        }

        let aura = SKShapeNode(circleOfRadius: max(8, sprite.size.width * 0.34))
        aura.name = "skin_aura"
        aura.fillColor = skin.highlightColor.withAlphaComponent(skin == .goldenPulse ? 0.26 : (skin == .voidCore ? 0.14 : 0.18))
        aura.strokeColor = skin.baseColor.withAlphaComponent(0.26)
        aura.lineWidth = 1
        aura.glowWidth = sprite.size.width * 0.18
        aura.zPosition = -1.4
        aura.run(.repeatForever(.sequence([
            .group([
                .fadeAlpha(to: skin == .goldenPulse ? 0.62 : (skin == .voidCore ? 0.38 : 0.44), duration: skin == .electricPurple ? 1.4 : 0.9),
                .scale(to: skin == .voidCore ? 1.03 : 1.06, duration: skin == .electricPurple ? 1.4 : 0.9)
            ]),
            .group([
                .fadeAlpha(to: skin == .goldenPulse ? 0.42 : (skin == .voidCore ? 0.18 : 0.26), duration: skin == .electricPurple ? 1.4 : 0.9),
                .scale(to: 1.0, duration: skin == .electricPurple ? 1.4 : 0.9)
            ])
        ])))
        sprite.addChild(aura)

        if let patternTexture = TextureFactory.shared.playerPatternTexture(size: sprite.size, skin: skin) {
            let overlay = SKSpriteNode(texture: patternTexture)
            overlay.name = "skin_overlay"
            overlay.zPosition = 0.2
            overlay.blendMode = .add
            overlay.alpha = 0.92
            switch skin {
            case .gridCore:
                overlay.run(.repeatForever(.sequence([
                    .moveBy(x: 1.5, y: -1.0, duration: 1.2),
                    .moveBy(x: -1.5, y: 1.0, duration: 0)
                ])))
            case .pulseCore:
                overlay.run(.repeatForever(.sequence([
                    .group([.scale(to: 1.04, duration: 0.6), .fadeAlpha(to: 1.0, duration: 0.6)]),
                    .group([.scale(to: 0.98, duration: 0.6), .fadeAlpha(to: 0.82, duration: 0.6)])
                ])))
            case .glitchSkin:
                overlay.run(.repeatForever(.sequence([
                    .wait(forDuration: 2.2),
                    .group([.moveBy(x: 2, y: 0, duration: 0.03), .fadeAlpha(to: 0.72, duration: 0.03)]),
                    .group([.moveBy(x: -2, y: 0, duration: 0.04), .fadeAlpha(to: 0.94, duration: 0.04)])
                ])))
            case .energyStripes:
                overlay.run(.repeatForever(.sequence([
                    .moveBy(x: 1.5, y: -1.5, duration: 0.9),
                    .moveBy(x: -1.5, y: 1.5, duration: 0)
                ])))
            case .dualCore:
                overlay.run(.repeatForever(.sequence([
                    .fadeAlpha(to: 1.0, duration: 0.9),
                    .fadeAlpha(to: 0.74, duration: 0.9)
                ])))
            case .quantumFracture:
                overlay.run(.repeatForever(.sequence([
                    .group([.moveBy(x: 1.5, y: -1.5, duration: 0.75), .fadeAlpha(to: 1.0, duration: 0.75)]),
                    .group([.moveBy(x: -1.5, y: 1.5, duration: 0.0), .fadeAlpha(to: 0.78, duration: 0.0)])
                ])))
            case .goldenPulse:
                overlay.run(.repeatForever(.sequence([
                    .fadeAlpha(to: 1.0, duration: 0.5),
                    .fadeAlpha(to: 0.75, duration: 0.5)
                ])))
            case .voidCore:
                overlay.run(.repeatForever(.sequence([
                    .fadeAlpha(to: 0.66, duration: 0.9),
                    .fadeAlpha(to: 0.92, duration: 0.9)
                ])))
            default:
                break
            }
            sprite.addChild(overlay)
        }

        let border = SKShapeNode(
            rectOf: sprite.size,
            cornerRadius: sprite.size.height * 0.22
        )
        border.name = "skin_border"
        border.fillColor = .clear
        border.strokeColor = skin.highlightColor.withAlphaComponent(0.78)
        border.lineWidth = max(1.2, sprite.size.width * 0.045)
        border.glowWidth = sprite.size.width * 0.08
        border.zPosition = 0.35
        sprite.addChild(border)
    }

    static func configureTeleporterNode(
        _ node: SKSpriteNode,
        key: Character,
        skin: TeleporterSkinStyle,
        tileSize: CGFloat,
        accentColor: SKColor
    ) {
        node.removeAllChildren()
        node.removeAllActions()
        node.texture = TextureFactory.shared.teleporterTexture(size: node.size, style: skin, accentColor: accentColor)
        node.color = accentColor
        node.colorBlendFactor = 0.12
        node.alpha = 0.98

        let basePulse = SKAction.repeatForever(.sequence([
            .group([
                .scale(to: skin == .quantumPortal ? 1.1 : 1.06, duration: 0.75),
                .fadeAlpha(to: 0.9, duration: 0.75)
            ]),
            .group([
                .scale(to: 1.0, duration: 0.75),
                .fadeAlpha(to: 0.98, duration: 0.75)
            ])
        ]))
        node.run(basePulse, withKey: "portalPulse")

        let tagShadow = SKLabelNode(fontNamed: ArcadeFont.digits)
        tagShadow.text = String(key)
        tagShadow.fontSize = max(9, tileSize * 0.2)
        tagShadow.fontColor = SKColor(white: 0.0, alpha: 0.72)
        tagShadow.verticalAlignmentMode = .center
        tagShadow.horizontalAlignmentMode = .center
        tagShadow.position = CGPoint(x: 1, y: -1)
        tagShadow.zPosition = 1
        node.addChild(tagShadow)

        let tag = SKLabelNode(fontNamed: ArcadeFont.digits)
        tag.text = String(key)
        tag.fontSize = tagShadow.fontSize
        tag.fontColor = ArcadeStyle.Color.textPrimary
        tag.verticalAlignmentMode = .center
        tag.horizontalAlignmentMode = .center
        tag.position = .zero
        tag.zPosition = 2
        node.addChild(tag)

        switch skin {
        case .digitalGlitchPortal:
            node.run(.repeatForever(.sequence([
                .wait(forDuration: 2.0),
                .group([.moveBy(x: 1.5, y: 0, duration: 0.03), .fadeAlpha(to: 0.82, duration: 0.03)]),
                .group([.moveBy(x: -1.5, y: 0, duration: 0.04), .fadeAlpha(to: 0.98, duration: 0.04)])
            ])), withKey: "portalGlitch")
        case .energyVortex:
            let ring = SKShapeNode(circleOfRadius: node.size.width * 0.18)
            ring.strokeColor = accentColor.withAlphaComponent(0.65)
            ring.lineWidth = max(1, tileSize * 0.04)
            ring.fillColor = .clear
            ring.glowWidth = tileSize * 0.1
            ring.zPosition = 0.5
            ring.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 2.6)))
            node.addChild(ring)
        case .splitPortal:
            for direction in [-1, 1] {
                let bar = SKSpriteNode(color: accentColor.withAlphaComponent(0.28), size: CGSize(width: node.size.width * 0.16, height: node.size.height * 0.42))
                bar.position = CGPoint(x: CGFloat(direction) * node.size.width * 0.18, y: 0)
                bar.zRotation = .pi / 14 * CGFloat(direction)
                bar.zPosition = 0.5
                node.addChild(bar)
            }
        case .quantumPortal:
            for index in 0..<3 {
                let orbit = SKSpriteNode(texture: TextureFactory.shared.trailParticleTexture(size: CGSize(width: tileSize * 0.12, height: tileSize * 0.12), style: .orbitTrail))
                orbit.alpha = 0.8 - CGFloat(index) * 0.12
                orbit.position = CGPoint(x: node.size.width * 0.2, y: 0)
                orbit.zPosition = 0.6
                let container = SKNode()
                container.zRotation = CGFloat(index) * (.pi * 2 / 3)
                container.zPosition = 0.55
                container.addChild(orbit)
                container.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 2.2 + Double(index) * 0.5)))
                node.addChild(container)
            }
        case .classicPortal:
            break
        }
    }
}

extension SKColor {
    convenience init(hex: Int, alpha: CGFloat = 1.0) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255.0
        let green = CGFloat((hex >> 8) & 0xFF) / 255.0
        let blue = CGFloat(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
