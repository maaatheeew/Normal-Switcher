import AppKit

@MainActor
final class MenuBarController: NSObject, NSApplicationDelegate {
    private var model: SwitcherModel?
    private var item: NSStatusItem?
    private var nativeMenu: NativeMenuController?
    private var applicationWindow: ApplicationWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard NSRunningApplication.runningApplications(withBundleIdentifier: "com.maaatheeew.NormalSwitcher")
            .filter({ $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }).isEmpty else {
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        configureApplicationMenu()
        let model = SwitcherModel()
        self.model = model
        let nativeMenu = NativeMenuController(model: model,
            openApplication: { [weak self] in self?.showApplication() },
            noticeWindow: { [weak self] in self?.applicationWindow?.window })
        self.nativeMenu = nativeMenu
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // NSStatusItem owns menu tracking, placement, keyboard handling and dismissal.
        item?.menu = nativeMenu.menu
        model.statusChanged = { [weak self] in self?.updateStatus() }
        updateStatus()
        model.start()
        if ProcessInfo.processInfo.arguments.contains("--show-window") { showApplication() }
    }

    func applicationWillTerminate(_ notification: Notification) { model?.stop() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showApplication()
        return true
    }

    private func configureApplicationMenu() {
        let main = NSMenu()
        let application = NSMenu(title: "Normal Switcher")
        let quit = application.addItem(withTitle: "Quit Normal Switcher", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        let applicationItem = NSMenuItem()
        applicationItem.submenu = application
        main.addItem(applicationItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        let windowItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)
        NSApp.mainMenu = main
        NSApp.windowsMenu = windowMenu
    }

    private func showApplication() {
        guard let model else { return }
        if applicationWindow == nil { applicationWindow = ApplicationWindowController(model: model) }
        applicationWindow?.showApplication()
    }

    private func updateStatus() {
        guard let model else { return }
        let selected = model.layouts.first { $0.id == model.selectedID }
        item?.button?.title = ""
        item?.button?.imagePosition = .imageOnly
        item?.button?.image = StatusLanguageIcon.image(language: selected?.shortName ?? "—", filled: selected?.isASCIICapable ?? false)
        item?.button?.toolTip = selected?.name
        item?.button?.setAccessibilityLabel(selected?.name ?? "Keyboard language")
        nativeMenu?.refreshStates()
    }
}
