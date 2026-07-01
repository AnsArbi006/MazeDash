import Foundation

struct MazeParameters: Codable, Hashable {
    let rows: Int
    let cols: Int
    let loopFactor: Double
    let branchFactor: Double
    let orbCount: Int
}

struct MovingBlockData: Codable, Hashable {
    let start: GridPoint
    let end: GridPoint
    let speedMultiplier: Double
    let phaseOffset: Double
}

struct ChaserSpawnData: Codable, Hashable {
    let spawn: GridPoint
    let behavior: ChaserBehavior
    let startDelay: TimeInterval
    let repathDelay: TimeInterval
    let speedMultiplier: Double
    let trailDelaySteps: Int
}

struct MazeData: Codable {
    let rows: Int
    let cols: Int
    let grid: [String]
    let start: GridPoint
    let exit: GridPoint
    let orbs: [GridPoint]
    let t2: TimeInterval
    let t3: TimeInterval
    let shortestPath: Int
    let movingBlocks: [MovingBlockData]
    let chaserSpawn: ChaserSpawnData?

    init(
        rows: Int,
        cols: Int,
        grid: [String],
        start: GridPoint,
        exit: GridPoint,
        orbs: [GridPoint],
        t2: TimeInterval,
        t3: TimeInterval,
        shortestPath: Int,
        movingBlocks: [MovingBlockData] = [],
        chaserSpawn: ChaserSpawnData? = nil
    ) {
        self.rows = rows
        self.cols = cols
        self.grid = grid
        self.start = start
        self.exit = exit
        self.orbs = orbs
        self.t2 = t2
        self.t3 = t3
        self.shortestPath = shortestPath
        self.movingBlocks = movingBlocks
        self.chaserSpawn = chaserSpawn
    }

    private enum CodingKeys: String, CodingKey {
        case rows
        case cols
        case grid
        case start
        case exit
        case orbs
        case t2
        case t3
        case shortestPath
        case movingBlocks
        case chaserSpawn
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rows = try container.decode(Int.self, forKey: .rows)
        cols = try container.decode(Int.self, forKey: .cols)
        grid = try container.decode([String].self, forKey: .grid)
        start = try container.decode(GridPoint.self, forKey: .start)
        exit = try container.decode(GridPoint.self, forKey: .exit)
        orbs = try container.decode([GridPoint].self, forKey: .orbs)
        t2 = try container.decode(TimeInterval.self, forKey: .t2)
        t3 = try container.decode(TimeInterval.self, forKey: .t3)
        shortestPath = try container.decode(Int.self, forKey: .shortestPath)
        movingBlocks = try container.decodeIfPresent([MovingBlockData].self, forKey: .movingBlocks) ?? []
        chaserSpawn = try container.decodeIfPresent(ChaserSpawnData.self, forKey: .chaserSpawn)
    }

    func tile(at point: GridPoint) -> Character? {
        guard point.row >= 0, point.row < rows, point.col >= 0, point.col < cols else {
            return nil
        }
        let line = grid[point.row]
        let index = line.index(line.startIndex, offsetBy: point.col)
        return line[index]
    }

    func isWalkable(_ point: GridPoint) -> Bool {
        guard let tile = tile(at: point) else { return false }
        return tile != "#"
    }
}

enum MazeTiming {
    static let stepDuration: TimeInterval = 0.11
}

enum MazeGenerator {
    struct ChallengeMazeFingerprint: Hashable {
        let role: ChallengeMazeRole
        let profile: ChallengeVariationProfile
        let sizeBucket: Int
        let pathBucket: Int
        let branchBucket: Int
        let deadEndBucket: Int
        let directnessBucket: Int
        let decisionBucket: Int
        let corridorBucket: Int
        let gimmickSignature: String
    }

    struct ChallengeCandidateEvaluation {
        let fingerprint: ChallengeMazeFingerprint
        let shortestPath: Int
        let branchDensity: Double
        let deadEndDensity: Double
        let directness: Double
        let decisionDensity: Double
        let corridorDensity: Double
        let maxSimilarity: Int
        let fitScore: Int
    }

