import Foundation

@MainActor
final class SystemFnAction {
    private let access: any FnSettingsAccess
    private let defaults: UserDefaults
    private let recoveryKey = "originalFnSettings.v1"
    private var original: FnSettingsSnapshot?

    init(access: any FnSettingsAccess, defaults: UserDefaults = .standard) {
        self.access = access
        self.defaults = defaults
    }

    /// Restore a snapshot left by an interrupted previous run before doing anything else.
    func recover() {
        guard let data = defaults.data(forKey: recoveryKey),
              let saved = try? JSONDecoder().decode(FnSettingsSnapshot.self, from: data) else { return }
        access.apply(saved)
        defaults.removeObject(forKey: recoveryKey)
    }

    func takeOver() {
        guard original == nil else { return }
        let saved = access.read()
        guard let encoded = try? JSONEncoder().encode(saved) else { return }
        defaults.set(encoded, forKey: recoveryKey)
        defaults.synchronize()
        original = saved
        access.apply(FnSettingsSnapshot(storedAction: 0, effectiveAction: 0, languageIndicator: saved.languageIndicator))
    }

    func restore() {
        guard let original else { return }
        access.apply(original)
        self.original = nil
        defaults.removeObject(forKey: recoveryKey)
        defaults.synchronize()
    }
}
