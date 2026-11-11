import AppKit
import SwiftUI
import Combine

@MainActor
final class MenuBarController: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var model: SwitcherModel?
    private var item: NSStatusItem?
    private let languageBadge = StatusLanguageBadge()
    private var panel: SwitcherPanel?
    private var hosting: NSHostingView<SwitcherView>?
    private var observation: AnyCancellable?
    private var outsideClick: Any?
    private var localEvent: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard NSRunningApplication.runningApplications(withBundleIdentifier: "com.maaatheeew.NormalSwitcher")
            .filter({ $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }).isEmpty else {
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        let model = SwitcherModel()
        self.model = model
        item = NSStatusBar.system.statusItem(withLength: 40)
        languageBadge.setAccessibilityElement(false)
        item?.button?.addSubview(languageBadge)
        item?.button?.target = self
        item?.button?.action = #selector(togglePanel)
        model.statusChanged = { [weak self] in self?.updateStatus() }
        observation = model.objectWillChange.sink { [weak self] in
            Task { @MainActor [weak self] in
                await Task.yield()
                if self?.panel?.isVisible == true { self?.positionPanel() }
            }
        }
        updateStatus()
        model.start()
        if ProcessInfo.processInfo.arguments.contains("--show") { showPanel() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.stop()
        if let outsideClick { NSEvent.removeMonitor(outsideClick) }
        if let localEvent { NSEvent.removeMonitor(localEvent) }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showPanel(); return false }
    func windowDidResignKey(_ notification: Notification) { panel?.orderOut(nil) }

    @objc private func togglePanel() {
        if panel?.isVisible == true { panel?.orderOut(nil) } else { showPanel() }
    }

    private func showPanel() {
        guard let model, item?.button?.window != nil else { return }
        if panel == nil {
            let window = SwitcherPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            window.delegate = self
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.level = .popUpMenu
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.isReleasedWhenClosed = false
            let content = NSHostingView(rootView: SwitcherView(model: model))
            content.sizingOptions = [.intrinsicContentSize]
            content.autoresizingMask = [.width, .height]
            let glass = NSGlassEffectView()
            glass.cornerRadius = 22
            glass.style = .regular
            glass.contentView = content
            window.contentView = glass
            panel = window
            hosting = content
            outsideClick = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                MainActor.assumeIsolated { self?.panel?.orderOut(nil) }
            }
            localEvent = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] event in
                let consumed = MainActor.assumeIsolated {
                    guard let self, self.panel?.isVisible == true else { return false }
                    if event.type == .keyDown && event.keyCode == 53 {
                        self.panel?.orderOut(nil)
                        return true
                    }
                    if event.type != .keyDown && event.window != self.panel && event.window != self.item?.button?.window {
                        self.panel?.orderOut(nil)
                    }
                    return false
                }
                return consumed ? nil : event
            }
        }
        model.refresh()
        positionPanel()
        NSApp.activate()
        panel?.makeKeyAndOrderFront(nil)
    }

    private func positionPanel() {
        guard let button = item?.button, let window = button.window, let panel, let hosting else { return }
        let anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
        let visible = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? anchor
        hosting.frame.size.width = Palette.width
        hosting.layoutSubtreeIfNeeded()
        let height = max(180, hosting.fittingSize.height)
        let frame = PanelPlacement.frame(anchor: anchor, content: CGSize(width: Palette.width, height: height), visible: visible)
        panel.setFrame(frame, display: true)
        hosting.frame = CGRect(origin: .zero, size: frame.size)
    }

    private func updateStatus() {
        guard let model else { return }
        let selected = model.layouts.first { $0.id == model.selectedID }
        item?.button?.image = nil
        item?.button?.title = ""
        languageBadge.language = selected?.shortName ?? "—"
        languageBadge.filled = selected?.isASCIICapable ?? false
        let width = languageBadge.preferredWidth
        item?.length = width + 8
        let height = item?.button?.bounds.height ?? 24
        languageBadge.frame = NSRect(x: 4, y: (height - 20) / 2, width: width, height: 20)
        item?.button?.toolTip = selected?.name
        item?.button?.setAccessibilityLabel(selected?.name ?? "Keyboard language")
    }
}
