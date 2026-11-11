import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var model: SwitcherModel?
    private var item: NSStatusItem?
    private let popover = NSPopover()
    private let languageBadge = StatusLanguageBadge()
    private var designWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard NSRunningApplication.runningApplications(withBundleIdentifier: "com.maaatheeew.NormalSwitcher")
            .filter({ $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }).isEmpty else {
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        let model = SwitcherModel()
        self.model = model
        item = NSStatusBar.system.statusItem(withLength: 34)
        languageBadge.setAccessibilityElement(false)
        item?.button?.addSubview(languageBadge)
        item?.button?.target = self
        item?.button?.action = #selector(togglePopover)
        item?.button?.setAccessibilityLabel("Normal Switcher")
        model.statusChanged = { [weak self] in self?.updateStatus() }
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: SwitcherView(model: model))
        updateStatus()
        model.start()
        if ProcessInfo.processInfo.arguments.contains("--window") || UserDefaults.standard.bool(forKey: "showDesignWindow") {
            NSApp.setActivationPolicy(.regular)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 350, height: 390), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Normal Switcher"
            window.contentViewController = NSHostingController(rootView: SwitcherView(model: model))
            window.center()
            window.makeKeyAndOrderFront(nil)
            designWindow = window
            NSApp.activate()
        } else if ProcessInfo.processInfo.arguments.contains("--show") { showPopover() }
    }

    func applicationWillTerminate(_ notification: Notification) { model?.stop() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showPopover(); return false }

    @objc private func togglePopover() {
        if popover.isShown { popover.performClose(nil) } else { showPopover() }
    }

    private func showPopover() {
        guard let button = item?.button else { return }
        model?.refresh()
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func updateStatus() {
        guard let model else { return }
        let selected = model.layouts.first { $0.id == model.selectedID }
        item?.button?.image = nil
        item?.button?.title = ""
        languageBadge.language = selected?.shortName ?? "—"
        let width = languageBadge.preferredWidth
        item?.length = width + 8
        let height = item?.button?.bounds.height ?? 24
        languageBadge.frame = NSRect(x: 4, y: (height - 18) / 2, width: width, height: 18)
        item?.button?.toolTip = selected?.name
        item?.button?.setAccessibilityLabel(selected?.name ?? "Keyboard language")
    }
}
