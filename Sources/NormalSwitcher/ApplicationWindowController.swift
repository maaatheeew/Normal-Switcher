import AppKit
import SwiftUI

@MainActor
final class ApplicationWindowController: NSWindowController, NSWindowDelegate {
    private let model: SwitcherModel

    init(model: SwitcherModel) {
        self.model = model
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 320),
                              styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = "Normal Switcher"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        let background = NSVisualEffectView()
        background.material = .underWindowBackground
        background.blendingMode = .behindWindow
        background.state = .active
        let hosting = NSHostingView(rootView: ApplicationView(model: model))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: background.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: background.bottomAnchor)
        ])
        window.contentView = background
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) { nil }

    func showApplication() {
        model.refresh()
        model.verifyPendingAccess()
        NSApp.setActivationPolicy(.regular)
        showWindow(nil)
        window?.deminiaturize(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        model.refresh()
        model.verifyPendingAccess()
    }

    func windowWillClose(_ notification: Notification) {
        // Closing the controls leaves the menu-bar service and current Fn mode running.
        NSApp.setActivationPolicy(.accessory)
    }
}
