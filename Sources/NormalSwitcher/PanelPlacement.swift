import Foundation
import CoreGraphics

enum PanelPlacement {
    static func frame(anchor: CGRect, content: CGSize, visible: CGRect) -> CGRect {
        let gap: CGFloat = 6
        let top = min(anchor.minY - gap, visible.maxY - gap)
        let height = min(content.height, max(1, top - visible.minY - gap))
        let width = min(content.width, max(1, visible.width - gap * 2))
        let x = min(max(anchor.maxX - width, visible.minX + gap), visible.maxX - width - gap)
        return CGRect(x: x, y: top - height, width: width, height: height)
    }
}
