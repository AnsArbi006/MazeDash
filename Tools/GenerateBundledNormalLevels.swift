import Foundation

struct GridPoint: Hashable, Codable {
    let row: Int
    let col: Int

    func moved(by direction: MoveDirection) -> GridPoint {
        GridPoint(row: row + direction.deltaRow, col: col + direction.deltaCol)
    }
}

enum MoveDirection: CaseIterable {
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

private func pointLiteral(_ point: GridPoint) -> String {
    "GridPoint(row: \(point.row), col: \(point.col))"
}

private func mazeLiteral(levelId: Int, maze: MazeData) -> String {
    let gridLines = maze.grid.map { "                \(String(reflecting: $0))" }.joined(separator: ",\n")
    let orbLines = maze.orbs.map(pointLiteral).joined(separator: ", ")
    let orbsLiteral = maze.orbs.isEmpty ? "[]" : "[\(orbLines)]"
    return
        "        \(levelId): MazeData(\n" +
        "            rows: \(maze.rows),\n" +
        "            cols: \(maze.cols),\n" +
        "            grid: [\n" +
        gridLines + "\n" +
        "            ],\n" +
        "            start: \(pointLiteral(maze.start)),\n" +
        "            exit: \(pointLiteral(maze.exit)),\n" +
        "            orbs: \(orbsLiteral),\n" +
        "            t2: \(maze.t2),\n" +
        "            t3: \(maze.t3),\n" +
        "            shortestPath: \(maze.shortestPath)\n" +
        "        )"
}

@main
struct GenerateBundledNormalLevelsMain {
    static func main() throws {
        let outputPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("MazeDash/Shared/BundledNormalLevels.swift")
        var entries: [String] = []
        for levelId in 1...30 {
            let config = makeLevelConfig(levelIndex: levelId)
            let maze = MazeGenerator.generate(levelIndex: levelId - 1, config: config)
            entries.append(mazeLiteral(levelId: levelId, maze: maze))
        }

        let fileContents = """
        import Foundation

        enum BundledNormalLevels {
            static let all: [Int: MazeData] = [
        \(entries.joined(separator: ",\n"))
            ]
        }
        """

        try fileContents.write(to: outputPath, atomically: true, encoding: .utf8)
        print("Wrote bundled normal levels to \(outputPath)")
    }
}
