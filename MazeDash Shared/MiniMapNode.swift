import SpriteKit

final class MiniMapNode: SKNode {
    let maze: MazeData
    private(set) var mapTexture: SKTexture

    private let backgroundNode: SKSpriteNode
    private let outlineNode = SKShapeNode()
    private let mapSprite: SKSpriteNode
    private let startDot = SKShapeNode(circleOfRadius: 3)
    private let exitDot = SKShapeNode(circleOfRadius: 3)
    private let playerDot = SKShapeNode(circleOfRadius: 3)

    private var sizeValue: CGSize
    private let cardStyle: CardStyle
    private let displayScale: CGFloat
    private var exploredTiles: Set<GridPoint>?
    private var currentPlayerGrid: GridPoint

    init(maze: MazeData, size: CGSize, mapTexture: SKTexture?, cardStyle: CardStyle, displayScale: CGFloat, exploredTiles: Set<GridPoint>? = nil) {
        self.maze = maze
        self.displayScale = max(1, displayScale)
        self.exploredTiles = exploredTiles
        self.currentPlayerGrid = maze.start
        self.mapTexture = mapTexture ?? MiniMapNode.makeMapTexture(maze: maze, displayScale: self.displayScale, exploredTiles: exploredTiles)
        self.sizeValue = size
        self.cardStyle = cardStyle
        self.backgroundNode = SKSpriteNode(texture: TextureFactory.shared.cardTexture(size: size, style: cardStyle))
        self.mapSprite = SKSpriteNode(texture: self.mapTexture)
        super.init()

        backgroundNode.zPosition = 0
        addChild(backgroundNode)

        outlineNode.zPosition = 1
        outlineNode.fillColor = .clear
        outlineNode.strokeColor = ArcadeStyle.Color.panelBorder
        outlineNode.lineWidth = 1.2
        outlineNode.glowWidth = 2
        addChild(outlineNode)

        mapSprite.zPosition = 2
        mapSprite.colorBlendFactor = 0
        addChild(mapSprite)

        startDot.fillColor = ArcadeStyle.Color.accentCyan
        startDot.strokeColor = .clear
        startDot.zPosition = 3
        addChild(startDot)

        exitDot.fillColor = ArcadeStyle.Color.accentMagenta
        exitDot.strokeColor = .clear
        exitDot.zPosition = 3
        addChild(exitDot)

        playerDot.fillColor = ArcadeStyle.Color.accentYellow
        playerDot.strokeColor = .clear
        playerDot.zPosition = 4
        addChild(playerDot)

        applySize(size)
        updateMarkers()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    var size: CGSize {
        sizeValue
    }

    func applySize(_ size: CGSize) {
        sizeValue = size
        backgroundNode.texture = TextureFactory.shared.cardTexture(size: size, style: cardStyle)
        backgroundNode.size = size

        let corner = min(ArcadeStyle.Metric.panelCornerRadius, size.height * 0.4)
        outlineNode.path = CGPath(roundedRect: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height), cornerWidth: corner, cornerHeight: corner, transform: nil)

        let maxMapWidth = size.width * 0.86
        let maxMapHeight = size.height * 0.78
        let aspect = CGFloat(maze.cols) / CGFloat(maze.rows)
        var mapSize = CGSize(width: maxMapWidth, height: maxMapWidth / aspect)
        if mapSize.height > maxMapHeight {
            mapSize.height = maxMapHeight
            mapSize.width = maxMapHeight * aspect
        }
        mapSprite.size = snapSize(mapSize)
        mapSprite.position = .zero

        let dotRadius = max(2, min(5, mapSprite.size.width / CGFloat(max(maze.cols, 12)) * 0.45))
        startDot.path = CGPath(ellipseIn: CGRect(x: -dotRadius, y: -dotRadius, width: dotRadius * 2, height: dotRadius * 2), transform: nil)
        exitDot.path = CGPath(ellipseIn: CGRect(x: -dotRadius, y: -dotRadius, width: dotRadius * 2, height: dotRadius * 2), transform: nil)
        playerDot.path = CGPath(ellipseIn: CGRect(x: -dotRadius, y: -dotRadius, width: dotRadius * 2, height: dotRadius * 2), transform: nil)

        updateMarkers()
    }

    func updatePlayerPosition(_ point: GridPoint) {
        currentPlayerGrid = point
        playerDot.isHidden = !(exploredTiles?.contains(point) ?? true)
        playerDot.position = mapPoint(for: point)
    }

