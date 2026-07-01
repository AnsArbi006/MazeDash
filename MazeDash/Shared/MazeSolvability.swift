import Foundation

enum MazeSolvability {
    struct State: Hashable {
        let point: GridPoint
        let direction: MoveDirection
        let hasKey: Bool
        let switchActive: Bool
        let breakHits: [UInt8]
    }

    struct Analysis {
        let solvable: Bool
        let visitedStates: Set<State>
        let reachablePoints: Set<GridPoint>
    }

    private struct Context {
        let grid: [[Character]]
        let rows: Int
        let cols: Int
        let exit: GridPoint
        let exitRequiresKey: Bool
        let teleporterPairs: [GridPoint: GridPoint]
        let breakableIndices: [GridPoint: Int]
    }

    private struct Transition {
        let nextState: State
        let touchedPoints: [GridPoint]
    }

    struct EasyBotLoopTracker {
        struct TrackerState: Hashable {
            let point: GridPoint
            let facing: MoveDirection?
        }

        struct TrackerTransition: Hashable {
            let from: GridPoint
            let to: GridPoint
        }

        private let maxHistory = 24
        private(set) var recentPoints: [GridPoint] = []
        private(set) var recentStates: [TrackerState] = []
        private(set) var recentTransitions: [TrackerTransition] = []
        private var visitedPoints = Set<GridPoint>()
        private var bannedTransitions: [TrackerTransition: Int] = [:]
        private(set) var stepsSinceNewPoint = 0

        mutating func seed(at point: GridPoint, facing: MoveDirection?) {
            recentPoints = [point]
            recentStates = [TrackerState(point: point, facing: facing)]
            recentTransitions = []
            visitedPoints = [point]
            bannedTransitions.removeAll()
            stepsSinceNewPoint = 0
        }

        mutating func recordMove(from: GridPoint, to: GridPoint, facing: MoveDirection?) {
            advanceBanDecay()

            recentPoints.append(to)
            if recentPoints.count > maxHistory {
                recentPoints.removeFirst(recentPoints.count - maxHistory)
            }

            recentStates.append(TrackerState(point: to, facing: facing))
            if recentStates.count > maxHistory {
                recentStates.removeFirst(recentStates.count - maxHistory)
            }

            recentTransitions.append(TrackerTransition(from: from, to: to))
            if recentTransitions.count > maxHistory {
                recentTransitions.removeFirst(recentTransitions.count - maxHistory)
            }

            if visitedPoints.insert(to).inserted {
                stepsSinceNewPoint = 0
            } else {
                stepsSinceNewPoint += 1
            }
        }

        mutating func chooseDirection(
            from point: GridPoint,
            facing: MoveDirection?,
            candidates: [MoveDirection]
        ) -> MoveDirection? {
            guard !candidates.isEmpty else { return nil }
            guard candidates.count > 1 else { return candidates[0] }

            let currentState = TrackerState(point: point, facing: facing)
            let recentStateHits = recentStates.suffix(14).filter { $0 == currentState }.count
            let recentWindow = Array(recentTransitions.suffix(14))

            var transitionCounts: [TrackerTransition: Int] = [:]
            for direction in candidates {
                let transition = TrackerTransition(from: point, to: point.moved(by: direction))
                transitionCounts[transition] = recentWindow.filter { $0 == transition }.count
            }

            var shouldEscape = recentStateHits >= 2 || stepsSinceNewPoint >= 10
            if transitionCounts.values.contains(where: { $0 >= 2 }) {
                shouldEscape = true
            }

            if let bounceTransition = bounceLoopTransition(currentPoint: point) {
                bannedTransitions[bounceTransition] = max(bannedTransitions[bounceTransition] ?? 0, 4)
                shouldEscape = true
            }

            if shouldEscape {
                for (transition, hits) in transitionCounts where hits >= 2 {
                    bannedTransitions[transition] = max(bannedTransitions[transition] ?? 0, 3)
                }

                if stepsSinceNewPoint >= 10,
                   let mostRecent = recentTransitions.last,
                   mostRecent.from == point {
                    bannedTransitions[mostRecent] = max(bannedTransitions[mostRecent] ?? 0, 2)
                }
            }

            for direction in candidates {
                let transition = TrackerTransition(from: point, to: point.moved(by: direction))
                if (bannedTransitions[transition] ?? 0) > 0 {
                    continue
                }
                return direction
            }

            return candidates[0]
        }

