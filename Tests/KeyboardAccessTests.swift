import AppKit

@MainActor
private final class DeniedKeyboardAccess {
    var checks = 0
    var prompts = 0

    func isTrusted() -> Bool {
        checks += 1
        return false
    }

    func prompt() { prompts += 1 }
}

@MainActor
private final class LatentKeyboardAccess {
    var granted = false
    var checks = 0
    var prompts = 0

    func isTrusted() -> Bool {
        checks += 1
        return granted
    }

    func prompt() { prompts += 1 }
}

@MainActor
private final class MemoryFnSettings: FnSettingsAccess {
    var current = FnSettingsSnapshot(storedAction: nil, effectiveAction: 2)
    func read() -> FnSettingsSnapshot { current }
    var failTakeover = false
    func apply(_ snapshot: FnSettingsSnapshot) throws {
        if failTakeover && snapshot.effectiveAction == 0 { throw FnControlError.writeFailed }
        current = snapshot
    }
}

@MainActor
private final class TestFnListener: FnListening {
    var available = true
    var running = false
    func start() -> Bool { running = available; return available }
    func stop() { running = false }
}

@main
@MainActor
struct KeyboardAccessTests {
    static func main() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        for storedEnabled in [false, true] {
            try await startupDoesNotPrompt(storedEnabled: storedEnabled)
        }
        try await deniedToggleCanRetryAndCancel()
        try await deniedEnableSurfacesGuidance()
        try await grantAfterRequestEnablesWithoutReprompt()
        try await monitorFailureAndRevocation()
        try startupDoesNotCelebrate()
        print("PASS: keyboard access startup without prompts, denied enable, explicit retry, guidance after grace, later grant enables without re-prompt, disable/stop cancel polling; isolated preferences, fake settings, fake event monitors and simulated AX")
    }

    private static func startupDoesNotPrompt(storedEnabled: Bool) async throws {
        let domain = "NormalSwitcher.KeyboardAccessTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: domain) else { fatalError("Test preferences unavailable") }
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(storedEnabled, forKey: "fnEnabled")
        let access = DeniedKeyboardAccess()
        let model = SwitcherModel(
            defaults: defaults,
            systemAction: SystemFnAction(access: MemoryFnSettings(), defaults: defaults),
            listener: TestFnListener(),
            isKeyboardAccessTrusted: access.isTrusted,
            promptForKeyboardAccess: access.prompt
        )
        defer { model.stop() }
        precondition(access.prompts == 0, "Constructing the model must not prompt")
        model.start()
        precondition(!model.fnEnabled, "Stored intent must not enable Fn before AX access")
        precondition(model.needsKeyboardAccess == storedEnabled)
        precondition(access.prompts == 0, "Startup must not prompt, even with stored Fn enabled")
        precondition(defaults.bool(forKey: "fnEnabled") == storedEnabled, "Startup preserves stored intent")
        let initialChecks = access.checks
        try await Task.sleep(for: .milliseconds(1200))
        precondition(access.prompts == 0, "Waiting for access must not prompt")
        precondition(storedEnabled ? access.checks > initialChecks : access.checks == initialChecks,
                     "Only stored enable intent should start permission polling")
        assertDenied(model, defaults: defaults)

        model.stop()
        precondition(!model.needsKeyboardAccess, "Stop must clear pending permission state")
        let checksAtStop = access.checks
        try await Task.sleep(for: .milliseconds(1200))
        precondition(access.checks == checksAtStop, "Stop must cancel permission polling")
        precondition(defaults.bool(forKey: "fnEnabled") == storedEnabled, "Quit preserves the next-launch preference")
        assertDenied(model, defaults: defaults)
    }

    private static func deniedToggleCanRetryAndCancel() async throws {
        let domain = "NormalSwitcher.KeyboardAccessTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: domain) else { fatalError("Test preferences unavailable") }
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(false, forKey: "fnEnabled")
        let access = DeniedKeyboardAccess()
        let model = SwitcherModel(
            defaults: defaults,
            systemAction: SystemFnAction(access: MemoryFnSettings(), defaults: defaults),
            listener: TestFnListener(),
            isKeyboardAccessTrusted: access.isTrusted,
            promptForKeyboardAccess: access.prompt
        )
        defer { model.stop() }
        model.start()
        model.fnEnabled = true
        precondition(access.prompts == 1, "An explicit denied enable must prompt exactly once")
        precondition(model.needsKeyboardAccess)
        precondition(!defaults.bool(forKey: "fnEnabled"), "Denied enable must not persist enabled")
        assertDenied(model, defaults: defaults)

        let checksBeforePoll = access.checks
        try await Task.sleep(for: .milliseconds(1200))
        precondition(access.checks > checksBeforePoll, "Denied enable must wait for permission")
        precondition(access.prompts == 1, "Permission polling must not repeat the prompt")
        assertDenied(model, defaults: defaults)
        model.fnEnabled = true
        precondition(access.prompts == 2, "A repeated explicit attempt must prompt again")
        precondition(model.needsKeyboardAccess)
        assertDenied(model, defaults: defaults)

        // The displayed switch is already off after denial; assigning off must still cancel the wait.
        model.fnEnabled = false
        precondition(!model.needsKeyboardAccess, "Disable must clear pending permission state")
        precondition(!defaults.bool(forKey: "fnEnabled"))
        let checksAtDisable = access.checks
        try await Task.sleep(for: .milliseconds(1200))
        precondition(access.checks == checksAtDisable, "Disable must cancel all permission polling")
        precondition(access.prompts == 2)
        assertDenied(model, defaults: defaults)

        model.fnEnabled = true
        precondition(access.prompts == 3, "Enable after cancellation must start a fresh request")
        precondition(model.needsKeyboardAccess)
        model.stop()
        model.stop()
        precondition(!model.needsKeyboardAccess, "Repeated stop must leave no pending permission state")
        let checksAtStop = access.checks
        try await Task.sleep(for: .milliseconds(1200))
        precondition(access.checks == checksAtStop, "Stop must cancel a user-initiated permission wait")
        precondition(access.prompts == 3)
        precondition(!defaults.bool(forKey: "fnEnabled"))
        assertDenied(model, defaults: defaults)
    }

    private static func deniedEnableSurfacesGuidance() async throws {
        let domain = "NormalSwitcher.KeyboardAccessTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: domain) else { fatalError("Test preferences unavailable") }
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(false, forKey: "fnEnabled")
        let access = DeniedKeyboardAccess()
        let model = SwitcherModel(
            defaults: defaults,
            systemAction: SystemFnAction(access: MemoryFnSettings(), defaults: defaults),
            listener: TestFnListener(),
            isKeyboardAccessTrusted: access.isTrusted,
            promptForKeyboardAccess: access.prompt
        )
        defer { model.stop() }
        model.start()
        model.fnEnabled = true
        precondition(model.notice == nil, "Guidance must wait for a grace period")
        try await Task.sleep(for: .milliseconds(3600))
        precondition(model.notice != nil, "Denied enable must surface guidance after the grace period")
        precondition(model.noticeIsAccessibility, "Guidance must be flagged as an accessibility notice")
        model.notice = nil
        model.noticeIsAccessibility = false
        model.fnEnabled = false
        let checksAtCancel = access.checks
        try await Task.sleep(for: .milliseconds(1200))
        precondition(access.checks == checksAtCancel, "Cancel must stop the permission poll")
        precondition(model.notice == nil, "Cancelling must not surface further guidance")
    }

    private static func grantAfterRequestEnablesWithoutReprompt() async throws {
        let domain = "NormalSwitcher.KeyboardAccessTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: domain) else { fatalError("Test preferences unavailable") }
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(false, forKey: "fnEnabled")
        let access = LatentKeyboardAccess()
        let model = SwitcherModel(
            defaults: defaults,
            systemAction: SystemFnAction(access: MemoryFnSettings(), defaults: defaults),
            listener: TestFnListener(),
            isKeyboardAccessTrusted: access.isTrusted,
            promptForKeyboardAccess: access.prompt
        )
        defer { model.stop() }
        let feedback = ActivationFeedback(model: model)
        model.start()
        feedback.toggle()
        precondition(feedback.burst == 0 && model.activationSequence == 0, "Permission request must not celebrate")
        precondition(access.prompts == 1, "Enable without trust must prompt exactly once")
        precondition(model.needsKeyboardAccess)
        precondition(!model.fnEnabled, "Fn must stay off until trust exists")
        access.granted = true
        try await Task.sleep(for: .milliseconds(1500))
        precondition(model.fnEnabled, "A later grant must flip Fn on via the poll")
        precondition(access.prompts == 1, "The grant must not re-prompt")
        precondition(!model.needsKeyboardAccess, "Grant must clear the pending state")
        precondition(defaults.bool(forKey: "fnEnabled"), "Grant must persist the enabled preference")
        precondition(defaults.data(forKey: "originalFnSettings.v1") != nil,
                     "System Fn ownership must be acquired only after trust exists")
        precondition(access.checks > 0, "The poll must actually poll")
        precondition(feedback.burst == 1 && model.activationSequence == 1, "Only successful activation should celebrate once")
        feedback.toggle()
        precondition(!model.fnEnabled && feedback.burst == 1, "Deactivation must not trigger confetti")
    }

    private static func monitorFailureAndRevocation() async throws {
        let domain = "NormalSwitcher.KeyboardAccessTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let access = LatentKeyboardAccess()
        access.granted = true
        let settings = MemoryFnSettings()
        let original = settings.current
        let listener = TestFnListener()
        listener.available = false
        let model = SwitcherModel(defaults: defaults,
            systemAction: SystemFnAction(access: settings, defaults: defaults), listener: listener,
            isKeyboardAccessTrusted: access.isTrusted, promptForKeyboardAccess: access.prompt)
        defer { model.stop() }
        let feedback = ActivationFeedback(model: model)
        model.start()
        feedback.toggle()
        precondition(!model.fnEnabled && !listener.running)
        precondition(settings.current == original, "Failed event monitor must not change system Fn")
        precondition(defaults.data(forKey: "originalFnSettings.v1") == nil)
        listener.available = true
        settings.failTakeover = true
        feedback.toggle()
        precondition(!model.fnEnabled && !listener.running, "A failed system write must stop the monitor")
        precondition(settings.current == original)
        precondition(defaults.data(forKey: "originalFnSettings.v1") == nil)
        precondition(feedback.burst == 0 && model.activationSequence == 0, "Failed activation must not celebrate")
        settings.failTakeover = false
        for _ in 0..<3 {
            model.fnEnabled = true
            precondition(model.fnEnabled && listener.running)
            model.fnEnabled = false
            precondition(settings.current == original && !listener.running)
        }
        model.fnEnabled = true
        precondition(model.fnEnabled && listener.running)
        access.granted = false
        try await Task.sleep(for: .milliseconds(1400))
        precondition(!model.fnEnabled && !listener.running, "Revocation must stop interception")
        precondition(settings.current == original, "Revocation must restore the original action")
        precondition(!defaults.bool(forKey: "fnEnabled"))
        access.granted = true
        model.fnEnabled = true
        model.stop()
        precondition(settings.current == original && !listener.running, "Quit must restore Fn")
        precondition(defaults.bool(forKey: "fnEnabled"), "Quit preserves the user's enable intent")
        print("PASS: unavailable monitor leaves system unchanged; revoked permission restores Fn")
    }

    private static func startupDoesNotCelebrate() throws {
        let domain = "NormalSwitcher.KeyboardAccessTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(true, forKey: "fnEnabled")
        let access = LatentKeyboardAccess()
        access.granted = true
        let model = SwitcherModel(defaults: defaults,
            systemAction: SystemFnAction(access: MemoryFnSettings(), defaults: defaults), listener: TestFnListener(),
            isKeyboardAccessTrusted: access.isTrusted, promptForKeyboardAccess: access.prompt)
        let feedback = ActivationFeedback(model: model)
        defer { model.stop() }
        model.start()
        precondition(model.fnEnabled && feedback.burst == 0, "Restoring active mode at launch must not celebrate")
        feedback.toggle()
        precondition(!model.fnEnabled && feedback.burst == 0)
        access.granted = false
        feedback.toggle()
        precondition(model.needsKeyboardAccess && feedback.burst == 0)
        feedback.toggle()
        access.granted = true
        model.verifyPendingAccess()
        precondition(!model.fnEnabled && feedback.burst == 0, "Cancelled requests must not celebrate or enable")
        feedback.toggle()
        precondition(model.fnEnabled && feedback.burst == 1, "A fresh successful user activation celebrates")
        print("PASS: confetti only after successful user activation, not on launch, denied/cancelled attempts, failed writes or deactivation")
    }

    private static func assertDenied(_ model: SwitcherModel, defaults: UserDefaults) {
        precondition(!model.fnEnabled, "Fn must stay off while AX access is denied")
        precondition(defaults.object(forKey: "originalFnSettings.v1") == nil,
                     "Denied access must not acquire system Fn ownership")
    }
}
