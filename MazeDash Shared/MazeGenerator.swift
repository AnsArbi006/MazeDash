import Foundation

struct MazeParameters: Codable, Hashable {
    let rows: Int
    let cols: Int
    let loopFactor: Double
    let branchFactor: Double
    let orbCount: Int
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

                if config.enabledMechanics.contains(.keysDoors) {
                    let doorCount = max(1, min(config.doorCount, max(1, mainPath.count / 8)))
                    let keyCount = max(1, min(config.keyCount, max(1, mainPath.count / 10)))
                    let splitIndex = max(2, Int(Double(mainPath.count) * 0.55))

                    var doorCandidates = Array(mainPath.dropFirst(splitIndex)).filter { !attemptReserved.contains($0) }
                    doorCandidates.shuffle(using: &rng)
                    let doors = Array(doorCandidates.prefix(doorCount))
                    for door in doors {
                        specialTiles[door] = "D"
                        attemptReserved.insert(door)
                    }

                    var keyCandidates = Array(mainPath.prefix(max(2, splitIndex))).filter { !attemptReserved.contains($0) && $0 != start }
                    keyCandidates.shuffle(using: &rng)
                    let keys = Array(keyCandidates.prefix(keyCount))
                    for key in keys {
                        specialTiles[key] = "K"
                        attemptReserved.insert(key)
                    }
                }

                if config.enabledMechanics.contains(.switchDoors) {
                    let doorCount = max(1, min(config.doorCount, max(1, mainPath.count / 8)))
                    let switchCount = max(1, min(config.switchCount, max(1, mainPath.count / 14)))
                    let splitIndex = max(3, Int(Double(mainPath.count) * 0.58))

                    var doorCandidates = Array(mainPath.dropFirst(splitIndex)).filter { !attemptReserved.contains($0) }
                    doorCandidates.shuffle(using: &rng)
                    let doors = Array(doorCandidates.prefix(doorCount))
                    for door in doors {
                        specialTiles[door] = "D"
                        attemptReserved.insert(door)
                    }

                    var switchCandidates = pathCells.filter {
                        !attemptReserved.contains($0)
                        && $0 != start
                        && $0 != exit
                        && !protectedTiles.contains($0)
                        && second.distances[$0.row][$0.col] >= 0
                        && second.distances[$0.row][$0.col] < second.distances[start.row][start.col]
                    }
                    switchCandidates.sort {
                        second.distances[$0.row][$0.col] > second.distances[$1.row][$1.col]
                    }
                    let switches = Array(switchCandidates.prefix(switchCount))
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

                let analysis = MazeSolvability.analyze(grid: grid, start: start, exit: exit)
                if analysis.solvable {
                    let rowsStrings = grid.map { String($0) }
                    return MazeData(rows: rows, cols: cols, grid: rowsStrings, start: start, exit: exit, orbs: orbs, t2: t2, t3: t3, shortestPath: shortestPath)
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
                        return MazeData(rows: rows, cols: cols, grid: rowsStrings, start: start, exit: exit, orbs: orbs, t2: t2, t3: t3, shortestPath: shortestPath)
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
        return MazeData(rows: rows, cols: cols, grid: rowsStrings, start: start, exit: exit, orbs: [], t2: t2, t3: t3, shortestPath: shortestPath)
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
            config.doorCount > 0 ? "dr\(config.doorCount)" : ""
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