        private func bounceLoopTransition(currentPoint: GridPoint) -> TrackerTransition? {
            guard recentPoints.count >= 4 else { return nil }
            let last4 = Array(recentPoints.suffix(4))
            guard last4[0] == last4[2], last4[1] == last4[3], last4[3] == currentPoint else { return nil }
            return TrackerTransition(from: currentPoint, to: last4[2])
        }

        private mutating func advanceBanDecay() {
            if bannedTransitions.isEmpty { return }
            bannedTransitions = bannedTransitions.reduce(into: [:]) { partial, entry in
                let nextValue = entry.value - 1
                if nextValue > 0 {
                    partial[entry.key] = nextValue
                }
            }
        }
    }

    static func isSolvable(grid: [[Character]], start: GridPoint, exit: GridPoint) -> Bool {
        analyze(grid: grid, start: start, exit: exit).solvable
    }

    static func analyze(grid: [[Character]], start: GridPoint, exit: GridPoint) -> Analysis {
        let rows = grid.count
        let cols = grid.first?.count ?? 0
        guard rows > 0, cols > 0 else {
            return Analysis(solvable: false, visitedStates: [], reachablePoints: [])
        }

        if start == exit {
            return Analysis(solvable: true, visitedStates: [], reachablePoints: [start])
        }

        let context = Context(
            grid: grid,
            rows: rows,
            cols: cols,
            exit: exit,
            exitRequiresKey: grid.contains { row in row.contains("K") || row.contains("D") },
            teleporterPairs: buildTeleporterPairs(grid: grid),
            breakableIndices: buildBreakableIndices(grid: grid)
        )

        let initialHasKey = keyStatus(at: start, hasKey: false, context: context)
        let initialSwitchActive = switchStatus(at: start, switchActive: false, context: context)
        let initialBreakHits = Array(repeating: UInt8(0), count: context.breakableIndices.count)
        var visited = Set<State>()
        var queue: [State] = []
        var index = 0
        var reachablePoints = Set<GridPoint>([start])

        for direction in validDirections(from: start, hasKey: initialHasKey, switchActive: initialSwitchActive, breakHits: initialBreakHits, context: context) {
            let state = State(point: start, direction: direction, hasKey: initialHasKey, switchActive: initialSwitchActive, breakHits: initialBreakHits)
            if visited.insert(state).inserted {
                queue.append(state)
            }
        }

        while index < queue.count {
            let state = queue[index]
            index += 1
            reachablePoints.insert(state.point)

            if state.point == exit {
                return Analysis(solvable: true, visitedStates: visited, reachablePoints: reachablePoints)
            }

            for transition in nextTransitions(from: state, context: context) {
                for point in transition.touchedPoints {
                    reachablePoints.insert(point)
                }
                if transition.nextState.point == exit {
                    reachablePoints.insert(exit)
                    return Analysis(solvable: true, visitedStates: visited, reachablePoints: reachablePoints)
                }
                if visited.insert(transition.nextState).inserted {
                    queue.append(transition.nextState)
                }
            }
        }

        return Analysis(solvable: false, visitedStates: visited, reachablePoints: reachablePoints)
    }

    static func analyze(grid: [String], start: GridPoint, exit: GridPoint) -> Analysis {
        analyze(grid: grid.map { Array($0) }, start: start, exit: exit)
    }

    static func requiresBreakableUse(grid: [[Character]], start: GridPoint, exit: GridPoint) -> Bool {
        var blockedGrid = grid
        var hasBreakable = false

        for row in 0..<blockedGrid.count {
            for col in 0..<blockedGrid[row].count where blockedGrid[row][col] == "B" {
                blockedGrid[row][col] = "#"
                hasBreakable = true
            }
        }

        guard hasBreakable else { return false }
        return !isSolvable(grid: blockedGrid, start: start, exit: exit)
    }

    static func requiresSwitchBlockUse(grid: [[Character]], start: GridPoint, exit: GridPoint) -> Bool {
        var blockedGrid = grid
        var hasSwitchBlock = false
        var hasSwitch = false

        for row in 0..<blockedGrid.count {
            for col in 0..<blockedGrid[row].count {
                switch blockedGrid[row][col] {
                case "X":
                    blockedGrid[row][col] = "#"
                    hasSwitchBlock = true
                case "T":
                    hasSwitch = true
                default:
                    break
                }
            }
        }

        guard hasSwitch, hasSwitchBlock else { return false }
        return !isSolvable(grid: blockedGrid, start: start, exit: exit)
    }

