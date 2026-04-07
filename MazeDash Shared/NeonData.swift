import Foundation
import SpriteKit
#if os(iOS) || os(tvOS)
import UIKit
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
        let ordered = [clampedEasy, clampedHard * 1.8, clampedHard].sorted(by: >)
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

    private let storagePrefix = "mazeDashBenchmark_v1_"
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
        return String(hash, radix: 16)
    }
}

struct LevelStore {
    static let levels: [LevelDefinition] = (1...30).map { index in
        let config = makeLevelConfig(levelIndex: index)
        return LevelDefinition(id: index, name: "Level \(index)", params: config.mazeParameters)
    }
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
    return String(format: "%.2f", clamped)
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
    case gridCore
    case pulseCore
    case glitchSkin
    case energyStripes
    case dualCore

    var kind: PlayerSkinKind {
        switch self {
        case .neonCyan, .neonPink, .electricPurple, .toxicGreen, .goldenPulse:
            return .color
        case .gridCore, .pulseCore, .glitchSkin, .energyStripes, .dualCore:
            return .pattern
        }
    }

    var displayName: String {
        switch self {
        case .neonCyan:
            return "NEON CYAN"
        case .neonPink:
            return "NEON PINK"
        case .electricPurple:
            return "ELECTRIC PURPLE"
        case .toxicGreen:
            return "TOXIC GREEN"
        case .goldenPulse:
            return "GOLDEN PULSE"
        case .gridCore:
            return "GRID CORE"
        case .pulseCore:
            return "PULSE CORE"
        case .glitchSkin:
            return "GLITCH SKIN"
        case .energyStripes:
            return "ENERGY STRIPES"
        case .dualCore:
            return "DUAL CORE"
        }
    }

    var detail: String {
        switch self {
        case .neonCyan:
            return "CLASSIC FUTURISTIC CYAN"
        case .neonPink:
            return "EXPRESSIVE NEON DRIVE"
        case .electricPurple:
            return "SOFT PREMIUM GLOW"
        case .toxicGreen:
            return "ARCADE REACTIVE HUE"
        case .goldenPulse:
            return "LUXURY SHIMMER FINISH"
        case .gridCore:
            return "TECHNICAL INNER GRID"
        case .pulseCore:
            return "BREATHING ENERGY CORE"
        case .glitchSkin:
            return "CONTROLLED DIGITAL GLITCH"
        case .energyStripes:
            return "FLOWING DIAGONAL LINES"
        case .dualCore:
            return "TWO NEON WORLDS SHIFTING"
        }
    }

    var price: Int? {
        switch self {
        case .neonCyan:
            return 0
        case .neonPink:
            return 24
        case .electricPurple:
            return 34
        case .toxicGreen:
            return 42
        case .pulseCore:
            return 78
        case .glitchSkin:
            return 112
        case .energyStripes:
            return 92
        case .goldenPulse, .gridCore, .dualCore:
            return nil
        }
    }

    var rewardLevel: Int? {
        switch self {
        case .goldenPulse:
            return 5
        case .gridCore:
            return 10
        case .dualCore:
            return 30
        default:
            return nil
        }
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
        case .gridCore:
            return SKColor(hex: 0x00D4FF)
        case .pulseCore:
            return SKColor(hex: 0xFF2D9A)
        case .glitchSkin:
            return SKColor(hex: 0xA855F7)
        case .energyStripes:
            return SKColor(hex: 0x39FF14)
        case .dualCore:
            return SKColor(hex: 0x00D4FF)
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
        case .gridCore:
            return SKColor(hex: 0x66F2FF)
        case .pulseCore:
            return SKColor(hex: 0xFF9DD8)
        case .glitchSkin:
            return SKColor(hex: 0xF0C3FF)
        case .energyStripes:
            return SKColor(hex: 0x9FFF7D)
        case .dualCore:
            return SKColor(hex: 0xFF6BC1)
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
        case .gridCore:
            return SKColor(hex: 0x00708E)
        case .pulseCore:
            return SKColor(hex: 0xAD125F)
        case .glitchSkin:
            return SKColor(hex: 0x5E2B9C)
        case .energyStripes:
            return SKColor(hex: 0x168300)
        case .dualCore:
            return SKColor(hex: 0x7E22CE)
        }
    }

    var accentColor: SKColor {
        switch self {
        case .goldenPulse:
            return ArcadeStyle.Color.accentYellow
        case .neonPink, .pulseCore:
            return ArcadeStyle.Color.accentMagenta
        default:
            return baseColor
        }
    }
}

