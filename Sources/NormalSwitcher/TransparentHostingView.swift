import AppKit
import SwiftUI

@MainActor
final class TransparentHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }
}