    static func hasReachableSinkState(grid: [[Character]], start: GridPoint, exit: GridPoint) -> Bool {
        let analysis = analyze(grid: grid, start: start, exit: exit)
        guard analysis.solvable else { return true }

        let rows = grid.count
        let cols = grid.first?.count ?? 0
        guard rows > 0, cols > 0 else { return true }

        let context = Context(
            grid: grid,
            rows: rows,
            cols: cols,
            exit: exit,
            exitRequiresKey: grid.contains { row in row.contains("K") || row.contains("D") },
            teleporterPairs: buildTeleporterPairs(grid: grid),
            breakableIndices: buildBreakableIndices(grid: grid)
        )

        for state in analysis.visitedStates {
            if state.point == exit { continue }
            if nextTransitions(from: state, context: context).isEmpty {
                return true
            }
        }

        return false
    }

    static func hasFairBreakableSwitchCombo(grid: [[Character]], start: GridPoint, exit: GridPoint) -> Bool {
        let hasBreakable = grid.contains { row in row.contains("B") }
        let hasSwitch = grid.contains { row in row.contains("T") || row.contains("X") }
        guard hasBreakable && hasSwitch else { return true }

        let analysis = analyze(grid: grid, start: start, exit: exit)
        guard analysis.solvable else { return false }
        guard !hasReachableSinkState(grid: grid, start: start, exit: exit) else { return false }

        for row in 0..<grid.count {
            for col in 0..<grid[row].count where grid[row][col] == "T" {
                let point = GridPoint(row: row, col: col)
                guard analysis.reachablePoints.contains(point) else { return false }
            }
        }

        for row in 0..<grid.count {
            for col in 0..<grid[row].count where grid[row][col] == "B" {
                let point = GridPoint(row: row, col: col)
                let hasReachableAdjacency = MoveDirection.allCases.contains { direction in
                    analysis.reachablePoints.contains(point.moved(by: direction))
                }
                guard hasReachableAdjacency else { return false }
            }
        }

        return true
    }

    static func canApproachLockedExitWithoutKey(grid: [[Character]], start: GridPoint, exit: GridPoint) -> Bool {
        let rows = grid.count
        let cols = grid.first?.count ?? 0
        guard rows > 0, cols > 0 else { return false }
        guard grid.contains(where: { row in row.contains("K") }) else { return false }

        let context = Context(
            grid: grid,
            rows: rows,
            cols: cols,
            exit: exit,
            exitRequiresKey: true,
            teleporterPairs: buildTeleporterPairs(grid: grid),
            breakableIndices: buildBreakableIndices(grid: grid)
        )

        let initialHasKey = false
        let initialSwitchActive = switchStatus(at: start, switchActive: false, context: context)
        let initialBreakHits = Array(repeating: UInt8(0), count: context.breakableIndices.count)
        var visited = Set<State>()
        var queue: [State] = []
        var index = 0

        if isAdjacentToExit(start, exit: exit) {
            return true
        }

        for direction in validDirections(from: start, hasKey: initialHasKey, switchActive: initialSwitchActive, breakHits: initialBreakHits, context: context) {
            let state = State(point: start, direction: direction, hasKey: initialHasKey, switchActive: initialSwitchActive, breakHits: initialBreakHits)
            if visited.insert(state).inserted {
                queue.append(state)
            }
        }

        while index < queue.count {
            let state = queue[index]
            index += 1

            if !state.hasKey, isAdjacentToExit(state.point, exit: exit) {
                return true
            }

            for transition in nextTransitions(from: state, context: context) {
                if !transition.nextState.hasKey, isAdjacentToExit(transition.nextState.point, exit: exit) {
                    return true
                }
                if visited.insert(transition.nextState).inserted {
                    queue.append(transition.nextState)
                }
            }
        }

        return false
    }

    static func shortestCompletionSteps(grid: [String], start: GridPoint, exit: GridPoint) -> Int? {
        shortestCompletionSteps(grid: grid.map { Array($0) }, start: start, exit: exit)
    }

