import AppKit
import CoreText

@MainActor
enum StatusLanguageIcon {
    static func image(language: String, filled: Bool) -> NSImage {
        let font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        let attributes = [kCTFontAttributeName: font as Any, kCTForegroundColorAttributeName: NSColor.black.cgColor] as CFDictionary
        let attributed = CFAttributedStringCreate(nil, language as CFString, attributes)!
        let line = CTLineCreateWithAttributedString(attributed)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let textWidth = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, nil))
        let size = NSSize(width: max(26, ceil(textWidth) + 10), height: 18)
        let image = NSImage(size: size, flipped: false) { bounds in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            let rect = bounds.insetBy(dx: 1, dy: 1)
            let path = CGPath(roundedRect: rect, cornerWidth: rect.height / 2, cornerHeight: rect.height / 2, transform: nil)
            context.setFillColor(NSColor.black.cgColor)
            context.setStrokeColor(NSColor.black.cgColor)
            context.setLineWidth(1.6)
            context.addPath(path)
            if filled { context.drawPath(using: .fillStroke) } else { context.strokePath() }
            context.saveGState()
            if filled { context.setBlendMode(.destinationOut) }
            context.textPosition = CGPoint(x: bounds.midX - textWidth / 2, y: bounds.midY - (ascent + descent) / 2 + descent)
            CTLineDraw(line, context)
            context.restoreGState()
            return true
        }
        // Let AppKit tint the icon and size the selected status-item background.
        image.isTemplate = true
        return image
    }
}
