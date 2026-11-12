import AppKit
import Combine
import os
import ServiceManagement

@MainActor
final class SwitcherModel: ObservableObject {
    @Published var layouts: [KeyboardLayout] = []
    @Published var selectedID = ""
    @Published var fnEnabled = false { didSet { fnToggleChanged() } }
    @Published private(set) var activationSequence = 0
    @Published var needsKeyboardAccess = false
    @Published var launchAtLogin = false
    @Published var notice: String?
    @Published var noticeIsAccessibility = false
    var statusChanged: (() -> Void)?
    private let catalog = LayoutCatalog()
    private let loginItems = LoginItemManager()
    private let systemIndicator: SystemLanguageIndicator
    private let systemAction: SystemFnAction
    private let defaults: UserDefaults
    private let isKeyboardAccessTrusted: () -> Bool
    private let promptForKeyboardAccess: () -> Void
    private let listener: any FnListening
    private var isRunning = false
    private var changingState = false
    private var pendingEnable = false
    private var permissionWait: Task<Void, Never>?
    private var activeAccessWatch: Task<Void, Never>?
    private var accessAlertTask: Task<Void, Never>?
    private var accessAlertShown = false
    private let log = Logger(subsystem: "com.maaatheeew.NormalSwitcher", category: "permission")

    init(
        defaults: UserDefaults = .standard,
        systemAction: SystemFnAction? = nil,
        systemIndicator: SystemLanguageIndicator? = nil,
        listener: (any FnListening)? = nil,
        isKeyboardAccessTrusted: @escaping () -> Bool = { AXIsProcessTrusted() },
        promptForKeyboardAccess: @escaping () -> Void = {
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
    ) {
        self.defaults = defaults
        self.isKeyboardAccessTrusted = isKeyboardAccessTrusted
        self.promptForKeyboardAccess = promptForKeyboardAccess
        self.listener = listener ?? FnListener(catalog: catalog)
        self.systemIndicator = systemIndicator ?? SystemLanguageIndicator(defaults: defaults)
        self.systemAction = systemAction ?? SystemFnAction(access: HIToolboxSettings(), defaults: defaults)
        launchAtLogin = loginItems.isEnabled
        catalog.changed = { [weak self] in self?.refresh() }
        refresh()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        var recoveryFailed = false
        do { try systemIndicator.recover() }
        catch { reportIndicatorFailure(error); recoveryFailed = true }
        do { try systemAction.recover() }
        catch { reportFnFailure(); recoveryFailed = true }
        guard !recoveryFailed else { return }
        if defaults.bool(forKey: "fnEnabled") {
            log.debug("stored Fn enabled; accessibility trust=\(self.isKeyboardAccessTrusted())")
            if isKeyboardAccessTrusted() { enable() }
            else { needsKeyboardAccess = true; pendingEnable = true; waitForPermission() }
        }
    }

    func stop() {
        activeAccessWatch?.cancel()
        activeAccessWatch = nil
        accessAlertTask?.cancel()
        notice = nil
        noticeIsAccessibility = false
        pendingEnable = false
        permissionWait?.cancel()
        permissionWait = nil
        needsKeyboardAccess = false
        listener.stop()
        restoreSystemAction()
        restoreSystemIndicator()
        displayEnabled(false)
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
                noticeIsAccessibility = false
                notice = "Allow Normal Switcher in Login Items to launch automatically."
                SMAppService.openSystemSettingsLoginItems()
            }
            launchAtLogin = loginItems.isEnabled
        } catch {
            launchAtLogin = loginItems.isEnabled
            noticeIsAccessibility = false
            notice = "Could not update Login Items. Try again in System Settings."
        }
    }

    func requestKeyboardAccess() {
        accessAlertShown = false
        pendingEnable = true
        log.debug("requesting Accessibility access; trust=\(self.isKeyboardAccessTrusted())")
        if isKeyboardAccessTrusted() { enable(); return }
        needsKeyboardAccess = true
        promptForKeyboardAccess()
        waitForPermission()
        scheduleAccessDeniedAlert()
    }

    /// Re-checks a pending grant when the menu opens, in case the poll was interrupted.
    func verifyPendingAccess() {
        guard pendingEnable else { return }
        if isKeyboardAccessTrusted() {
            enable()
        } else {
            log.debug("menu open; accessibility still denied (trust=\(self.isKeyboardAccessTrusted()))")
            waitForPermission()
        }
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func fnToggleChanged() {
        guard isRunning, !changingState else { return }
        if fnEnabled {
            if isKeyboardAccessTrusted() { enable() }
            else {
                log.debug("Fn enable denied by accessibility; keeping Fn off")
                displayEnabled(false)
                requestKeyboardAccess()
            }
        } else {
            activeAccessWatch?.cancel()
            activeAccessWatch = nil
            accessAlertTask?.cancel()
            notice = nil
            noticeIsAccessibility = false
            pendingEnable = false
            permissionWait?.cancel()
            permissionWait = nil
            needsKeyboardAccess = false
            listener.stop()
            restoreSystemAction()
            restoreSystemIndicator()
            defaults.set(false, forKey: "fnEnabled")
            statusChanged?()
        }
    }

    private func enable() {
        guard isRunning, isKeyboardAccessTrusted() else { return }
        accessAlertTask?.cancel()
        pendingEnable = false
        permissionWait?.cancel()
        permissionWait = nil
        needsKeyboardAccess = false
        log.debug("accessibility granted; enabling Fn interception")
        // Permission comes first. Never disable the system action before access exists.
        guard listener.start() else {
            listener.stop()
            reportFnFailure()
            return
        }
        do { try systemAction.takeOver() }
        catch {
            listener.stop()
            restoreSystemIndicator()
            reportFnFailure()
            return
        }
        do { try systemIndicator.start() }
        catch {
            listener.stop()
            restoreSystemAction()
            restoreSystemIndicator()
            reportIndicatorFailure(error)
            return
        }
        notice = nil
        noticeIsAccessibility = false
        defaults.set(true, forKey: "fnEnabled")
        displayEnabled(true)
        activationSequence += 1
        watchActiveAccess()
        statusChanged?()
    }

    private func watchActiveAccess() {
        activeAccessWatch?.cancel()
        activeAccessWatch = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                guard let self, self.isRunning, self.fnEnabled else { return }
                if !self.isKeyboardAccessTrusted() {
                    self.fnEnabled = false
                    if self.notice == nil {
                        self.noticeIsAccessibility = false
                        self.notice = "Accessibility access was lost. Fn has been turned off. Enable Fn again to request access."
                    }
                    return
                }
            }
        }
    }

    private func restoreSystemAction() {
        do { try systemAction.restore() }
        catch { reportFnFailure() }
    }

    private func restoreSystemIndicator() {
        do { try systemIndicator.restore() }
        catch { reportIndicatorFailure(error) }
    }

    private func reportIndicatorFailure(_ error: Error) {
        displayEnabled(false)
        noticeIsAccessibility = false
        notice = "Could not update the system input-source indicator. Fn is off. " + error.localizedDescription
        log.error("System indicator operation failed; recovery retained when needed: \(error.localizedDescription, privacy: .public)")
        statusChanged?()
    }

    private func reportFnFailure() {
        displayEnabled(false)
        noticeIsAccessibility = false
        notice = "Fn control could not be started or its previous settings could not be restored. Fn is off. If switching does not work, check Keyboard settings in System Settings. The saved recovery record is kept when restoration fails."
        log.error("Fn settings or event monitor operation failed; Fn disabled")
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
                if self.isKeyboardAccessTrusted() { self.enable(); return }
            }
        }
    }

    private func scheduleAccessDeniedAlert() {
        accessAlertTask?.cancel()
        accessAlertTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            guard let self, self.pendingEnable, !self.isKeyboardAccessTrusted(), !self.accessAlertShown else { return }
            self.accessAlertShown = true
            self.noticeIsAccessibility = true
            self.notice = "Normal Switcher needs Accessibility permission to control Fn. Open System Settings → Privacy & Security → Accessibility and turn on Normal Switcher. If it is already on, quit and reopen Normal Switcher."
            self.log.debug("accessibility still denied; surfaced guidance")
        }
    }

    func openSource() {
        if let url = URL(string: "https://github.com/maaatheeew/Normal-Switcher") { NSWorkspace.shared.open(url) }
    }

    func quit() { NSApp.terminate(nil) }
}
