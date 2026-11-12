import Foundation

@MainActor
final class SystemFnAction {
    private let access: any FnSettingsAccess
    private let defaults: UserDefaults
    private let recoveryKey = "originalFnSettings.v1"
    private let takeover = FnSettingsSnapshot(storedAction: 0, effectiveAction: 0)
    private var original: FnSettingsSnapshot?
    private var active = false
    private var rollbackRequired = false

    init(access: any FnSettingsAccess, defaults: UserDefaults = .standard) {
        self.access = access
        self.defaults = defaults
    }

    func recover() throws {
        guard defaults.object(forKey: recoveryKey) != nil else { return }
        guard let data = defaults.data(forKey: recoveryKey),
              let saved = try? JSONDecoder().decode(FnSettingsSnapshot.self, from: data), saved.isValid else {
            throw FnControlError.recoveryFailed
        }
        original = saved
        try restore()
    }

    func takeOver() throws {
        guard original == nil else {
            guard active, try access.read() == takeover else { throw FnControlError.recoveryFailed }
            return
        }
        // Never overwrite an unresolved recovery record.
        guard defaults.object(forKey: recoveryKey) == nil else { throw FnControlError.recoveryFailed }
        let saved = try access.read()
        guard saved.isValid else { throw FnControlError.readFailed }
        let encoded = try JSONEncoder().encode(saved)
        defaults.set(encoded, forKey: recoveryKey)
        guard defaults.synchronize(), defaults.data(forKey: recoveryKey) == encoded else {
            throw FnControlError.recoveryFailed
        }
        original = saved
        rollbackRequired = true
        do {
            try access.apply(takeover)
            guard try access.read() == takeover else { throw FnControlError.writeFailed }
            rollbackRequired = false
            active = true
        } catch {
            // A failed write may already have changed part of the state. Roll it back now.
            try restore(force: true)
            throw error
        }
    }

    func restore() throws { try restore(force: rollbackRequired) }

    private func restore(force: Bool) throws {
        guard let original else { return }
        active = false
        let current = try access.read()
        // A different current action belongs to the user, not to this app.
        if force || current == takeover {
            try access.apply(original)
            guard try access.read() == original else { throw FnControlError.recoveryFailed }
        }
        // Keep the snapshot until restoration (or a manual override) has been verified.
        defaults.removeObject(forKey: recoveryKey)
        guard defaults.synchronize() else {
            defaults.set(try JSONEncoder().encode(original), forKey: recoveryKey)
            throw FnControlError.recoveryFailed
        }
        self.original = nil
        active = false
        rollbackRequired = false
    }
}