enum TrailStyle: String, CaseIterable, Codable {
    case classicNeon
    case electricSparks
    case smoothLight
    case pixelTrail
    case pulseTrail
    case energyBurst
    case orbitTrail

    var displayName: String {
        switch self {
        case .classicNeon:
            return "CLASSIC NEON"
        case .electricSparks:
            return "ELECTRIC SPARKS"
        case .smoothLight:
            return "SMOOTH LIGHT"
        case .pixelTrail:
            return "PIXEL TRAIL"
        case .pulseTrail:
            return "PULSE TRAIL"
        case .energyBurst:
            return "ENERGY BURST"
        case .orbitTrail:
            return "ORBIT TRAIL"
        }
    }

    var detail: String {
        switch self {
        case .classicNeon:
            return "CLEAN BASELINE TRAIL"
        case .electricSparks:
            return "SMALL ELECTRIC FUNKS"
        case .smoothLight:
            return "SOFT LIGHT RESIDUE"
        case .pixelTrail:
            return "GEOMETRIC PIXEL BURSTS"
        case .pulseTrail:
            return "PARTICLES THAT BREATHE"
        case .energyBurst:
            return "CALM UNTIL COMBO BURSTS"
        case .orbitTrail:
            return "MICRO PARTICLES IN ORBIT"
        }
    }

    var price: Int? {
        switch self {
        case .classicNeon:
            return 0
        case .electricSparks:
            return 64
        case .smoothLight:
            return 76
        case .pixelTrail:
            return 70
        case .pulseTrail:
            return 94
        case .orbitTrail:
            return 128
        case .energyBurst:
            return nil
        }
    }

    var rewardLevel: Int? {
        self == .energyBurst ? 15 : nil
    }

    var accentColor: SKColor {
        switch self {
        case .classicNeon:
            return ArcadeStyle.Color.accentCyan
        case .electricSparks:
            return ArcadeStyle.Color.accentYellow
        case .smoothLight:
            return SKColor(hex: 0xA6F7FF)
        case .pixelTrail:
            return ArcadeStyle.Color.accentMagenta
        case .pulseTrail:
            return SKColor(hex: 0xFF91D4)
        case .energyBurst:
            return SKColor(hex: 0xFFD84D)
        case .orbitTrail:
            return SKColor(hex: 0xB691FF)
        }
    }
}

enum WinAnimationStyle: String, CaseIterable, Codable {
    case neonExplosion
    case energyImplosion
    case pixelShatter
    case shockwaveRing
    case lightBeamFinish

    var displayName: String {
        switch self {
        case .neonExplosion:
            return "NEON EXPLOSION"
        case .energyImplosion:
            return "ENERGY IMPLOSION"
        case .pixelShatter:
            return "PIXEL SHATTER"
        case .shockwaveRing:
            return "SHOCKWAVE RING"
        case .lightBeamFinish:
            return "LIGHT BEAM FINISH"
        }
    }

    var detail: String {
        switch self {
        case .neonExplosion:
            return "RADIAL ENERGY BURST"
        case .energyImplosion:
            return "CONTROLLED COMPRESSION RELEASE"
        case .pixelShatter:
            return "PLAYER BREAKS INTO PIXELS"
        case .shockwaveRing:
            return "RING BLAST FROM GOAL"
        case .lightBeamFinish:
            return "ABSORBED INTO LIGHT"
        }
    }

    var price: Int? {
        switch self {
        case .neonExplosion:
            return 0
        case .energyImplosion:
            return 84
        case .pixelShatter:
            return 108
        case .shockwaveRing:
            return 92
        case .lightBeamFinish:
            return nil
        }
    }

