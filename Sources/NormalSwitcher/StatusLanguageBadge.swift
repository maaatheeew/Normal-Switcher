import AppKit

@MainActor
final class StatusLanguageBadge: NSView {
    var language = "—" {
        didSet { needsDisplay = true }
    }

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
        let highContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let capsule = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
        NSColor(white: 1, alpha: highContrast ? (dark ? 0.25 : 0.85) : (dark ? 0.10 : 0.40)).setFill()
        capsule.fill()
        NSColor(white: dark ? 1 : 0, alpha: highContrast ? 0.45 : (dark ? 0.20 : 0.10)).setStroke()
        capsule.lineWidth = 0.5
        capsule.stroke()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Self.font,
            .foregroundColor: dark ? NSColor.white : NSColor(white: 0.12, alpha: 1)
        ]
        let label = language as NSString
        let size = label.size(withAttributes: attributes)
        label.draw(at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2), withAttributes: attributes)
    }
}