    static func generate(levelIndex: Int, config: LevelConfig, seedSalt: Int = 0) -> MazeData {
        let params = config.mazeParameters
        let rows = max(5, params.rows | 1)
        let cols = max(5, params.cols | 1)
        let maxMazeAttempts = 6
        let maxSpecialPlacementAttempts = 6
        let maxArrowRepairAttempts = 50

        for mazeAttempt in 0..<maxMazeAttempts {
            let generationSeed = SeededGenerator.seed(
                for: levelIndex,
                rows: rows,
                cols: cols,
                seedSalt: seedSalt,
                attempt: mazeAttempt
            )
            var rng = SeededGenerator(seed: generationSeed)

            var walls = Array(repeating: Array(repeating: true, count: cols), count: rows)
            for row in stride(from: 1, to: rows, by: 2) {
                for col in stride(from: 1, to: cols, by: 2) {
                    walls[row][col] = false
                }
            }

            var visited = Array(repeating: Array(repeating: false, count: cols), count: rows)
            let startCell = GridPoint(row: randomOdd(rows, using: &rng), col: randomOdd(cols, using: &rng))
            var stack = [startCell]
            visited[startCell.row][startCell.col] = true

            while let current = stack.last {
                var neighbors: [(GridPoint, GridPoint)] = []
                for direction in MoveDirection.allCases {
                    let nextRow = current.row + direction.deltaRow * 2
                    let nextCol = current.col + direction.deltaCol * 2
                    guard nextRow > 0, nextRow < rows - 1, nextCol > 0, nextCol < cols - 1 else { continue }
                    guard !visited[nextRow][nextCol] else { continue }
                    let between = GridPoint(row: current.row + direction.deltaRow, col: current.col + direction.deltaCol)
                    neighbors.append((GridPoint(row: nextRow, col: nextCol), between))
                }
                if neighbors.isEmpty {
                    stack.removeLast()
                    continue
                }
                let choice = neighbors.randomElement(using: &rng) ?? neighbors[0]
                visited[choice.0.row][choice.0.col] = true
                walls[choice.1.row][choice.1.col] = false
                walls[choice.0.row][choice.0.col] = false
                stack.append(choice.0)
            }

            let loopFactor = max(0, min(1, params.loopFactor))
            if loopFactor > 0 {
                for row in 1..<(rows - 1) {
                    for col in 1..<(cols - 1) where walls[row][col] {
                        let horizontal = !walls[row][col - 1] && !walls[row][col + 1]
                        let vertical = !walls[row - 1][col] && !walls[row + 1][col]
                        if horizontal || vertical {
                            if rng.nextDouble() < loopFactor {
                                walls[row][col] = false
                            }
                        }
                    }
                }
            }

            let branchAttempts = Int(Double(rows * cols) * max(0, params.branchFactor))
            if branchAttempts > 0 {
                for _ in 0..<branchAttempts {
                    let row = rng.nextInt(rows - 2) + 1
                    let col = rng.nextInt(cols - 2) + 1
                    guard !walls[row][col] else { continue }
                    let direction = MoveDirection.allCases[rng.nextInt(MoveDirection.allCases.count)]
                    let mid = GridPoint(row: row + direction.deltaRow, col: col + direction.deltaCol)
                    let end = GridPoint(row: row + direction.deltaRow * 2, col: col + direction.deltaCol * 2)
                    guard end.row > 0, end.row < rows - 1, end.col > 0, end.col < cols - 1 else { continue }
                    guard walls[mid.row][mid.col], walls[end.row][end.col] else { continue }
                    walls[mid.row][mid.col] = false
                    walls[end.row][end.col] = false
                }
            }

            let pathCells = collectPaths(walls: walls)
            let initial = pathCells[rng.nextInt(pathCells.count)]
            let first = bfsDistances(from: initial, walls: walls)
            let start = first.farthest
            let second = bfsDistances(from: start, walls: walls)
            let exit = second.farthest
            let shortestPath = max(1, second.distances[exit.row][exit.col])
            let mainPath = bfsPath(from: start, to: exit, walls: walls)

            let shortestSteps = Double(shortestPath)
            let baseTime = shortestSteps * MazeTiming.stepDuration
            let levelNumber = config.levelIndex
            let tightFactor = levelNumber >= 20 ? 1.15 : 1.25
            let moderateFactor = levelNumber >= 20 ? 1.45 : 1.6
            let t3 = max(4.0, baseTime * tightFactor)
            let t2 = max(t3 + 1.5, baseTime * moderateFactor)

            let baseGrid = baseGrid(walls: walls)
            let protectedTiles = Set<GridPoint>([start, exit] + neighborPoints(of: start, rows: rows, cols: cols) + neighborPoints(of: exit, rows: rows, cols: cols))
            let mainPathSet = Set(mainPath)
            let specialPlacementLimit = config.enabledMechanics.isEmpty ? 1 : maxSpecialPlacementAttempts

            for _ in 0..<specialPlacementLimit {
                var specialTiles: [GridPoint: Character] = [:]
                var attemptReserved = Set<GridPoint>([start, exit])
                var minArrowCount = 0
                var movingBlocks: [MovingBlockData] = []
                var chaserSpawn: ChaserSpawnData?

                if config.enabledMechanics.contains(.keysDoors) {
                    let keyCount = max(1, min(config.keyCount, max(1, mainPath.count / 10)))
                    let splitIndex = max(2, Int(Double(mainPath.count) * 0.52))
                    let targetDistance = max(2, Int(Double(shortestPath) * 0.42))

                    let branchKeyCandidates = pathCells.filter { point in
                        guard !attemptReserved.contains(point), point != start, point != exit else { return false }
                        guard !mainPathSet.contains(point) else { return false }
                        let distanceFromStart = second.distances[point.row][point.col]
                        guard distanceFromStart >= max(2, shortestPath / 5) else { return false }
                        guard distanceFromStart <= max(4, Int(Double(shortestPath) * 0.75)) else { return false }
                        return neighborPoints(of: point, rows: rows, cols: cols).contains(where: mainPathSet.contains)
                    }

                    let prioritizedBranchCandidates = branchKeyCandidates.sorted { lhs, rhs in
                        let lhsDistance = abs(second.distances[lhs.row][lhs.col] - targetDistance)
                        let rhsDistance = abs(second.distances[rhs.row][rhs.col] - targetDistance)
                        if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
                        return second.distances[lhs.row][lhs.col] < second.distances[rhs.row][rhs.col]
                    }

                    var selectedKeys: [GridPoint] = []
                    for key in prioritizedBranchCandidates.prefix(keyCount) {
                        selectedKeys.append(key)
                        attemptReserved.insert(key)
                    }

                    if selectedKeys.count < keyCount {
                        var fallbackCandidates = Array(mainPath.prefix(max(2, splitIndex))).filter {
                            !attemptReserved.contains($0) && $0 != start && $0 != exit
                        }
                        fallbackCandidates.shuffle(using: &rng)
                        for key in fallbackCandidates.prefix(keyCount - selectedKeys.count) {
                            selectedKeys.append(key)
                            attemptReserved.insert(key)
                        }
                    }

                    for key in selectedKeys {
                        specialTiles[key] = "K"
                    }
                }

                if config.enabledMechanics.contains(.breakableWalls) {
                    let breakableCount = max(1, min(config.breakableCount, max(1, mainPath.count / 10)))
                    let splitIndex = max(3, Int(Double(mainPath.count) * 0.52))

                    let requiredBreakables = requiredBlockingCandidates(
                        on: mainPath,
                        walls: walls,
                        start: start,
                        exit: exit,
                        reserved: attemptReserved
                    ).filter { second.distances[$0.row][$0.col] <= second.distances[mainPath[min(splitIndex, mainPath.count - 1)].row][mainPath[min(splitIndex, mainPath.count - 1)].col] }

                    let primaryBreakable = (requiredBreakables.isEmpty ? Array(mainPath.dropFirst(splitIndex)) : requiredBreakables).first {
                        !attemptReserved.contains($0) && !protectedTiles.contains($0)
                    }

                    if let primaryBreakable {
                        specialTiles[primaryBreakable] = "B"
                        attemptReserved.insert(primaryBreakable)
                    }

                    var extraBreakableCandidates = Array(mainPath.dropFirst(splitIndex)).filter {
                        !attemptReserved.contains($0) && !protectedTiles.contains($0)
                    }
                    extraBreakableCandidates.shuffle(using: &rng)
                    for point in extraBreakableCandidates.prefix(max(0, breakableCount - (primaryBreakable == nil ? 0 : 1))) {
                        specialTiles[point] = "B"
                        attemptReserved.insert(point)
                    }
                }

                if config.enabledMechanics.contains(.switchBlocks) {
                    let switchBlockCount = max(1, min(config.switchBlockCount, max(1, mainPath.count / 8)))
                    let switchCount = max(1, min(config.switchCount, max(1, mainPath.count / 14)))
                    let splitIndex = max(3, Int(Double(mainPath.count) * 0.58))
                    let pathIndexByPoint = Dictionary(uniqueKeysWithValues: mainPath.enumerated().map { ($0.element, $0.offset) })
                    let progressionSpacing = max(4, min(9, mainPath.count / 7))
                    let breakablePoints = specialTiles.compactMap { point, tile in
                        tile == "B" ? point : nil
                    }
                    let breakableIndices = breakablePoints.compactMap { pathIndexByPoint[$0] }
                    let breakableSpacingBuffer = Set(
                        breakablePoints.flatMap {
                            bufferedPoints(around: $0, maxDistance: 4, rows: rows, cols: cols)
                        }
                    )

                    let requiredSwitchBlocks = requiredBlockingCandidates(
                        on: mainPath,
                        walls: walls,
                        start: start,
                        exit: exit,
                        reserved: attemptReserved
                    )
                    let primarySwitchBlock = (requiredSwitchBlocks.isEmpty ? Array(mainPath.dropFirst(splitIndex)) : requiredSwitchBlocks).first {
                        !attemptReserved.contains($0)
                        && !protectedTiles.contains($0)
                        && !breakableSpacingBuffer.contains($0)
                        && pathIndexByPoint[$0].map { candidateIndex in
                            breakableIndices.allSatisfy { abs($0 - candidateIndex) >= progressionSpacing }
                        } ?? false
                    }

                    if let primarySwitchBlock {
                        specialTiles[primarySwitchBlock] = "X"
                        attemptReserved.insert(primarySwitchBlock)
                    }

                    var switchBlockCandidates = Array(mainPath.dropFirst(splitIndex)).filter {
                        !attemptReserved.contains($0)
                        && !protectedTiles.contains($0)
                        && !breakableSpacingBuffer.contains($0)
                        && pathIndexByPoint[$0].map { candidateIndex in
                            breakableIndices.allSatisfy { abs($0 - candidateIndex) >= progressionSpacing }
                        } ?? false
                    }
                    switchBlockCandidates.shuffle(using: &rng)
                    for point in switchBlockCandidates.prefix(max(0, switchBlockCount - (primarySwitchBlock == nil ? 0 : 1))) {
                        specialTiles[point] = "X"
                        attemptReserved.insert(point)
                    }

                    let switchAnchorPoint = primarySwitchBlock ?? mainPath[min(splitIndex, mainPath.count - 1)]
                    let switchAnchorDistance = max(1, second.distances[switchAnchorPoint.row][switchAnchorPoint.col])
                    let switchAnchorIndex = pathIndexByPoint[switchAnchorPoint] ?? (mainPath.count - 1)
                    let desiredSwitchIndex = max(2, Int(Double(switchAnchorIndex) * 0.45))
                    let minimumGap = max(5, min(11, mainPath.count / 6))
                    let earliestBlockingIndex = ([switchAnchorIndex] + breakableIndices).min() ?? switchAnchorIndex

                    var primarySwitch: GridPoint?
                    let mainPathSwitchCandidates = Array(mainPath.dropFirst().dropLast()).filter {
                        !attemptReserved.contains($0)
                        && $0 != start
                        && $0 != exit
                        && !protectedTiles.contains($0)
                        && !breakableSpacingBuffer.contains($0)
                        && second.distances[$0.row][$0.col] >= 0
                        && second.distances[$0.row][$0.col] < switchAnchorDistance
                        && pathIndexByPoint[$0].map { candidateIndex in
                            earliestBlockingIndex - candidateIndex >= minimumGap
                        } ?? false
                    }

                    let spreadCandidates = mainPathSwitchCandidates.filter {
                        let candidateIndex = pathIndexByPoint[$0] ?? 0
                        return switchAnchorIndex - candidateIndex >= minimumGap
                    }
                    let prioritizedCandidates = spreadCandidates.isEmpty ? mainPathSwitchCandidates : spreadCandidates
                    let shapedCandidates = prioritizedCandidates.filter {
                        isIntersectionOrCorner($0, walls: walls) || isCorridor($0, walls: walls)
                    }
                    let rankedCandidates = shapedCandidates.isEmpty ? prioritizedCandidates : shapedCandidates

                    primarySwitch = rankedCandidates.min {
                        let lhsIndex = pathIndexByPoint[$0] ?? 0
                        let rhsIndex = pathIndexByPoint[$1] ?? 0
                        let lhsScore = abs(lhsIndex - desiredSwitchIndex)
                        let rhsScore = abs(rhsIndex - desiredSwitchIndex)
                        if lhsScore == rhsScore {
                            return lhsIndex < rhsIndex
                        }
                        return lhsScore < rhsScore
                    }

                    if let primarySwitch {
                        specialTiles[primarySwitch] = "T"
                        attemptReserved.insert(primarySwitch)
                    }

                    var switchCandidates = pathCells.filter {
                        !attemptReserved.contains($0)
                        && $0 != start
                        && $0 != exit
                        && !protectedTiles.contains($0)
                        && !breakableSpacingBuffer.contains($0)
                        && second.distances[$0.row][$0.col] >= 0
                        && second.distances[$0.row][$0.col] < switchAnchorDistance
                        && (pathIndexByPoint[$0].map { candidateIndex in
                            earliestBlockingIndex - candidateIndex >= minimumGap
                        } ?? true)
                    }
                    switchCandidates.sort {
                        second.distances[$0.row][$0.col] > second.distances[$1.row][$1.col]
                    }
                    let switches = Array(switchCandidates.prefix(max(0, switchCount - (primarySwitch == nil ? 0 : 1))))
                    for trigger in switches {
                        specialTiles[trigger] = "T"
                        attemptReserved.insert(trigger)
                    }
                }

                if config.enabledMechanics.contains(.teleporters) {
                    let pairCount = max(1, config.teleporterPairs)
                    var candidates = pathCells.filter { !attemptReserved.contains($0) && neighborCount($0, walls: walls) >= 3 }
                    if candidates.count < pairCount * 2 {
                        candidates = pathCells.filter { !attemptReserved.contains($0) }
                    }
                    candidates.shuffle(using: &rng)
                    let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
                    for pairIndex in 0..<min(pairCount, candidates.count / 2) {
                        let first = candidates[pairIndex * 2]
                        let second = candidates[pairIndex * 2 + 1]
                        let letter = letters[pairIndex % letters.count]
                        specialTiles[first] = letter
                        specialTiles[second] = Character(letter.lowercased())
                        attemptReserved.insert(first)
                        attemptReserved.insert(second)
                    }
                }

                if config.enabledMechanics.contains(.timingGates) {
                    let gateCount = max(1, min(6, max(1, mainPath.count / 12)))
                    var gateCandidates = pathCells.filter { !attemptReserved.contains($0) && isCorridor($0, walls: walls) }
                    gateCandidates.shuffle(using: &rng)
                    for gate in gateCandidates.prefix(gateCount) {
                        specialTiles[gate] = "G"
                        attemptReserved.insert(gate)
                    }
                }

                if config.enabledMechanics.contains(.oneWay) {
                    let density = min(0.1, max(0.02, config.oneWayDensity))
                    let candidates = pathCells.filter {
                        !attemptReserved.contains($0)
                        && !protectedTiles.contains($0)
                        && isIntersectionOrCorner($0, walls: walls)
                    }
                    let targetCount = min(candidates.count, max(1, Int(Double(pathCells.count) * density)))
                    minArrowCount = targetCount == 0 ? 0 : max(1, Int(Double(targetCount) * 0.7))
                    var shuffled = candidates
                    shuffled.shuffle(using: &rng)
                    for point in shuffled.prefix(targetCount) {
                        let directions = walkableDirections(from: point, walls: walls)
                        guard let direction = directions.randomElement(using: &rng) else { continue }
                        specialTiles[point] = arrowFor(direction)
                        attemptReserved.insert(point)
                    }
                }

                if config.enabledMechanics.contains(.movingBlocks) {
                    let targetCount = max(1, config.movingBlockCount)
                    let trackCandidates = movingTrackCandidates(
                        on: mainPath,
                        reserved: attemptReserved,
                        protected: protectedTiles
                    )
                    for (index, track) in trackCandidates.prefix(targetCount).enumerated() {
                        guard let first = track.first, let last = track.last else { continue }
                        movingBlocks.append(
                            MovingBlockData(
                                start: first,
                                end: last,
                                speedMultiplier: 0.72 + Double(index) * 0.04,
                                phaseOffset: Double(index) * 1.35
                            )
                        )
                        for point in track {
                            attemptReserved.insert(point)
                        }
                    }
                    if movingBlocks.count < targetCount {
                        continue
                    }
                }

                if config.enabledMechanics.contains(.chaserEnemy) {
                    guard let behavior = config.chaserBehavior else { continue }
                    guard let spawn = selectChaserSpawn(
                        from: pathCells,
                        mainPath: mainPathSet,
                        distancesFromStart: second.distances,
                        walls: walls,
                        start: start,
                        exit: exit,
                        reserved: attemptReserved,
                        protected: protectedTiles
                    ) else {
                        continue
                    }
                    chaserSpawn = ChaserSpawnData(
                        spawn: spawn,
                        behavior: behavior,
                        startDelay: behavior == .direct ? 1.1 : 1.35,
                        repathDelay: behavior == .direct ? 0.28 : 0.34,
                        speedMultiplier: behavior == .direct ? 0.86 : 0.82,
                        trailDelaySteps: behavior == .direct ? 0 : 8
                    )
                    attemptReserved.insert(spawn)
                }

                var orbCandidates = pathCells.filter { !attemptReserved.contains($0) }
                orbCandidates.shuffle(using: &rng)
                let orbCount = min(config.orbCount, orbCandidates.count)
                let orbs = Array(orbCandidates.prefix(orbCount))
                for orb in orbs {
                    specialTiles[orb] = "O"
                    attemptReserved.insert(orb)
                }

                var grid = baseGrid
                applySpecialTiles(specialTiles, to: &grid)
                grid[start.row][start.col] = "S"
                grid[exit.row][exit.col] = "E"

                if config.enabledMechanics.contains(.breakableWalls),
                   !MazeSolvability.requiresBreakableUse(grid: grid, start: start, exit: exit) {
                    let breakableSplitIndex = max(3, Int(Double(mainPath.count) * 0.52))
                    let ensuredBreakable = ensureRequiredBreakable(
                        in: &grid,
                        mainPath: mainPath,
                        splitIndex: breakableSplitIndex,
                        protected: protectedTiles,
                        start: start,
                        exit: exit
                    )
                    if !ensuredBreakable {
                        continue
                    }
                }

                if config.enabledMechanics.contains(.switchBlocks),
                   !MazeSolvability.requiresSwitchBlockUse(grid: grid, start: start, exit: exit) {
                    continue
                }

                let analysis = MazeSolvability.analyze(grid: grid, start: start, exit: exit)
                if analysis.solvable {
                    let rowsStrings = grid.map { String($0) }
                    return MazeData(
                        rows: rows,
                        cols: cols,
                        grid: rowsStrings,
                        start: start,
                        exit: exit,
                        orbs: orbs,
                        t2: t2,
                        t3: t3,
                        shortestPath: shortestPath,
                        movingBlocks: movingBlocks,
                        chaserSpawn: chaserSpawn
                    )
                }

                if config.enabledMechanics.contains(.oneWay) {
                    let repaired = repairArrows(
                        grid: &grid,
                        start: start,
                        exit: exit,
                        minArrowCount: minArrowCount,
                        rng: &rng,
                        mainPath: mainPathSet,
                        maxAttempts: maxArrowRepairAttempts
                    )
                    if repaired {
                        let rowsStrings = grid.map { String($0) }
                        return MazeData(
                            rows: rows,
                            cols: cols,
                            grid: rowsStrings,
                            start: start,
                            exit: exit,
                            orbs: orbs,
                            t2: t2,
                            t3: t3,
                            shortestPath: shortestPath,
                            movingBlocks: movingBlocks,
                            chaserSpawn: chaserSpawn
                        )
                    }
                }
            }
        }

        var fallback: [[Character]] = Array(repeating: Array(repeating: ".", count: cols), count: rows)
        for row in 0..<rows {
            for col in 0..<cols where row == 0 || col == 0 || row == rows - 1 || col == cols - 1 {
                fallback[row][col] = "#"
            }
        }
        let start = GridPoint(row: 1, col: 1)
        let exit = GridPoint(row: rows - 2, col: cols - 2)
        fallback[start.row][start.col] = "S"
        fallback[exit.row][exit.col] = "E"
        let rowsStrings = fallback.map { String($0) }
        let shortestPath = max(1, (rows - 3) + (cols - 3))
        let baseTime = Double(shortestPath) * MazeTiming.stepDuration
        let t3 = max(4.0, baseTime * 1.25)
        let t2 = max(t3 + 1.5, baseTime * 1.6)
        return MazeData(rows: rows, cols: cols, grid: rowsStrings, start: start, exit: exit, orbs: [], t2: t2, t3: t3, shortestPath: shortestPath, movingBlocks: [], chaserSpawn: nil)
    }