    static func easyBotCompletionSteps(grid: [String], start: GridPoint, exit: GridPoint) -> Int? {
        let gridCharacters = grid.map { Array($0) }
        let rows = gridCharacters.count
        let cols = gridCharacters.first?.count ?? 0
        guard rows > 0, cols > 0 else { return nil }
        guard start != exit else { return 0 }

        let context = Context(
            grid: gridCharacters,
            rows: rows,
            cols: cols,
            exit: exit,
            exitRequiresKey: gridCharacters.contains { row in row.contains("K") || row.contains("D") },
            teleporterPairs: buildTeleporterPairs(grid: gridCharacters),
            breakableIndices: buildBreakableIndices(grid: gridCharacters)
        )

        var point = start
        var facing: MoveDirection?
        var hasKey = keyStatus(at: start, hasKey: false, context: context)
        var switchActive = switchStatus(at: start, switchActive: false, context: context)
        var breakHits = Array(repeating: UInt8(0), count: context.breakableIndices.count)
        var loopTracker = EasyBotLoopTracker()
        loopTracker.seed(at: start, facing: nil)

        let maxSteps = max(rows * cols * 24, 240)
        for step in 1...maxSteps {
            let candidates = easyBotCandidates(
                from: point,
                facing: facing,
                hasKey: hasKey,
                switchActive: switchActive,
                breakHits: breakHits,
                context: context
            )
            guard let direction = loopTracker.chooseDirection(from: point, facing: facing, candidates: candidates) else {
                return nil
            }
            guard let transition = advance(from: point, direction: direction, hasKey: hasKey, switchActive: switchActive, breakHits: breakHits, context: context) else {
                return nil
            }
            let previousPoint = point
            point = transition.nextState.point
            facing = direction
            hasKey = transition.nextState.hasKey
            switchActive = transition.nextState.switchActive
            breakHits = transition.nextState.breakHits
            loopTracker.recordMove(from: previousPoint, to: point, facing: facing)
            if point == exit {
                return step
            }
        }

        return nil
    }

    private static func nextTransitions(from state: State, context: Context) -> [Transition] {
        let currentPoint = state.point
        let currentHasKey = keyStatus(at: currentPoint, hasKey: state.hasKey, context: context)
        let currentSwitchActive = state.switchActive
        let currentBreakHits = state.breakHits

        let candidateDirections: [MoveDirection]
        if let forced = arrowDirection(at: currentPoint, context: context) {
            if canAttempt(currentPoint.moved(by: forced), hasKey: currentHasKey, switchActive: currentSwitchActive, breakHits: currentBreakHits, context: context) {
                candidateDirections = [forced]
            } else {
                candidateDirections = validDirections(from: currentPoint, hasKey: currentHasKey, switchActive: currentSwitchActive, breakHits: currentBreakHits, context: context)
            }
        } else {
            let forward = currentPoint.moved(by: state.direction)
            if isDecisionTile(currentPoint, hasKey: currentHasKey, switchActive: currentSwitchActive, breakHits: currentBreakHits, context: context) ||
                !canAttempt(forward, hasKey: currentHasKey, switchActive: currentSwitchActive, breakHits: currentBreakHits, context: context) {
                candidateDirections = validDirections(from: currentPoint, hasKey: currentHasKey, switchActive: currentSwitchActive, breakHits: currentBreakHits, context: context)
            } else {
                candidateDirections = [state.direction]
            }
        }

        var transitions: [Transition] = []
        for direction in candidateDirections {
            guard let transition = advance(from: currentPoint, direction: direction, hasKey: currentHasKey, switchActive: currentSwitchActive, breakHits: currentBreakHits, context: context) else {
                continue
            }
            transitions.append(transition)
        }
        return transitions
    }

