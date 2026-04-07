import Foundation

final class MazeCache {
    static let shared = MazeCache()

    private let storagePrefix = "maze_cache_v2_"
    private let queue = DispatchQueue(label: "maze.cache.queue")
    private var memory: [String: MazeData] = [:]
    private var pending: [String: [(MazeData) -> Void]] = [:]
    private var didStartPrewarmingNormalLevels = false
    private var challengeRunFingerprints: [String: [MazeGenerator.ChallengeMazeFingerprint]] = [:]
    private var challengeGeneratedMazes: [String: (maze: MazeData, fingerprint: MazeGenerator.ChallengeMazeFingerprint)] = [:]
    private var challengeRunOrder: [String] = []

    private init() {}

    func cachedMaze(levelIndex: Int, config: LevelConfig) -> MazeData? {
        let key = cacheKey(levelIndex: levelIndex, config: config)
        var result: MazeData?
        queue.sync {
            if let cached = self.memory[key], self.isMazeValid(cached, config: config) {
                result = cached
                MazeBenchmarkStore.shared.prefetch(levelId: config.levelIndex, maze: cached)
                return
            }
            if let stored = self.loadFromDisk(key: key), self.isMazeValid(stored, config: config) {
                self.memory[key] = stored
                result = stored
                MazeBenchmarkStore.shared.prefetch(levelId: config.levelIndex, maze: stored)
                return
            }
            if let bundled = BundledNormalLevels.all[config.levelIndex], self.isMazeValid(bundled, config: config) {
                self.memory[key] = bundled
                result = bundled
                MazeBenchmarkStore.shared.prefetch(levelId: config.levelIndex, maze: bundled)
            }
        }
        return result
    }

    func prefetch(levelIndex: Int, config: LevelConfig) {
        loadOrGenerate(levelIndex: levelIndex, config: config) { _ in }
    }

    func loadOrGenerate(levelIndex: Int, config: LevelConfig, completion: @escaping (MazeData) -> Void) {
        let key = cacheKey(levelIndex: levelIndex, config: config)
        queue.async {
            if let cached = self.memory[key] {
                if self.isMazeValid(cached, config: config) {
                    DispatchQueue.main.async { completion(cached) }
                    return
                }
                self.memory[key] = nil
            }
            if let stored = self.loadFromDisk(key: key) {
                if self.isMazeValid(stored, config: config) {
                    self.memory[key] = stored
                    DispatchQueue.main.async { completion(stored) }
                    return
                }
            }
            if let bundled = BundledNormalLevels.all[config.levelIndex] {
                if self.isMazeValid(bundled, config: config) {
                    self.memory[key] = bundled
                    DispatchQueue.main.async { completion(bundled) }
                    return
                }
            }
            if self.pending[key] != nil {
                self.pending[key]?.append(completion)
                return
            }
            self.pending[key] = [completion]
            DispatchQueue.global(qos: .userInitiated).async {
                let generated = MazeGenerator.generate(levelIndex: levelIndex, config: config)
                self.queue.async {
                    self.memory[key] = generated
                    let callbacks = self.pending[key] ?? []
                    self.pending[key] = nil
                    self.saveToDisk(key: key, maze: generated)
                    DispatchQueue.main.async {
                        callbacks.forEach { $0(generated) }
                    }
                }
            }
        }
    }