    var rewardLevel: Int? {
        self == .lightBeamFinish ? 20 : nil
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
    case teleporters

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
        case .teleporters:
            return "PORTALS"
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
            return .teleporters
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
        case 5:
            return StoryCosmeticReward(
                milestoneLevel: 5,
                item: .player(.goldenPulse),
                title: "NEW SKIN UNLOCKED",
                detail: "GOLDEN PULSE REWARDED FOR CLEARING 5 LEVELS."
            )
        case 10:
            return StoryCosmeticReward(
                milestoneLevel: 10,
                item: .player(.gridCore),
                title: "PATTERN UNLOCKED",
                detail: "GRID CORE REWARDED FOR CLEARING 10 LEVELS."
            )
        case 15:
            return StoryCosmeticReward(
                milestoneLevel: 15,
                item: .trail(.energyBurst),
                title: "TRAIL UNLOCKED",
                detail: "ENERGY BURST REWARDED FOR CLEARING 15 LEVELS."
            )
        case 20:
            return StoryCosmeticReward(
                milestoneLevel: 20,
                item: .win(.lightBeamFinish),
                title: "WIN FX UNLOCKED",
                detail: "LIGHT BEAM FINISH REWARDED FOR CLEARING 20 LEVELS."
            )
        case 25:
            return StoryCosmeticReward(
                milestoneLevel: 25,
                item: .teleporter(.quantumPortal),
                title: "PORTAL SKIN UNLOCKED",
                detail: "QUANTUM PORTAL REWARDED FOR CLEARING 25 LEVELS."
            )
        case 30:
            return StoryCosmeticReward(
                milestoneLevel: 30,
                item: .player(.dualCore),
                title: "FINAL SKIN UNLOCKED",
                detail: "DUAL CORE REWARDED FOR FINISHING STORY MODE."
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

        persist()
    }

    func items(for tab: ShopTab) -> [ShopItem] {
        switch tab {
        case .playerColors:
            return PlayerSkin.allCases.filter { $0.kind == .color }.map(ShopItem.player)
        case .playerPatterns:
            return PlayerSkin.allCases.filter { $0.kind == .pattern }.map(ShopItem.player)
        case .trails:
            return TrailStyle.allCases.map(ShopItem.trail)
        case .winAnimations:
            return WinAnimationStyle.allCases.map(ShopItem.win)
        case .teleporters:
            return TeleporterSkinStyle.allCases.map(ShopItem.teleporter)
        }
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
        if let rewardLevel = item.rewardLevel {
            return "UNLOCK L\(rewardLevel)"
        }
        if let price = item.price {
            return "\(price) COINS"
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
        guard let price = item.price else {
            return .rewardOnly
        }
        guard CoinStore.shared.spend(price) else {
            return .insufficientCoins
        }
        unlock(item)
        equip(item)
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
        aura.fillColor = skin.highlightColor.withAlphaComponent(skin == .goldenPulse ? 0.26 : 0.18)
        aura.strokeColor = skin.baseColor.withAlphaComponent(0.26)
        aura.lineWidth = 1
        aura.glowWidth = sprite.size.width * 0.18
        aura.zPosition = -1.4
        aura.run(.repeatForever(.sequence([
            .group([
                .fadeAlpha(to: skin == .goldenPulse ? 0.62 : 0.44, duration: skin == .electricPurple ? 1.4 : 0.9),
                .scale(to: 1.06, duration: skin == .electricPurple ? 1.4 : 0.9)
            ]),
            .group([
                .fadeAlpha(to: skin == .goldenPulse ? 0.42 : 0.26, duration: skin == .electricPurple ? 1.4 : 0.9),
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
                    .colorize(with: SKColor(hex: 0xFF2D9A), colorBlendFactor: 0.24, duration: 1.2),
                    .colorize(with: SKColor(hex: 0x00D4FF), colorBlendFactor: 0.24, duration: 1.2)
                ])))
            case .goldenPulse:
                overlay.run(.repeatForever(.sequence([
                    .fadeAlpha(to: 1.0, duration: 0.5),
                    .fadeAlpha(to: 0.75, duration: 0.5)
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
