import Foundation
import Darwin

@MainActor
final class HIToolboxSettings: FnSettingsAccess {
    private let domain = "com.apple.HIToolbox" as CFString
    private let actionKey = "AppleFnUsageType" as CFString
    private let indicatorKey = "TSMLanguageIndicatorEnabled" as CFString

    func read() -> FnSettingsSnapshot {
        let action = value(actionKey, domain: domain)
        var effective = action ?? 2
        withLibrary { handle in
            if let address = dlsym(handle, "TISGetFnUsageType") {
                effective = Int(unsafeBitCast(address, to: (@convention(c) () -> Int32).self)())
            }
        }
        return FnSettingsSnapshot(storedAction: action, effectiveAction: effective, languageIndicator: value(indicatorKey, domain: kCFPreferencesAnyApplication))
    }

    func apply(_ snapshot: FnSettingsSnapshot) {
        let previousIndicator = value(indicatorKey, domain: kCFPreferencesAnyApplication)
        write(actionKey, domain: domain, value: snapshot.storedAction)
        withLibrary { handle in
            if let address = dlsym(handle, "TISUpdateFnUsageType") {
                unsafeBitCast(address, to: (@convention(c) (Int32) -> Void).self)(Int32(snapshot.effectiveAction))
            }
        }
        write(indicatorKey, domain: kCFPreferencesAnyApplication, value: snapshot.languageIndicator)
        if previousIndicator != snapshot.languageIndicator {
            // This system helper caches the indicator setting; it restarts on demand.
            let helper = Process()
            helper.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            helper.arguments = ["TextInputMenuAgent"]
            helper.standardOutput = FileHandle.nullDevice
            helper.standardError = FileHandle.nullDevice
            try? helper.run()
        }
    }

    private func value(_ key: CFString, domain: CFString) -> Int? {
        (CFPreferencesCopyValue(key, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? NSNumber)?.intValue
    }

    private func write(_ key: CFString, domain: CFString, value: Int?) {
        CFPreferencesSetValue(key, value.map(NSNumber.init(value:)), domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }

    private func withLibrary(_ body: (UnsafeMutableRawPointer) -> Void) {
        // Optional private cache API, resolved dynamically to survive OS changes.
        guard let handle = dlopen("/System/Library/Frameworks/Carbon.framework/Frameworks/HIToolbox.framework/HIToolbox", RTLD_LAZY) else { return }
        defer { dlclose(handle) }
        body(handle)
    }
}