    func generateFresh(levelIndex: Int, config: LevelConfig, seedSalt: Int, completion: @escaping (MazeData) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let generated = MazeGenerator.generate(levelIndex: levelIndex, config: config, seedSalt: seedSalt)
            DispatchQueue.main.async {
                completion(generated)
            }
        }
    }

    func generateFreshChallenge(
        mazeNumber: Int,
        duration: TimeChallengeDuration,
        config: LevelConfig,
        seedSalt: Int,
        completion: @escaping (MazeData) -> Void
    ) {
        let runKey = challengeRunKey(duration: duration, mazeNumber: mazeNumber, seedSalt: seedSalt)
        let mazeKey = challengeMazeKey(runKey: runKey, mazeNumber: mazeNumber)

        if let cached = queue.sync(execute: { challengeGeneratedMazes[mazeKey]?.maze }) {
            DispatchQueue.main.async {
                completion(cached)
            }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
        let generated = self.generateChallengeMaze(
                mazeNumber: mazeNumber,
                duration: duration,
                config: config,
                seedSalt: seedSalt,
                runKey: runKey,
                mazeKey: mazeKey
            )
            DispatchQueue.main.async {
                completion(generated)
            }
        }
    }

    func prewarmNormalLevels() {
        queue.async {
            guard !self.didStartPrewarmingNormalLevels else { return }
            self.didStartPrewarmingNormalLevels = true
            let levels = LevelStore.levels
            DispatchQueue.global(qos: .utility).async {
                for level in levels {
                    let config = makeLevelConfig(levelIndex: level.id)
                    let key = self.cacheKey(levelIndex: level.id - 1, config: config)
                    var shouldGenerate = true
                    self.queue.sync {
                        if let cached = self.memory[key], self.isMazeValid(cached, config: config) {
                            MazeBenchmarkStore.shared.prefetch(levelId: level.id, maze: cached)
                            shouldGenerate = false
                            return
                        }
                        if let stored = self.loadFromDisk(key: key), self.isMazeValid(stored, config: config) {
                            self.memory[key] = stored
                            MazeBenchmarkStore.shared.prefetch(levelId: level.id, maze: stored)
                            shouldGenerate = false
                            return
                        }
                        if let bundled = BundledNormalLevels.all[level.id], self.isMazeValid(bundled, config: config) {
                            self.memory[key] = bundled
                            MazeBenchmarkStore.shared.prefetch(levelId: level.id, maze: bundled)
                            shouldGenerate = false
                        }
                    }
                    guard shouldGenerate else { continue }
                    let generated = MazeGenerator.generate(levelIndex: level.id - 1, config: config)
                    self.queue.sync {
                        self.memory[key] = generated
                        self.saveToDisk(key: key, maze: generated)
                    }
                    MazeBenchmarkStore.shared.prefetch(levelId: level.id, maze: generated)
                }
            }
        }
    }

    private func cacheKey(levelIndex: Int, config: LevelConfig) -> String {
        let loop = String(format: "%.2f", config.loopFactor)
        let branch = String(format: "%.2f", config.branchFactor)
        let mechanics = config.enabledMechanics.map { $0.rawValue }.sorted().joined(separator: "-")
        return "lvl\(levelIndex)_\(config.mazeSize)x\(config.mazeSize)_l\(loop)_b\(branch)_o\(config.orbCount)_\(mechanics)_ow\(String(format: "%.2f", config.oneWayDensity))_tp\(config.teleporterPairs)_g\(String(format: "%.2f", config.gatePeriod))_k\(config.keyCount)_s\(config.switchCount)_d\(config.doorCount)_f\(config.fogRadius)"
    }

    private func loadFromDisk(key: String) -> MazeData? {
        let storageKey = storagePrefix + key
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(MazeData.self, from: data)
    }

    private func saveToDisk(key: String, maze: MazeData) {
        let storageKey = storagePrefix + key
        if let data = try? JSONEncoder().encode(maze) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func isMazeValid(_ maze: MazeData, config: LevelConfig) -> Bool {
        let expectedSize = max(5, config.mazeSize | 1)
        guard maze.rows == expectedSize, maze.cols == expectedSize else { return false }
        guard config.orbCount == 0 || maze.orbs.count <= config.orbCount else { return false }

        if config.enabledMechanics.isEmpty {
            return true
        }

        return MazeSolvability.analyze(grid: maze.grid, start: maze.start, exit: maze.exit).solvable
    }

    private func generateChallengeMaze(
        mazeNumber: Int,
        duration: TimeChallengeDuration,
        config: LevelConfig,
        seedSalt: Int,
        runKey: String,
        mazeKey: String
    ) -> MazeData {
        let levelIndex = 10_000 + duration.rawValue * 100 + mazeNumber
        let recentFingerprints = queue.sync { challengeRunFingerprints[runKey] ?? [] }
        let maxAttempts = 10
        var bestCandidate: (maze: MazeData, fingerprint: MazeGenerator.ChallengeMazeFingerprint, score: Int)?

        for attempt in 0..<maxAttempts {
            let plan = makeChallengeGenerationPlan(mazeNumber: mazeNumber, variationOffset: attempt)
            let candidateConfig = attempt == 0 ? config : plan.config
            let challengeSeedSalt = seedSalt &+ (attempt &* 1_639)
            let candidate = MazeGenerator.generate(levelIndex: levelIndex, config: candidateConfig, seedSalt: challengeSeedSalt)
            let analysis = MazeSolvability.analyze(grid: candidate.grid, start: candidate.start, exit: candidate.exit)
            guard analysis.solvable else { continue }

            let evaluation = MazeGenerator.evaluateChallengeCandidate(
                maze: candidate,
                config: candidateConfig,
                plan: plan,
                recentFingerprints: recentFingerprints
            )
            let isPlayable = challengeCandidateIsPlayable(candidate, plan: plan, evaluation: evaluation)
            if isPlayable, bestCandidate == nil || evaluation.fitScore > (bestCandidate?.score ?? Int.min) {
                bestCandidate = (candidate, evaluation.fingerprint, evaluation.fitScore)
            }
            guard isPlayable else { continue }
            if MazeGenerator.challengeCandidateAcceptable(evaluation, plan: plan, recentFingerprints: recentFingerprints) {
                recordChallengeMaze(candidate, fingerprint: evaluation.fingerprint, runKey: runKey, mazeKey: mazeKey)
                return candidate
            }
        }

        if let bestCandidate {
            recordChallengeMaze(bestCandidate.maze, fingerprint: bestCandidate.fingerprint, runKey: runKey, mazeKey: mazeKey)
            return bestCandidate.maze
        }

        let fallbackPlan = makeChallengeGenerationPlan(mazeNumber: mazeNumber, variationOffset: maxAttempts)
        let fallbackMaze = MazeGenerator.generate(levelIndex: levelIndex, config: fallbackPlan.config, seedSalt: seedSalt &+ 97_531)
        let fallbackEvaluation = MazeGenerator.evaluateChallengeCandidate(
            maze: fallbackMaze,
            config: fallbackPlan.config,
            plan: fallbackPlan,
            recentFingerprints: recentFingerprints
        )
        recordChallengeMaze(fallbackMaze, fingerprint: fallbackEvaluation.fingerprint, runKey: runKey, mazeKey: mazeKey)
        return fallbackMaze
    }

    private func challengeCandidateIsPlayable(
        _ maze: MazeData,
        plan: ChallengeGenerationPlan,
        evaluation: MazeGenerator.ChallengeCandidateEvaluation
    ) -> Bool {
        if plan.isRewardMaze {
            guard maze.shortestPath >= max(12, plan.shortestPathRange.lowerBound - 4) else { return false }
            guard evaluation.directness <= plan.directnessRange.upperBound + 0.2 else { return false }
            return evaluation.decisionDensity >= 0.05
        }

        guard maze.shortestPath >= max(18, plan.shortestPathRange.lowerBound - 6) else { return false }
        guard maze.shortestPath <= plan.shortestPathRange.upperBound + 14 else { return false }
        guard evaluation.decisionDensity >= 0.07 else { return false }
        return evaluation.branchDensity >= 0.05
    }

    private func challengeRunKey(duration: TimeChallengeDuration, mazeNumber: Int, seedSalt: Int) -> String {
        let runSeedBase = seedSalt &- (mazeNumber &* 7_919)
        return "challenge_\(duration.rawValue)_\(runSeedBase)"
    }

    private func challengeMazeKey(runKey: String, mazeNumber: Int) -> String {
        "\(runKey)_maze_\(mazeNumber)"
    }

    private func recordChallengeMaze(
        _ maze: MazeData,
        fingerprint: MazeGenerator.ChallengeMazeFingerprint,
        runKey: String,
        mazeKey: String
    ) {
        queue.sync {
            challengeGeneratedMazes[mazeKey] = (maze: maze, fingerprint: fingerprint)

            var fingerprints = challengeRunFingerprints[runKey] ?? []
            if !challengeRunOrder.contains(runKey) {
                challengeRunOrder.append(runKey)
            }
            if fingerprints.last != fingerprint {
                fingerprints.append(fingerprint)
            }
            if fingerprints.count > 6 {
                fingerprints.removeFirst(fingerprints.count - 6)
            }
            challengeRunFingerprints[runKey] = fingerprints

            while challengeRunOrder.count > 10 {
                let removedRunKey = challengeRunOrder.removeFirst()
                challengeRunFingerprints[removedRunKey] = nil
                let mazeKeysToRemove = challengeGeneratedMazes.keys.filter { $0.hasPrefix(removedRunKey) }
                for key in mazeKeysToRemove {
                    challengeGeneratedMazes[key] = nil
                }
            }
        }
    }
}
