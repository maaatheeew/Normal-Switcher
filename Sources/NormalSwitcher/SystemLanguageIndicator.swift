import Foundation

@MainActor
final class SystemLanguageIndicator {
    private let access: any IndicatorSettingsAccess
    private let defaults: UserDefaults
    private let recoveryKey = "originalLanguageIndicator.v1"
    private let hidden = IndicatorPreference.integer(0)
    private var original: IndicatorPreference?
    private var rollbackRequired = false
    private var isActive = false

    init(access: any IndicatorSettingsAccess = GlobalIndicatorSettings(), defaults: UserDefaults = .standard) {
        self.access = access
        self.defaults = defaults
    }

    func recover() throws {
        guard original == nil else { throw failure("Indicator recovery is already in progress.") }
        guard defaults.object(forKey: recoveryKey) != nil else { return }
        guard let data = defaults.data(forKey: recoveryKey),
              let saved = try? JSONDecoder().decode(IndicatorPreference.self, from: data) else {
            throw failure("The saved indicator preference could not be read.")
        }
        original = saved
        try restore()
    }

    func start() throws {
        guard original == nil else {
            guard isActive, try access.read() == hidden else { throw failure("Indicator recovery is still pending.") }
            return
        }
        let current = try access.read()
        if defaults.object(forKey: recoveryKey) != nil {
            guard let data = defaults.data(forKey: recoveryKey),
                  let saved = try? JSONDecoder().decode(IndicatorPreference.self, from: data) else {
                throw failure("The saved indicator preference could not be read.")
            }
            if current == hidden {
                // Continue ownership after a crash without replacing the original snapshot with 0.
                original = saved
                try access.reloadAgent()
                isActive = true
                return
            }
            // A manual change after the old run is the new baseline.
            try clearRecovery()
        }
        guard !current.isHidden else { return }
        let encoded = try JSONEncoder().encode(current)
        defaults.set(encoded, forKey: recoveryKey)
        guard defaults.synchronize(), defaults.data(forKey: recoveryKey) == encoded else {
            throw failure("Could not save the original indicator preference.")
        }
        original = current
        rollbackRequired = true
        do {
            try access.apply(hidden)
            guard try access.read() == hidden else { throw failure("The indicator preference did not change.") }
            try access.reloadAgent()
            rollbackRequired = false
            isActive = true
        } catch {
            try restore()
            throw error
        }
    }

    func restore() throws {
        guard let original else { return }
        isActive = false
        let current = try access.read()
        if rollbackRequired || current == hidden {
            try access.apply(original)
            guard try access.read() == original else { throw failure("Could not restore the original indicator preference.") }
            try access.reloadAgent()
        } else if current == original {
            // Retry an agent refresh that failed after a successful preference restore.
            try access.reloadAgent()
        }
        try clearRecovery()
        self.original = nil
        rollbackRequired = false
    }

    private func clearRecovery() throws {
        let saved = defaults.object(forKey: recoveryKey)
        defaults.removeObject(forKey: recoveryKey)
        guard defaults.synchronize() else {
            if let saved { defaults.set(saved, forKey: recoveryKey) }
            throw failure("Could not finish indicator preference recovery.")
        }
    }

    private func failure(_ message: String) -> NSError {
        NSError(domain: "NormalSwitcher.SystemIndicator", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