    private static func baseGrid(walls: [[Bool]]) -> [[Character]] {
        let rows = walls.count
        let cols = walls.first?.count ?? 0
        var grid: [[Character]] = Array(repeating: Array(repeating: "#", count: cols), count: rows)
        for row in 0..<rows {
            for col in 0..<cols where !walls[row][col] {
                grid[row][col] = "."
            }
        }
        return grid
    }

    private static func applySpecialTiles(_ specialTiles: [GridPoint: Character], to grid: inout [[Character]]) {
        for (point, tile) in specialTiles {
            grid[point.row][point.col] = tile
        }
    }

    private static func ensureRequiredBreakable(
        in grid: inout [[Character]],
        mainPath: [GridPoint],
        splitIndex: Int,
        protected: Set<GridPoint>,
        start: GridPoint,
        exit: GridPoint
    ) -> Bool {
        guard !MazeSolvability.requiresBreakableUse(grid: grid, start: start, exit: exit) else {
            return true
        }

        let candidatePoints = Array(mainPath.dropFirst(splitIndex)).filter {
            !protected.contains($0) && grid[$0.row][$0.col] == "."
        }

        for point in candidatePoints.reversed() {
            grid[point.row][point.col] = "B"
            if MazeSolvability.requiresBreakableUse(grid: grid, start: start, exit: exit),
               MazeSolvability.isSolvable(grid: grid, start: start, exit: exit) {
                return true
            }
            grid[point.row][point.col] = "."
        }

        return false
    }

