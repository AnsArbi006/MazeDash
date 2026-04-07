import SpriteKit

#if os(iOS) || os(tvOS)
import UIKit
#elseif os(OSX)
import AppKit
#endif

enum FontProvider {
    #if os(iOS) || os(tvOS)
    static func systemFontName(weight: UIFont.Weight) -> String {
        UIFont.systemFont(ofSize: 16, weight: weight).fontName
    }
    #elseif os(OSX)
    static func systemFontName(weight: NSFont.Weight) -> String {
        NSFont.systemFont(ofSize: 16, weight: weight).fontName
    }
    #else
    static func systemFontName(weight: CGFloat) -> String {
        "HelveticaNeue-Bold"
    }
    #endif
}

final class GlossyButtonNode: SKSpriteNode {
    let label: SKLabelNode
    var onTap: (() -> Void)?
    private(set) var isEnabled: Bool = true

    init(text: String, size: CGSize) {
        let texture = TextureFactory.shared.cardTexture(size: size, style: .button)
        label = SKLabelNode(fontNamed: FontProvider.systemFontName(weight: .semibold))
        super.init(texture: texture, color: .clear, size: size)

        label.text = text
        label.fontSize = 16
        label.fontColor = SKColor.white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = .zero
        addChild(label)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        alpha = enabled ? 1.0 : 0.4
    }
}

extension SKScene {
    func glossyButton(at point: CGPoint) -> GlossyButtonNode? {
        for node in nodes(at: point) {
            if let button = node as? GlossyButtonNode {
                return button
            }
            if let button = node.parent as? GlossyButtonNode {
                return button
            }
        }
        return nil
    }
}
