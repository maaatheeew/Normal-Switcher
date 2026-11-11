import Foundation
import Darwin

@MainActor
final class HIToolboxSettings: FnSettingsAccess {
    private let domain = "com.apple.HIToolbox" as CFString
    private let actionKey = "AppleFnUsageType" as CFString

    func read() -> FnSettingsSnapshot {
        let action = value(actionKey, domain: domain)
        var effective = action ?? 2
        withLibrary { handle in
            if let address = dlsym(handle, "TISGetFnUsageType") {
                effective = Int(unsafeBitCast(address, to: (@convention(c) () -> Int32).self)())
            }
        }
        return FnSettingsSnapshot(storedAction: action, effectiveAction: effective)
    }

    func apply(_ snapshot: FnSettingsSnapshot) {
        write(actionKey, domain: domain, value: snapshot.storedAction)
        withLibrary { handle in
            if let address = dlsym(handle, "TISUpdateFnUsageType") {
                unsafeBitCast(address, to: (@convention(c) (Int32) -> Void).self)(Int32(snapshot.effectiveAction))
            }
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