    private static func stripArrows(from grid: [[Character]]) -> [[Character]] {
        var cleaned = grid
        for row in 0..<cleaned.count {
            for col in 0..<cleaned[row].count {
                if isArrow(cleaned[row][col]) {
                    cleaned[row][col] = "."
                }
            }
        }
        return cleaned
    }

    private static func repairArrows(
        grid: inout [[Character]],
        start: GridPoint,
        exit: GridPoint,
        minArrowCount: Int,
        rng: inout SeededGenerator,
        mainPath: Set<GridPoint>,
        maxAttempts: Int
    ) -> Bool {
        var arrowCount = arrowPositions(in: grid).count
        if arrowCount == 0 { return false }
        let protected = Set<GridPoint>([start, exit] + neighborPoints(of: start, rows: grid.count, cols: grid[0].count) + neighborPoints(of: exit, rows: grid.count, cols: grid[0].count))

        for _ in 0..<maxAttempts {
            let analysis = MazeSolvability.analyze(grid: grid, start: start, exit: exit)
            if analysis.solvable {
                return true
            }
            let currentReachable = analysis.reachablePoints.count

            let arrows = arrowPositions(in: grid)
            if arrows.isEmpty { return false }
            guard let target = pickArrowCandidate(
                arrows,
                reachable: analysis.reachablePoints,
                mainPath: mainPath,
                exit: exit,
                grid: grid,
                rng: &rng
            ) else {
                return false
            }

            let original = grid[target.row][target.col]
            var appliedChange = false
            var removed = false
            var movedTarget: GridPoint?

            if let rotated = bestArrowRotation(at: target, grid: grid, excluding: original) {
                grid[target.row][target.col] = rotated
                appliedChange = true
            } else if arrowCount > minArrowCount {
                grid[target.row][target.col] = "."
                appliedChange = true
                removed = true
            } else if let moveTarget = pickArrowMoveTarget(
                grid: grid,
                protected: protected,
                reachable: analysis.reachablePoints,
                mainPath: mainPath,
                exit: exit,
                rng: &rng
            ) {
                grid[target.row][target.col] = "."
                let newArrow = bestArrowRotation(at: moveTarget, grid: grid, excluding: nil) ?? ">"
                grid[moveTarget.row][moveTarget.col] = newArrow
                movedTarget = moveTarget
                appliedChange = true
            }

            if !appliedChange {
                continue
            }

            let newAnalysis = MazeSolvability.analyze(grid: grid, start: start, exit: exit)
            if newAnalysis.solvable {
                return true
            }

            if newAnalysis.reachablePoints.count >= currentReachable {
                if removed { arrowCount -= 1 }
            } else {
                grid[target.row][target.col] = original
                if let movedTarget = movedTarget {
                    grid[movedTarget.row][movedTarget.col] = "."
                }
            }
        }
        return false
    }

