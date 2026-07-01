import SpriteKit

final class ScrollContainerNode: SKNode {
    let contentNode = SKNode()

    private let cropNode = SKCropNode()
    private let maskNode = SKSpriteNode(color: .white, size: .zero)
    private var viewportSize: CGSize = .zero
    private var scrollOffset: CGFloat = 0
    private var contentHeight: CGFloat = 0
    private var momentumVelocity: CGFloat = 0
    private var lastMomentumUpdate: TimeInterval?

    private let velocityCutoff: CGFloat = 14
    private let decelerationPerFrame: CGFloat = 0.94

    override init() {
        super.init()
        cropNode.maskNode = maskNode
        cropNode.addChild(contentNode)
        addChild(cropNode)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func update(size: CGSize) {
        viewportSize = size
        maskNode.size = size
        maskNode.position = .zero
        cropNode.position = .zero
        clampOffset()
        updateContentPosition()
    }

    func setContentHeight(_ height: CGFloat) {
        contentHeight = height
        clampOffset()
        updateContentPosition()
    }

    func scrollTo(_ offset: CGFloat) {
        scrollOffset = clamp(offset)
        updateContentPosition()
    }

    func scrollBy(_ delta: CGFloat) {
        scrollTo(scrollOffset + delta)
    }

    func beginInteraction() {
        momentumVelocity = 0
        lastMomentumUpdate = nil
    }

    func endInteraction(with velocity: CGFloat) {
        guard maxOffset > 0 else {
            momentumVelocity = 0
            lastMomentumUpdate = nil
            return
        }
        momentumVelocity = velocity
        lastMomentumUpdate = nil
    }

    func update(currentTime: TimeInterval) {
        guard abs(momentumVelocity) > velocityCutoff else {
            momentumVelocity = 0
            lastMomentumUpdate = nil
            return
        }
        guard maxOffset > 0 else {
            momentumVelocity = 0
            lastMomentumUpdate = nil
            return
        }

        guard let lastMomentumUpdate else {
            self.lastMomentumUpdate = currentTime
            return
        }

        let dt = CGFloat(min(max(currentTime - lastMomentumUpdate, 1.0 / 240.0), 1.0 / 30.0))
        self.lastMomentumUpdate = currentTime

        let previousOffset = scrollOffset
        scrollOffset = clamp(scrollOffset + momentumVelocity * dt)
        updateContentPosition()

        if abs(scrollOffset - previousOffset) < 0.01,
           (scrollOffset <= 0.001 || scrollOffset >= maxOffset - 0.001) {
            momentumVelocity = 0
            self.lastMomentumUpdate = nil
            return
        }

        momentumVelocity *= pow(decelerationPerFrame, dt * 60)
    }

    func contains(point: CGPoint, in scene: SKScene) -> Bool {
        let local = convert(point, from: scene)
        return abs(local.x) <= viewportSize.width / 2 && abs(local.y) <= viewportSize.height / 2
    }

    var offset: CGFloat {
        scrollOffset
    }

    var maxOffset: CGFloat {
        max(0, contentHeight - viewportSize.height)
    }

    private func clampOffset() {
        scrollOffset = clamp(scrollOffset)
    }

    private func clamp(_ value: CGFloat) -> CGFloat {
        min(max(0, value), maxOffset)
    }

    private func updateContentPosition() {
        guard viewportSize != .zero else { return }
        let verticalInset = max(0, (viewportSize.height - contentHeight) * 0.5)
        contentNode.position = CGPoint(
            x: -viewportSize.width / 2,
            y: viewportSize.height / 2 - verticalInset + scrollOffset
        )
    }
}