    func updatePlayerPosition(worldPosition: CGPoint, gridOrigin: CGPoint, tileSize: CGFloat) {
        let tileWidth = mapSprite.size.width / CGFloat(maze.cols)
        let tileHeight = mapSprite.size.height / CGFloat(maze.rows)
        let col = (worldPosition.x - gridOrigin.x) / tileSize
        let row = (gridOrigin.y - worldPosition.y) / tileSize
        let x = -mapSprite.size.width / 2 + tileWidth / 2 + col * tileWidth
        let y = mapSprite.size.height / 2 - tileHeight / 2 - row * tileHeight
        playerDot.position = snap(CGPoint(x: x, y: y))
    }

    func updateExplored(_ explored: Set<GridPoint>?) {
        if exploredTiles == explored {
            updateMarkers()
            return
        }
        exploredTiles = explored
        mapTexture = MiniMapNode.makeMapTexture(maze: maze, displayScale: displayScale, exploredTiles: explored)
        mapSprite.texture = mapTexture
        updateMarkers()
    }

    func hitTest(_ scenePoint: CGPoint, in scene: SKScene) -> Bool {
        let localPoint: CGPoint
        if let camera = scene.camera, inParentHierarchy(camera) {
            let cameraPoint = camera.convert(scenePoint, from: scene)
            localPoint = convert(cameraPoint, from: camera)
        } else {
            localPoint = convert(scenePoint, from: scene)
        }
        let halfWidth = sizeValue.width / 2
        let halfHeight = sizeValue.height / 2
        return localPoint.x >= -halfWidth && localPoint.x <= halfWidth && localPoint.y >= -halfHeight && localPoint.y <= halfHeight
    }

    private func updateMarkers() {
        let shouldShowStart = exploredTiles?.contains(maze.start) ?? true
        let shouldShowExit = exploredTiles?.contains(maze.exit) ?? true
        let shouldShowPlayer = exploredTiles?.contains(currentPlayerGrid) ?? true
        startDot.isHidden = !shouldShowStart
        exitDot.isHidden = !shouldShowExit
        playerDot.isHidden = !shouldShowPlayer
        startDot.position = mapPoint(for: maze.start)
        exitDot.position = mapPoint(for: maze.exit)
        playerDot.position = mapPoint(for: currentPlayerGrid)
    }

    private func mapPoint(for grid: GridPoint) -> CGPoint {
        let tileWidth = mapSprite.size.width / CGFloat(maze.cols)
        let tileHeight = mapSprite.size.height / CGFloat(maze.rows)
        let x = -mapSprite.size.width / 2 + tileWidth / 2 + CGFloat(grid.col) * tileWidth
        let y = mapSprite.size.height / 2 - tileHeight / 2 - CGFloat(grid.row) * tileHeight
        return snap(CGPoint(x: x, y: y))
    }

    private func snap(_ point: CGPoint) -> CGPoint {
        CGPoint(x: round(point.x), y: round(point.y))
    }

    private func snapSize(_ size: CGSize) -> CGSize {
        CGSize(width: round(size.width), height: round(size.height))
    }

    static func makeMapTexture(maze: MazeData, displayScale: CGFloat, exploredTiles: Set<GridPoint>? = nil) -> SKTexture {
        let maxDimension = max(maze.rows, maze.cols)
        let targetPixels: CGFloat = 180
        let cellSize = max(2, min(10, Int(round(targetPixels / CGFloat(maxDimension)))))
        let width = maze.cols * cellSize
        let height = maze.rows * cellSize
        let size = CGSize(width: CGFloat(width), height: CGFloat(height))
        let scale = max(1, displayScale)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: Int(size.width * scale),
            height: Int(size.height * scale),
            bitsPerComponent: 8,
            bytesPerRow: Int(size.width * scale) * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return SKTexture()
        }

        context.scaleBy(x: scale, y: scale)
        #if os(OSX)
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        #endif

        let wallColor = SKColor(white: 0.08, alpha: 1.0).cgColor
        let floorColor = SKColor(white: 0.22, alpha: 1.0).cgColor
        let hiddenColor = SKColor(white: 0.0, alpha: 1.0).cgColor

        context.setFillColor(hiddenColor)
        context.fill(CGRect(origin: .zero, size: size))

        for row in 0..<maze.rows {
            for col in 0..<maze.cols {
                let point = GridPoint(row: row, col: col)
                if let exploredTiles, !exploredTiles.contains(point) {
                    continue
                }
                let tile = maze.tile(at: GridPoint(row: row, col: col)) ?? "#"
                let isWall = tile == "#"
                let x = CGFloat(col * cellSize)
                let y = CGFloat((maze.rows - 1 - row) * cellSize)
                context.setFillColor(isWall ? wallColor : floorColor)
                context.fill(CGRect(x: x, y: y, width: CGFloat(cellSize), height: CGFloat(cellSize)))
            }
        }

        guard let image = context.makeImage() else { return SKTexture() }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        return texture
    }

}