    private static func pickArrowCandidate(
        _ arrows: [GridPoint],
        reachable: Set<GridPoint>,
        mainPath: Set<GridPoint>,
        exit: GridPoint,
        grid: [[Character]],
        rng: inout SeededGenerator
    ) -> GridPoint? {
        guard !arrows.isEmpty else { return nil }
        var scored: [(GridPoint, Int)] = []
        for point in arrows {
            let score = arrowScore(point, grid: grid, reachable: reachable, mainPath: mainPath, exit: exit)
            scored.append((point, score))
        }
        let maxScore = scored.map(\.1).max() ?? 0
        let candidates = scored.filter { $0.1 >= maxScore - 1 }
        let choice = candidates[rng.nextInt(candidates.count)]
        return choice.0
    }

    private static func arrowPositions(in grid: [[Character]]) -> [GridPoint] {
        var points: [GridPoint] = []
        for row in 0..<grid.count {
            for col in 0..<grid[row].count where isArrow(grid[row][col]) {
                points.append(GridPoint(row: row, col: col))
            }
        }
        return points
    }

    private static func rotateArrow(_ tile: Character, using rng: inout SeededGenerator) -> Character {
        let arrows: [Character] = ["^", "v", "<", ">"]
        guard let index = arrows.firstIndex(of: tile) else {
            return arrows[rng.nextInt(arrows.count)]
        }
        var options = arrows
        options.remove(at: index)
        return options[rng.nextInt(options.count)]
    }

    private static func bestArrowRotation(at point: GridPoint, grid: [[Character]], excluding original: Character?) -> Character? {
        let directions = walkableDirections(from: point, grid: grid)
        guard !directions.isEmpty else { return nil }
        var best: (MoveDirection, Int)?
        for direction in directions {
            let candidate = arrowFor(direction)
            if let original = original, candidate == original {
                continue
            }
            let next = point.moved(by: direction)
            let nextNeighbors = neighborCount(next, grid: grid)
            var score = nextNeighbors
            if nextNeighbors <= 1 {
                score -= 2
            }
            if best == nil || score > (best?.1 ?? Int.min) {
                best = (direction, score)
            }
        }
        guard let selected = best?.0 else { return nil }
        return arrowFor(selected)
    }

    private static func pickArrowMoveTarget(
        grid: [[Character]],
        protected: Set<GridPoint>,
        reachable: Set<GridPoint>,
        mainPath: Set<GridPoint>,
        exit: GridPoint,
        rng: inout SeededGenerator
    ) -> GridPoint? {
        var candidates: [GridPoint] = []
        for row in 0..<grid.count {
            for col in 0..<grid[row].count {
                let point = GridPoint(row: row, col: col)
                if protected.contains(point) { continue }
                if grid[row][col] != "." { continue }
                if walkableDirections(from: point, grid: grid).count < 2 { continue }
                candidates.append(point)
            }
        }
        guard !candidates.isEmpty else { return nil }
        var scored: [(GridPoint, Int)] = []
        for point in candidates {
            let score = arrowScore(point, grid: grid, reachable: reachable, mainPath: mainPath, exit: exit)
            scored.append((point, score))
        }
        let maxScore = scored.map(\.1).max() ?? 0
        let filtered = scored.filter { $0.1 >= maxScore - 1 }
        let choice = filtered[rng.nextInt(filtered.count)]
        return choice.0
    }

    private static func arrowScore(
        _ point: GridPoint,
        grid: [[Character]],
        reachable: Set<GridPoint>,
        mainPath: Set<GridPoint>,
        exit: GridPoint
    ) -> Int {
        var score = 0
        if reachable.contains(point) { score += 3 }
        if mainPath.contains(point) { score += 2 }
        if isReachableBoundary(point, grid: grid, reachable: reachable) { score += 4 }
        let dist = abs(point.row - exit.row) + abs(point.col - exit.col)
        if dist <= 4 {
            score += 2
        } else if dist <= 8 {
            score += 1
        }
        if let direction = arrowDirection(at: point, grid: grid),
           isForcedDeadEnd(from: point, direction: direction, grid: grid) {
            score += 3
        }
        return score
    }

    private static func isForcedDeadEnd(from point: GridPoint, direction: MoveDirection, grid: [[Character]]) -> Bool {
        let next = point.moved(by: direction)
        if !isWalkable(next, grid: grid) { return true }
        return neighborCount(next, grid: grid) <= 1
    }

