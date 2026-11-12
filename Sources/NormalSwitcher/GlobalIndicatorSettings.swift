import Foundation

@MainActor
final class GlobalIndicatorSettings: IndicatorSettingsAccess {
    private let key = "TSMLanguageIndicatorEnabled" as CFString

    func read() throws -> IndicatorPreference {
        guard CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else {
            throw failure("Could not read the system input-source indicator preference.")
        }
        guard let raw = CFPreferencesCopyValue(key, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else {
            return .absent
        }
        guard let number = raw as? NSNumber else { throw failure("Unsupported indicator preference type.") }
        if CFGetTypeID(raw) == CFBooleanGetTypeID() { return .boolean(number.boolValue) }
        guard !["f", "d"].contains(String(cString: number.objCType)) else {
            throw failure("Unsupported non-integer indicator preference.")
        }
        return .integer(number.intValue)
    }

    func apply(_ value: IndicatorPreference) throws {
        let stored: NSNumber?
        switch value {
        case .absent: stored = nil
        case .boolean(let enabled): stored = NSNumber(value: enabled)
        case .integer(let enabled): stored = NSNumber(value: enabled)
        }
        CFPreferencesSetValue(key, stored, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        guard CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost),
              try read() == value else {
            throw failure("Could not verify the system input-source indicator preference.")
        }
    }

    func reloadAgent() throws {
        // FnLangSwitch uses this agent restart to apply the global indicator setting.
        // Restrict it to the signed-in user's agent; status 1 also covers an absent agent.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["-u", NSUserName(), "TextInputMenuAgent"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard [0, 1].contains(process.terminationStatus) else { throw failure("Could not refresh the input-source indicator agent.") }
    }

    private func failure(_ message: String) -> NSError {
        NSError(domain: "NormalSwitcher.SystemIndicator", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