    private static func advance(from point: GridPoint, direction: MoveDirection, hasKey: Bool, switchActive: Bool, breakHits: [UInt8], context: Context) -> Transition? {
        let next = point.moved(by: direction)
        if let breakableIndex = context.breakableIndices[next], breakHits[breakableIndex] < 3 {
            var nextBreakHits = breakHits
            nextBreakHits[breakableIndex] = min(3, nextBreakHits[breakableIndex] + 1)
            let nextState = State(point: point, direction: direction, hasKey: hasKey, switchActive: switchActive, breakHits: nextBreakHits)
            return Transition(nextState: nextState, touchedPoints: [])
        }
        guard canEnter(next, hasKey: hasKey, switchActive: switchActive, breakHits: breakHits, context: context) else {
            return nil
        }

        var destination = next
        var touchedPoints: [GridPoint] = [next]
        var nextHasKey = keyStatus(at: next, hasKey: hasKey, context: context)
        var nextSwitchActive = switchStatus(at: next, switchActive: switchActive, context: context)
        if let teleported = context.teleporterPairs[next] {
            destination = teleported
            touchedPoints.append(teleported)
            nextHasKey = keyStatus(at: teleported, hasKey: nextHasKey, context: context)
            nextSwitchActive = switchStatus(at: teleported, switchActive: nextSwitchActive, context: context)
        }

        let nextState = State(point: destination, direction: direction, hasKey: nextHasKey, switchActive: nextSwitchActive, breakHits: breakHits)
        return Transition(nextState: nextState, touchedPoints: touchedPoints)
    }

    private static func shortestCompletionSteps(grid: [[Character]], start: GridPoint, exit: GridPoint) -> Int? {
        let rows = grid.count
        let cols = grid.first?.count ?? 0
        guard rows > 0, cols > 0 else { return nil }
        guard start != exit else { return 0 }

        let context = Context(
            grid: grid,
            rows: rows,
            cols: cols,
            exit: exit,
            exitRequiresKey: grid.contains { row in row.contains("K") || row.contains("D") },
            teleporterPairs: buildTeleporterPairs(grid: grid),
            breakableIndices: buildBreakableIndices(grid: grid)
        )

        let startHasKey = keyStatus(at: start, hasKey: false, context: context)
        let startSwitchActive = switchStatus(at: start, switchActive: false, context: context)
        let startBreakHits = Array(repeating: UInt8(0), count: context.breakableIndices.count)
        let startStates = validDirections(from: start, hasKey: startHasKey, switchActive: startSwitchActive, breakHits: startBreakHits, context: context).map {
            State(point: start, direction: $0, hasKey: startHasKey, switchActive: startSwitchActive, breakHits: startBreakHits)
        }

        guard !startStates.isEmpty else { return nil }

        var queue: [(State, Int)] = startStates.map { ($0, 0) }
        var visited = Set<State>(startStates)
        var index = 0

        while index < queue.count {
            let (state, distance) = queue[index]
            index += 1
            if state.point == exit {
                return distance
            }

            for transition in nextTransitions(from: state, context: context) {
                if transition.nextState.point == exit {
                    return distance + 1
                }
                if visited.insert(transition.nextState).inserted {
                    queue.append((transition.nextState, distance + 1))
                }
            }
        }

        return nil
    }

    private static func canEnter(_ point: GridPoint, hasKey: Bool, switchActive: Bool, breakHits: [UInt8], context: Context) -> Bool {
        guard let tile = tile(at: point, context: context) else { return false }
        if tile == "#" { return false }
        if tile == "E", context.exitRequiresKey { return hasKey }
        if tile == "X" { return switchActive }
        if tile == "B", let breakableIndex = context.breakableIndices[point] {
            return breakHits[breakableIndex] >= 3
        }
        // Gates are solvable in principle because the player can wait and retry on an open phase.
        return true
    }

    private static func canAttempt(_ point: GridPoint, hasKey: Bool, switchActive: Bool, breakHits: [UInt8], context: Context) -> Bool {
        guard let tile = tile(at: point, context: context) else { return false }
        if tile == "B", let breakableIndex = context.breakableIndices[point], breakHits[breakableIndex] < 3 {
            return true
        }
        return canEnter(point, hasKey: hasKey, switchActive: switchActive, breakHits: breakHits, context: context)
    }

    private static func validDirections(from point: GridPoint, hasKey: Bool, switchActive: Bool, breakHits: [UInt8], context: Context) -> [MoveDirection] {
        MoveDirection.allCases.filter { direction in
            canAttempt(point.moved(by: direction), hasKey: hasKey, switchActive: switchActive, breakHits: breakHits, context: context)
        }
    }