    private static func isReachableBoundary(_ point: GridPoint, grid: [[Character]], reachable: Set<GridPoint>) -> Bool {
        var hasReach = false
        var hasUnreach = false
        for direction in MoveDirection.allCases {
            let next = point.moved(by: direction)
            if isWalkable(next, grid: grid) {
                if reachable.contains(next) {
                    hasReach = true
                } else {
                    hasUnreach = true
                }
            }
        }
        return hasReach && hasUnreach
    }

    private static func neighborPoints(of point: GridPoint, rows: Int, cols: Int) -> [GridPoint] {
        var points: [GridPoint] = []
        for direction in MoveDirection.allCases {
            let next = point.moved(by: direction)
            if next.row >= 0, next.row < rows, next.col >= 0, next.col < cols {
                points.append(next)
            }
        }
        return points
    }

    private static func walkableDirections(from point: GridPoint, grid: [[Character]]) -> [MoveDirection] {
        var directions: [MoveDirection] = []
        for direction in MoveDirection.allCases {
            let next = point.moved(by: direction)
            if isWalkable(next, grid: grid) {
                directions.append(direction)
            }
        }
        return directions
    }

    private static func neighborCount(_ point: GridPoint, grid: [[Character]]) -> Int {
        walkableDirections(from: point, grid: grid).count
    }

    private static func isWalkable(_ point: GridPoint, grid: [[Character]]) -> Bool {
        guard point.row >= 0, point.row < grid.count, point.col >= 0, point.col < grid[0].count else {
            return false
        }
        return grid[point.row][point.col] != "#"
    }

