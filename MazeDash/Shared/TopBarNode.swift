import SpriteKit

final class TopBarNode: SKNode {
    let titleLabel: SKLabelNode
    let backButton: ArcadeButtonNode

    private let backgroundNode = SKSpriteNode(color: LevelSelectStyle.Color.topBarFill, size: .zero)
    private let contentCropNode = SKCropNode()
    private let contentMaskNode = SKShapeNode()
    private let innerBandNode = SKSpriteNode(color: SKColor(white: 1.0, alpha: 0.03), size: .zero)
    private let outlineNode = SKShapeNode()

    init(title: String) {
        titleLabel = SKLabelNode(fontNamed: LevelSelectStyle.FontName.title)
        backButton = ArcadeButtonNode(text: "BACK", size: CGSize(width: LevelSelectStyle.Metric.backButtonWidth, height: LevelSelectStyle.Metric.backButtonHeight))

        super.init()

        backButton.setAccentColor(ArcadeStyle.Color.accentMagenta)

        backgroundNode.zPosition = 0
        addChild(backgroundNode)

        contentCropNode.zPosition = 0.5
        addChild(contentCropNode)

        contentMaskNode.fillColor = .white
        contentMaskNode.strokeColor = .clear
        contentCropNode.maskNode = contentMaskNode

        innerBandNode.zPosition = 0.5
        contentCropNode.addChild(innerBandNode)

        outlineNode.zPosition = 1
        outlineNode.fillColor = .clear
        outlineNode.strokeColor = LevelSelectStyle.Color.topBarOutline
        outlineNode.lineWidth = 1.1
        outlineNode.glowWidth = 0.9
        addChild(outlineNode)

        titleLabel.text = title
        titleLabel.fontColor = LevelSelectStyle.Color.textPrimary
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.zPosition = 5
        addChild(titleLabel)

        backButton.label.fontName = LevelSelectStyle.FontName.button
        backButton.label.fontSize = LevelSelectStyle.FontSize.backButton
        backButton.label.fontColor = LevelSelectStyle.Color.textPrimary
        backButton.zPosition = 6
        addChild(backButton)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func layout(width: CGFloat, height: CGFloat) {
        let clampedHeight = max(height, LevelSelectStyle.Metric.backButtonHeight)
        let backgroundSize = CGSize(width: width, height: clampedHeight)
        backgroundNode.texture = TextureFactory.shared.cardTexture(size: backgroundSize, style: .shellPanel)
        backgroundNode.size = backgroundSize
        backgroundNode.position = .zero
        let cornerRadius = min(LevelSelectStyle.Metric.topBarCornerRadius, clampedHeight * 0.5)
        contentMaskNode.path = CGPath(
            roundedRect: CGRect(x: -width / 2, y: -clampedHeight / 2, width: width, height: clampedHeight),
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        innerBandNode.size = CGSize(width: width * 0.54, height: 1)
        innerBandNode.alpha = 0.18
        innerBandNode.position = CGPoint(x: 0, y: clampedHeight * 0.19)

        outlineNode.path = CGPath(
            roundedRect: CGRect(x: -width / 2, y: -clampedHeight / 2, width: width, height: clampedHeight),
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )

        backButton.size = CGSize(width: LevelSelectStyle.Metric.backButtonWidth, height: LevelSelectStyle.Metric.backButtonHeight)
        backButton.label.fontSize = min(LevelSelectStyle.FontSize.backButton, backButton.size.height * 0.38)
        backButton.position = snap(CGPoint(
            x: -width / 2 + LevelSelectStyle.Metric.cardInnerPadding + backButton.size.width / 2,
            y: 0
        ))

        let targetTitleSize = clamp(LevelSelectStyle.FontSize.titleMin, LevelSelectStyle.FontSize.titleMax, width * 0.06)
        titleLabel.fontSize = targetTitleSize
        titleLabel.horizontalAlignmentMode = .center
        let maxTitleWidth = width - (LevelSelectStyle.Metric.backButtonWidth + LevelSelectStyle.Metric.cardInnerPadding + 24) * 2
        if titleLabel.frame.width > maxTitleWidth {
            let scale = maxTitleWidth / max(1, titleLabel.frame.width)
            titleLabel.fontSize = floor(targetTitleSize * scale)
        }
        titleLabel.position = snap(CGPoint(x: 0, y: 1))
    }

    private func clamp(_ minValue: CGFloat, _ maxValue: CGFloat, _ value: CGFloat) -> CGFloat {
        min(maxValue, max(minValue, value))
    }

    private func snap(_ point: CGPoint) -> CGPoint {
        CGPoint(x: round(point.x), y: round(point.y))
    }
}