    private static func easyBotCandidates(
        from point: GridPoint,
        facing: MoveDirection?,
        hasKey: Bool,
        switchActive: Bool,
        breakHits: [UInt8],
        context: Context
    ) -> [MoveDirection] {
        if let forced = arrowDirection(at: point, context: context),
           canAttempt(point.moved(by: forced), hasKey: hasKey, switchActive: switchActive, breakHits: breakHits, context: context) {
            return [forced]
        }

        if let facing {
            let forward = point.moved(by: facing)
            if canAttempt(forward, hasKey: hasKey, switchActive: switchActive, breakHits: breakHits, context: context),
               !isDecisionTile(point, hasKey: hasKey, switchActive: switchActive, breakHits: breakHits, context: context) {
                return [facing]
            }
            let ordered = [leftTurn(from: facing), facing, rightTurn(from: facing), opposite(of: facing)]
            return ordered.filter {
                canAttempt(point.moved(by: $0), hasKey: hasKey, switchActive: switchActive, breakHits: breakHits, context: context)
            }
        }

        return [.left, .up, .right, .down].filter {
            canAttempt(point.moved(by: $0), hasKey: hasKey, switchActive: switchActive, breakHits: breakHits, context: context)
        }
    }

    private static func isDecisionTile(_ point: GridPoint, hasKey: Bool, switchActive: Bool, breakHits: [UInt8], context: Context) -> Bool {
        let directions = validDirections(from: point, hasKey: hasKey, switchActive: switchActive, breakHits: breakHits, context: context)
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

    private static func keyStatus(at point: GridPoint, hasKey: Bool, context: Context) -> Bool {
        hasKey || tile(at: point, context: context) == "K"
    }

    private static func isAdjacentToExit(_ point: GridPoint, exit: GridPoint) -> Bool {
        abs(point.row - exit.row) + abs(point.col - exit.col) == 1
    }

    private static func switchStatus(at point: GridPoint, switchActive: Bool, context: Context) -> Bool {
        tile(at: point, context: context) == "T" ? !switchActive : switchActive
    }

    private static func tile(at point: GridPoint, context: Context) -> Character? {
        guard point.row >= 0, point.row < context.rows, point.col >= 0, point.col < context.cols else {
            return nil
        }
        return context.grid[point.row][point.col]
    }

    private static func arrowDirection(at point: GridPoint, context: Context) -> MoveDirection? {
        guard let tile = tile(at: point, context: context) else { return nil }
        switch tile {
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

    private static func leftTurn(from direction: MoveDirection) -> MoveDirection {
        switch direction {
        case .up: return .left
        case .down: return .right
        case .left: return .down
        case .right: return .up
        }
    }

    private static func rightTurn(from direction: MoveDirection) -> MoveDirection {
        switch direction {
        case .up: return .right
        case .down: return .left
        case .left: return .up
        case .right: return .down
        }
    }

    private static func opposite(of direction: MoveDirection) -> MoveDirection {
        switch direction {
        case .up: return .down
        case .down: return .up
        case .left: return .right
        case .right: return .left
        }
    }

    private static func buildTeleporterPairs(grid: [[Character]]) -> [GridPoint: GridPoint] {
        var groups: [String: [GridPoint]] = [:]
        for row in 0..<grid.count {
            for col in 0..<grid[row].count {
                let tile = grid[row][col]
                guard isTeleporterTile(tile) else { continue }
                let key = String(tile).lowercased()
                groups[key, default: []].append(GridPoint(row: row, col: col))
            }
        }

        var pairs: [GridPoint: GridPoint] = [:]
        for points in groups.values where points.count == 2 {
            pairs[points[0]] = points[1]
            pairs[points[1]] = points[0]
        }
        return pairs
    }

    private static func buildBreakableIndices(grid: [[Character]]) -> [GridPoint: Int] {
        var mapping: [GridPoint: Int] = [:]
        var nextIndex = 0
        for row in 0..<grid.count {
            for col in 0..<grid[row].count where grid[row][col] == "B" {
                mapping[GridPoint(row: row, col: col)] = nextIndex
                nextIndex += 1
            }
        }
        return mapping
    }

    private static func isTeleporterTile(_ tile: Character) -> Bool {
        switch tile {
        case "#", ".", "S", "E", "O", "K", "D", "G", "T", "B", "X", "^", "v", "<", ">":
            return false
        default:
            return String(tile).rangeOfCharacter(from: CharacterSet.letters) != nil
        }
    }
}
