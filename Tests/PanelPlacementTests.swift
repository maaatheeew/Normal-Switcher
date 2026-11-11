import Foundation
import CoreGraphics

@main
struct PanelPlacementTests {
    static func main() {
        let cases: [(CGRect, CGRect)] = [
            (CGRect(x: 1800, y: 1056, width: 40, height: 24), CGRect(x: 0, y: 0, width: 1920, height: 1056)),
            (CGRect(x: 10, y: 744, width: 40, height: 24), CGRect(x: 0, y: 0, width: 1024, height: 744)),
            (CGRect(x: -90, y: 1176, width: 40, height: 24), CGRect(x: -1920, y: 0, width: 1920, height: 1176)),
            (CGRect(x: 400, y: 2256, width: 40, height: 24), CGRect(x: 0, y: 1080, width: 1920, height: 1176))
        ]
        for (anchor, visible) in cases {
            for height: CGFloat in [180, 320, 500, 2000] {
                let panel = PanelPlacement.frame(anchor: anchor, content: CGSize(width: 350, height: height), visible: visible)
                precondition(panel.maxY <= anchor.minY - 6, "Panel must remain below the menu bar")
                precondition(panel.minY >= visible.minY + 6, "Tall panel must fit the screen")
                precondition(panel.minX >= visible.minX + 6 && panel.maxX <= visible.maxX - 6, "Horizontal screen bounds")
            }
        }
        print("PASS: 16 panel placement cases including multiple screens and tall content")
    }
}
