import AppKit

@MainActor
enum PanelSurface {
    static let radius: CGFloat = 22

    static func container(glass: NSGlassEffectView) -> NSView {
        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.clear.cgColor
        root.layer?.cornerRadius = radius
        root.layer?.masksToBounds = true
        glass.cornerRadius = radius
        glass.wantsLayer = true
        glass.layer?.backgroundColor = NSColor.clear.cgColor
        glass.layer?.cornerRadius = radius
        glass.layer?.masksToBounds = true
        glass.autoresizingMask = [.width, .height]
        root.addSubview(glass)
        return root
    }
}