    private static func arrowDirection(at point: GridPoint, grid: [[Character]]) -> MoveDirection? {
        guard point.row >= 0, point.row < grid.count, point.col >= 0, point.col < grid[0].count else {
            return nil
        }
        switch grid[point.row][point.col] {
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

    private static func collectPaths(walls: [[Bool]]) -> [GridPoint] {
        var paths: [GridPoint] = []
        for row in 0..<walls.count {
            for col in 0..<walls[row].count where !walls[row][col] {
                paths.append(GridPoint(row: row, col: col))
            }
        }
        return paths
    }

    private static func bfsDistances(from start: GridPoint, walls: [[Bool]]) -> (distances: [[Int]], farthest: GridPoint, maxDistance: Int) {
        let rows = walls.count
        let cols = walls.first?.count ?? 0
        var distances = Array(repeating: Array(repeating: -1, count: cols), count: rows)
        var queue: [GridPoint] = [start]
        var index = 0
        distances[start.row][start.col] = 0

        var farthest = start
        var maxDistance = 0

        while index < queue.count {
            let current = queue[index]
            index += 1
            let currentDistance = distances[current.row][current.col]
            if currentDistance > maxDistance {
                maxDistance = currentDistance
                farthest = current
            }
            for direction in MoveDirection.allCases {
                let nextRow = current.row + direction.deltaRow
                let nextCol = current.col + direction.deltaCol
                guard nextRow >= 0, nextRow < rows, nextCol >= 0, nextCol < cols else { continue }
                guard !walls[nextRow][nextCol] else { continue }
                guard distances[nextRow][nextCol] == -1 else { continue }
                distances[nextRow][nextCol] = currentDistance + 1
                queue.append(GridPoint(row: nextRow, col: nextCol))
            }
        }
        return (distances, farthest, maxDistance)
    }

    private static func bfsPath(from start: GridPoint, to end: GridPoint, walls: [[Bool]]) -> [GridPoint] {
        let rows = walls.count
        let cols = walls.first?.count ?? 0
        var parents: [[GridPoint?]] = Array(repeating: Array(repeating: nil, count: cols), count: rows)
        var queue: [GridPoint] = [start]
        var index = 0
        parents[start.row][start.col] = start

        while index < queue.count {
            let current = queue[index]
            index += 1
            if current == end { break }
            for direction in MoveDirection.allCases {
                let nextRow = current.row + direction.deltaRow
                let nextCol = current.col + direction.deltaCol
                guard nextRow >= 0, nextRow < rows, nextCol >= 0, nextCol < cols else { continue }
                guard !walls[nextRow][nextCol] else { continue }
                guard parents[nextRow][nextCol] == nil else { continue }
                parents[nextRow][nextCol] = current
                queue.append(GridPoint(row: nextRow, col: nextCol))
            }
        }

        guard parents[end.row][end.col] != nil else { return [] }
        var path: [GridPoint] = []
        var current = end
        path.append(current)
        while current != start {
            guard let parent = parents[current.row][current.col] else { break }
            current = parent
            path.append(current)
        }
        return path.reversed()
    }

    private static func requiredBlockingCandidates(
        on mainPath: [GridPoint],
        walls: [[Bool]],
        start: GridPoint,
        exit: GridPoint,
        reserved: Set<GridPoint>
    ) -> [GridPoint] {
        guard mainPath.count >= 6 else { return [] }

        let splitIndex = max(3, Int(Double(mainPath.count) * 0.5))
        var candidates: [GridPoint] = []
        for point in mainPath.dropFirst(splitIndex).dropLast() {
            guard !reserved.contains(point) else { continue }
            guard isCorridor(point, walls: walls) else { continue }
            var blockedWalls = walls
            blockedWalls[point.row][point.col] = true
            let distances = bfsDistances(from: start, walls: blockedWalls).distances
            if distances[exit.row][exit.col] == -1 {
                candidates.append(point)
            }
        }
        return candidates
    }

    private static func movingTrackCandidates(
        on mainPath: [GridPoint],
        reserved: Set<GridPoint>,
        protected: Set<GridPoint>
    ) -> [[GridPoint]] {
        guard mainPath.count >= 5 else { return [] }

        var candidates: [[GridPoint]] = []
        var index = 0

        while index < mainPath.count - 2 {
            let current = mainPath[index]
            let next = mainPath[index + 1]
            let deltaRow = next.row - current.row
            let deltaCol = next.col - current.col

            guard abs(deltaRow) + abs(deltaCol) == 1 else {
                index += 1
                continue
            }

            var end = index + 1
            while end + 1 < mainPath.count {
                let lhs = mainPath[end]
                let rhs = mainPath[end + 1]
                if rhs.row - lhs.row == deltaRow && rhs.col - lhs.col == deltaCol {
                    end += 1
                } else {
                    break
                }
            }

            let run = Array(mainPath[index...end]).filter { !reserved.contains($0) && !protected.contains($0) }
            if run.count >= 3 {
                if run.count <= 4 {
                    candidates.append(run)
                } else {
                    let mid = run.count / 2
                    let start = max(0, mid - 2)
                    let slice = Array(run[start..<min(run.count, start + 4)])
                    if slice.count >= 3 {
                        candidates.append(slice)
                    }
                }
            }

            index = max(index + 1, end)
        }

        return candidates.sorted {
            if $0.count == $1.count {
                return $0.first!.row + $0.first!.col < $1.first!.row + $1.first!.col
            }
            return $0.count > $1.count
        }
    }

    private static func selectChaserSpawn(
        from pathCells: [GridPoint],
        mainPath: Set<GridPoint>,
        distancesFromStart: [[Int]],
        walls: [[Bool]],
        start: GridPoint,
        exit: GridPoint,
        reserved: Set<GridPoint>,
        protected: Set<GridPoint>
    ) -> GridPoint? {
        let minimumDistance = max(6, max(walls.count, walls[0].count) / 3)
        let candidates = pathCells.filter {
            guard $0 != start, $0 != exit else { return false }
            guard !reserved.contains($0), !protected.contains($0) else { return false }
            guard distancesFromStart[$0.row][$0.col] >= minimumDistance else { return false }
            return neighborCount($0, walls: walls) >= 2
        }

        return candidates.max { lhs, rhs in
            let lhsScore = distancesFromStart[lhs.row][lhs.col] + (mainPath.contains(lhs) ? 0 : 3)
            let rhsScore = distancesFromStart[rhs.row][rhs.col] + (mainPath.contains(rhs) ? 0 : 3)
            if lhsScore == rhsScore {
                return neighborCount(lhs, walls: walls) < neighborCount(rhs, walls: walls)
            }
            return lhsScore < rhsScore
        }
    }

    private static func walkableDirections(from point: GridPoint, walls: [[Bool]]) -> [MoveDirection] {
        var directions: [MoveDirection] = []
        for direction in MoveDirection.allCases {
            let nextRow = point.row + direction.deltaRow
            let nextCol = point.col + direction.deltaCol
            guard nextRow >= 0, nextRow < walls.count, nextCol >= 0, nextCol < walls[0].count else { continue }
            if !walls[nextRow][nextCol] {
                directions.append(direction)
            }
        }
        return directions
    }

    private static func neighborCount(_ point: GridPoint, walls: [[Bool]]) -> Int {
        walkableDirections(from: point, walls: walls).count
    }

    private static func bufferedPoints(around point: GridPoint, maxDistance: Int, rows: Int, cols: Int) -> [GridPoint] {
        guard maxDistance > 0 else { return [point] }
        var points: [GridPoint] = []
        for row in max(0, point.row - maxDistance)...min(rows - 1, point.row + maxDistance) {
            for col in max(0, point.col - maxDistance)...min(cols - 1, point.col + maxDistance) {
                let candidate = GridPoint(row: row, col: col)
                if abs(candidate.row - point.row) + abs(candidate.col - point.col) <= maxDistance {
                    points.append(candidate)
                }
            }
        }
        return points
    }

    private static func isIntersectionOrCorner(_ point: GridPoint, walls: [[Bool]]) -> Bool {
        let directions = walkableDirections(from: point, walls: walls)
        let count = directions.count
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

    private static func isCorridor(_ point: GridPoint, walls: [[Bool]]) -> Bool {
        let directions = walkableDirections(from: point, walls: walls)
        if directions.count != 2 { return false }
        let hasUp = directions.contains(.up)
        let hasDown = directions.contains(.down)
        let hasLeft = directions.contains(.left)
        let hasRight = directions.contains(.right)
        return (hasUp && hasDown) || (hasLeft && hasRight)
    }

    private static func arrowFor(_ direction: MoveDirection) -> Character {
        switch direction {
        case .up:
            return "^"
        case .down:
            return "v"
        case .left:
            return "<"
        case .right:
            return ">"
        }
    }

    private static func isArrow(_ tile: Character) -> Bool {
        tile == "^" || tile == "v" || tile == "<" || tile == ">"
    }

    static func evaluateChallengeCandidate(
        maze: MazeData,
        config: LevelConfig,
        plan: ChallengeGenerationPlan,
        recentFingerprints: [ChallengeMazeFingerprint]
    ) -> ChallengeCandidateEvaluation {
        let grid = maze.grid.map { Array($0) }
        var walkableCount = 0
        var branchCount = 0
        var deadEndCount = 0
        var cornerCount = 0
        var corridorCount = 0

        for row in 0..<grid.count {
            for col in 0..<grid[row].count {
                let point = GridPoint(row: row, col: col)
                guard isWalkable(point, grid: grid) else { continue }
                walkableCount += 1
                let directions = walkableDirections(from: point, grid: grid)
                let neighborTotal = directions.count
                if neighborTotal >= 3 {
                    branchCount += 1
                } else if neighborTotal == 1, point != maze.start, point != maze.exit {
                    deadEndCount += 1
                } else if neighborTotal == 2 {
                    let hasUp = directions.contains(.up)
                    let hasDown = directions.contains(.down)
                    let hasLeft = directions.contains(.left)
                    let hasRight = directions.contains(.right)
                    let opposite = (hasUp && hasDown) || (hasLeft && hasRight)
                    if opposite {
                        corridorCount += 1
                    } else {
                        cornerCount += 1
                    }
                }
            }
        }

        let walkable = Double(max(1, walkableCount))
        let branchDensity = Double(branchCount) / walkable
        let deadEndDensity = Double(deadEndCount) / walkable
        let decisionDensity = Double(branchCount + cornerCount) / walkable
        let corridorDensity = Double(corridorCount) / walkable
        let manhattanDistance = max(1, abs(maze.start.row - maze.exit.row) + abs(maze.start.col - maze.exit.col))
        let directness = Double(maze.shortestPath) / Double(manhattanDistance)

        let fingerprint = ChallengeMazeFingerprint(
            role: plan.role,
            profile: plan.profile,
            sizeBucket: bucket(for: maze.rows, bounds: [15, 19, 23, 27, 33]),
            pathBucket: bucket(for: maze.shortestPath, bounds: [24, 34, 44, 56, 70]),
            branchBucket: densityBucket(for: branchDensity, bounds: [0.07, 0.1, 0.13, 0.17, 0.21]),
            deadEndBucket: densityBucket(for: deadEndDensity, bounds: [0.1, 0.14, 0.18, 0.23, 0.29]),
            directnessBucket: densityBucket(for: directness, bounds: [1.8, 2.1, 2.4, 2.8, 3.2]),
            decisionBucket: densityBucket(for: decisionDensity, bounds: [0.09, 0.12, 0.15, 0.18, 0.22]),
            corridorBucket: densityBucket(for: corridorDensity, bounds: [0.2, 0.28, 0.36, 0.44, 0.52]),
            gimmickSignature: gimmickSignature(for: config)
        )

        let maxSimilarity = recentFingerprints.map { similarityScore(fingerprint, $0) }.max() ?? 0
        let fitScore = challengeCandidateScore(
            shortestPath: maze.shortestPath,
            branchDensity: branchDensity,
            deadEndDensity: deadEndDensity,
            directness: directness,
            decisionDensity: decisionDensity,
            fingerprint: fingerprint,
            plan: plan,
            recentFingerprints: recentFingerprints
        )

        return ChallengeCandidateEvaluation(
            fingerprint: fingerprint,
            shortestPath: maze.shortestPath,
            branchDensity: branchDensity,
            deadEndDensity: deadEndDensity,
            directness: directness,
            decisionDensity: decisionDensity,
            corridorDensity: corridorDensity,
            maxSimilarity: maxSimilarity,
            fitScore: fitScore
        )
    }

    static func challengeCandidateAcceptable(
        _ evaluation: ChallengeCandidateEvaluation,
        plan: ChallengeGenerationPlan,
        recentFingerprints: [ChallengeMazeFingerprint]
    ) -> Bool {
        let pathFits = plan.shortestPathRange.contains(evaluation.shortestPath)
        let branchFits = plan.branchDensityRange.contains(evaluation.branchDensity)
        let deadEndFits = plan.deadEndDensityRange.contains(evaluation.deadEndDensity)
        let directnessFits = plan.directnessRange.contains(evaluation.directness)
        let decisionFits = plan.decisionDensityRange.contains(evaluation.decisionDensity)
        let fitCount = [pathFits, branchFits, deadEndFits, directnessFits, decisionFits].filter { $0 }.count

        guard evaluation.maxSimilarity < 8 else { return false }

        let recentTail = Array(recentFingerprints.suffix(2))
        if recentTail.count == 2 {
            if recentTail.allSatisfy({ $0.sizeBucket == evaluation.fingerprint.sizeBucket }) {
                return false
            }
            if recentTail.allSatisfy({ $0.profile == evaluation.fingerprint.profile }) {
                return false
            }
            if !evaluation.fingerprint.gimmickSignature.isEmpty &&
                recentTail.allSatisfy({ $0.gimmickSignature == evaluation.fingerprint.gimmickSignature }) {
                return false
            }
        }

        if plan.isRewardMaze {
            guard pathFits, directnessFits else { return false }
            return fitCount >= 3
        }

        guard pathFits, decisionFits else { return false }
        return fitCount >= 4
    }

    private static func challengeCandidateScore(
        shortestPath: Int,
        branchDensity: Double,
        deadEndDensity: Double,
        directness: Double,
        decisionDensity: Double,
        fingerprint: ChallengeMazeFingerprint,
        plan: ChallengeGenerationPlan,
        recentFingerprints: [ChallengeMazeFingerprint]
    ) -> Int {
        let pathFits = plan.shortestPathRange.contains(shortestPath)
        let branchFits = plan.branchDensityRange.contains(branchDensity)
        let deadEndFits = plan.deadEndDensityRange.contains(deadEndDensity)
        let directnessFits = plan.directnessRange.contains(directness)
        let decisionFits = plan.decisionDensityRange.contains(decisionDensity)
        let fitCount = [pathFits, branchFits, deadEndFits, directnessFits, decisionFits].filter { $0 }.count
        let maxSimilarity = recentFingerprints.map { similarityScore(fingerprint, $0) }.max() ?? 0

        var score = fitCount * 24
        if pathFits { score += 10 }
        if plan.isRewardMaze && directnessFits { score += 6 }
        if !plan.isRewardMaze && decisionFits { score += 6 }
        score -= maxSimilarity * 6

        let recentTail = Array(recentFingerprints.suffix(2))
        if recentTail.count == 2 {
            if recentTail.allSatisfy({ $0.sizeBucket == fingerprint.sizeBucket }) {
                score -= 10
            }
            if recentTail.allSatisfy({ $0.profile == fingerprint.profile }) {
                score -= 8
            }
            if !fingerprint.gimmickSignature.isEmpty &&
                recentTail.allSatisfy({ $0.gimmickSignature == fingerprint.gimmickSignature }) {
                score -= 8
            }
        }

        return score
    }

    private static func similarityScore(_ lhs: ChallengeMazeFingerprint, _ rhs: ChallengeMazeFingerprint) -> Int {
        var score = 0
        if lhs.role == rhs.role { score += 1 }
        if lhs.profile == rhs.profile { score += 1 }
        if lhs.sizeBucket == rhs.sizeBucket { score += 2 }
        if lhs.pathBucket == rhs.pathBucket { score += 2 }
        if lhs.branchBucket == rhs.branchBucket { score += 2 }
        if lhs.deadEndBucket == rhs.deadEndBucket { score += 1 }
        if lhs.directnessBucket == rhs.directnessBucket { score += 1 }
        if lhs.decisionBucket == rhs.decisionBucket { score += 1 }
        if lhs.corridorBucket == rhs.corridorBucket { score += 1 }
        if lhs.gimmickSignature == rhs.gimmickSignature { score += 2 }
        return score
    }

    private static func gimmickSignature(for config: LevelConfig) -> String {
        let parts = config.enabledMechanics.map(\.rawValue).sorted() + [
            config.teleporterPairs > 0 ? "tp\(min(config.teleporterPairs, 2))" : "",
            config.oneWayDensity > 0 ? "ow\(bucket(for: Int(config.oneWayDensity * 1000), bounds: [18, 32, 48, 64]))" : "",
            config.gatePeriod > 0 ? "gt\(bucket(for: Int(config.gatePeriod * 100), bounds: [80, 90, 100]))" : "",
            config.doorCount > 0 ? "dr\(config.doorCount)" : "",
            config.breakableCount > 0 ? "br\(config.breakableCount)" : "",
            config.switchBlockCount > 0 ? "sb\(config.switchBlockCount)" : "",
            config.movingBlockCount > 0 ? "mb\(config.movingBlockCount)" : "",
            config.chaserBehavior.map { "ch\($0.rawValue)" } ?? ""
        ]
        return parts.filter { !$0.isEmpty }.joined(separator: "_")
    }

    private static func bucket(for value: Int, bounds: [Int]) -> Int {
        for (index, bound) in bounds.enumerated() where value <= bound {
            return index
        }
        return bounds.count
    }

    private static func densityBucket(for value: Double, bounds: [Double]) -> Int {
        for (index, bound) in bounds.enumerated() where value <= bound {
            return index
        }
        return bounds.count
    }

    private static func randomOdd(_ upperBound: Int, using rng: inout SeededGenerator) -> Int {
        let count = max(1, (upperBound - 1) / 2)
        let index = rng.nextInt(count)
        return index * 2 + 1
    }
}

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x123456789ABCDEF : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func nextInt(_ upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        
        return Int(next() % UInt64(upperBound))
    }

    mutating func nextDouble() -> Double {
        Double(next()) / Double(UInt64.max)
    }

    static func seed(for levelIndex: Int, rows: Int, cols: Int, seedSalt: Int = 0, attempt: Int = 0) -> UInt64 {
        var hash: UInt64 = 0x9E3779B97F4A7C15
        mix(&hash, UInt64(bitPattern: Int64(levelIndex)))
        mix(&hash, UInt64(bitPattern: Int64(rows)))
        mix(&hash, UInt64(bitPattern: Int64(cols)))
        mix(&hash, UInt64(bitPattern: Int64(seedSalt)))
        mix(&hash, UInt64(bitPattern: Int64(attempt)))
        return hash
    }

    private static func mix(_ hash: inout UInt64, _ value: UInt64) {
        hash ^= value &+ 0x9E3779B97F4A7C15
        hash = (hash ^ (hash >> 30)) &* 0xBF58476D1CE4E5B9
        hash = (hash ^ (hash >> 27)) &* 0x94D049BB133111EB
        hash ^= hash >> 31
    }
}
