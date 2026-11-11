import AppKit

@MainActor
final class StatusLanguageBadge: NSView {
    var language = "—" {
        didSet { needsDisplay = true }
    }

    var filled = false { didSet { needsDisplay = true } }

    var preferredWidth: CGFloat {
        let textWidth = (language as NSString).size(withAttributes: [.font: Self.font]).width
        return max(32, ceil(textWidth) + 16)
    }

    private static var font: NSFont { .systemFont(ofSize: 11, weight: .semibold) }

    // The status button owns mouse and accessibility interaction.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let dark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let capsule = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
        let ink = dark ? NSColor.white : NSColor(white: 0.12, alpha: 1)
        ink.setStroke()
        capsule.lineWidth = 1.8
        if filled { ink.setFill(); capsule.fill() }
        capsule.stroke()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Self.font,
            .foregroundColor: filled ? (dark ? NSColor.black : NSColor.white) : ink
        ]
        let label = language as NSString
        let size = label.size(withAttributes: attributes)
        label.draw(at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2), withAttributes: attributes)
    }
}
