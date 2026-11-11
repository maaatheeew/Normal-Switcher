import AppKit
import Combine
import ServiceManagement

@MainActor
final class SwitcherModel: ObservableObject {
    @Published var layouts: [KeyboardLayout] = []
    @Published var selectedID = ""
    @Published var fnEnabled = false { didSet { fnToggleChanged() } }
    @Published var needsKeyboardAccess = false
    @Published var launchAtLogin = false
    @Published var notice: String?
    var statusChanged: (() -> Void)?
    private let catalog = LayoutCatalog()
    private let loginItems = LoginItemManager()
    private let systemAction = SystemFnAction(access: HIToolboxSettings())
    private var listener: FnListener?
    private var isRunning = false
    private var changingState = false
    private var pendingEnable = false
    private var permissionWait: Task<Void, Never>?

    init() {
        launchAtLogin = loginItems.isEnabled
        catalog.changed = { [weak self] in self?.refresh() }
        refresh()
    }

    func start() {
        systemAction.recover()
        let listener = FnListener(catalog: catalog)
        self.listener = listener
        isRunning = true
        if UserDefaults.standard.bool(forKey: "fnEnabled") {
            if AXIsProcessTrusted() { enable() }
            else { needsKeyboardAccess = true; pendingEnable = true; waitForPermission() }
        }
    }

    func stop() {
        permissionWait?.cancel()
        listener?.stop()
        systemAction.restore()
        isRunning = false
    }

    func refresh() {
        launchAtLogin = loginItems.isEnabled
        layouts = catalog.layouts()
        selectedID = catalog.selectedID() ?? ""
        statusChanged?()
    }

    func select(_ layout: KeyboardLayout) {
        if !catalog.choose(layout.id) { notice = "This input source is unavailable in the current app." }
    }

    func updateLoginItem() {
        let status = loginItems.status
        if launchAtLogin == (status == .enabled || status == .requiresApproval) { return }
        do {
            let result = try loginItems.setEnabled(launchAtLogin)
            if result == .requiresApproval {
                notice = "Allow Normal Switcher in Login Items to launch automatically."
                SMAppService.openSystemSettingsLoginItems()
            }
            launchAtLogin = loginItems.isEnabled
        } catch {
            launchAtLogin = loginItems.isEnabled
            notice = "Could not update Login Items. Try again in System Settings."
        }
    }

    func requestKeyboardAccess() {
        pendingEnable = true
        if AXIsProcessTrusted() { enable(); return }
        needsKeyboardAccess = true
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        waitForPermission()
    }

    private func fnToggleChanged() {
        guard isRunning, !changingState else { return }
        if fnEnabled {
            if AXIsProcessTrusted() { enable() }
            else {
                displayEnabled(false)
                requestKeyboardAccess()
            }
        } else {
            pendingEnable = false
            permissionWait?.cancel()
            needsKeyboardAccess = false
            listener?.stop()
            systemAction.restore()
            UserDefaults.standard.set(false, forKey: "fnEnabled")
            statusChanged?()
        }
    }

    private func enable() {
        guard isRunning, AXIsProcessTrusted() else { return }
        pendingEnable = false
        permissionWait?.cancel()
        needsKeyboardAccess = false
        // Permission comes first. Never disable the system action before access exists.
        systemAction.takeOver()
        listener?.enabled = true
        listener?.start()
        UserDefaults.standard.set(true, forKey: "fnEnabled")
        displayEnabled(true)
        statusChanged?()
    }

    private func displayEnabled(_ enabled: Bool) {
        changingState = true
        fnEnabled = enabled
        changingState = false
    }

    private func waitForPermission() {
        permissionWait?.cancel()
        permissionWait = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                guard let self, self.pendingEnable else { return }
                if AXIsProcessTrusted() { self.enable(); return }
            }
        }
    }

    func openSource() {
        if let url = URL(string: "https://github.com/maaatheeew/Normal-Switcher") { NSWorkspace.shared.open(url) }
    }

    func quit() { NSApp.terminate(nil) }
}
