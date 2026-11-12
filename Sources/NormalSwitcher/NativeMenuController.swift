import AppKit
import Combine

@MainActor
final class NativeMenuController: NSObject, NSMenuDelegate {
    let menu = NSMenu()
    private let model: SwitcherModel
    private let openApplication: () -> Void
    private let noticeWindow: () -> NSWindow?
    private let statusItem = NSMenuItem(title: "Status: Off", action: nil, keyEquivalent: "")
    private var observation: AnyCancellable?

    init(model: SwitcherModel, openApplication: @escaping () -> Void, noticeWindow: @escaping () -> NSWindow? = { nil }) {
        self.model = model
        self.openApplication = openApplication
        self.noticeWindow = noticeWindow
        super.init()
        menu.autoenablesItems = false
        menu.showsStateColumn = false
        menu.delegate = self
        configure(statusItem, action: #selector(showApplication))
        menu.addItem(statusItem)
        let quit = NSMenuItem(title: "Quit Normal Switcher", action: #selector(quitApp), keyEquivalent: "q")
        configure(quit, action: #selector(quitApp))
        menu.addItem(quit)
        observation = model.objectWillChange.sink { [weak self] in
            Task { @MainActor [weak self] in
                await Task.yield()
                self?.refreshStates()
                self?.presentNoticeIfNeeded()
            }
        }
        refreshStates()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        model.refresh()
        refreshStates()
    }

    func menuWillOpen(_ menu: NSMenu) {
        model.verifyPendingAccess()
        refreshStates()
    }

    func refreshStates() {
        statusItem.title = model.fnEnabled ? "Status: On" : "Status: Off"
    }

    private func configure(_ item: NSMenuItem, action: Selector) {
        item.target = self
        item.action = action
    }

    private func presentNoticeIfNeeded() {
        guard let notice = model.notice else { return }
        model.notice = nil
        let isAccessibility = model.noticeIsAccessibility
        model.noticeIsAccessibility = false
        menu.cancelTracking()
        let alert = NSAlert()
        alert.messageText = isAccessibility ? "Keyboard access" : "Normal Switcher"
        alert.informativeText = notice
        alert.addButton(withTitle: isAccessibility ? "Open System Settings…" : "OK")
        if isAccessibility { alert.addButton(withTitle: "Later") }
        NSApp.activate(ignoringOtherApps: true)
        if let window = noticeWindow(), window.isVisible {
            alert.beginSheetModal(for: window) { [weak self] response in
                if isAccessibility, response == .alertFirstButtonReturn { self?.model.openAccessibilitySettings() }
            }
        } else if alert.runModal() == .alertFirstButtonReturn, isAccessibility {
            model.openAccessibilitySettings()
        }
    }

    @objc private func showApplication() {
        menu.cancelTracking()
        openApplication()
    }

    @objc private func quitApp() { model.quit() }
}
