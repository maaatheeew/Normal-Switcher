import Foundation
import Darwin

@MainActor
final class HIToolboxSettings: FnSettingsAccess {
    private let domain = "com.apple.HIToolbox" as CFString
    private let actionKey = "AppleFnUsageType" as CFString

    func read() throws -> FnSettingsSnapshot {
        try withLibrary { handle in
            guard let address = dlsym(handle, "TISGetFnUsageType"),
                  dlsym(handle, "TISUpdateFnUsageType") != nil else { throw FnControlError.unavailable }
            guard CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else {
                throw FnControlError.readFailed
            }
            let raw = CFPreferencesCopyValue(actionKey, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            if let raw, !(raw is NSNumber) { throw FnControlError.readFailed }
            let action = (raw as? NSNumber)?.intValue
            let effective = Int(unsafeBitCast(address, to: (@convention(c) () -> Int32).self)())
            guard (0...3).contains(effective), (action.map { (0...3).contains($0) } ?? true) else {
                throw FnControlError.readFailed
            }
            return FnSettingsSnapshot(storedAction: action, effectiveAction: effective)
        }
    }

    func apply(_ snapshot: FnSettingsSnapshot) throws {
        guard snapshot.isValid else { throw FnControlError.writeFailed }
        try withLibrary { handle in
            guard let address = dlsym(handle, "TISUpdateFnUsageType"),
                  dlsym(handle, "TISGetFnUsageType") != nil else { throw FnControlError.unavailable }
            CFPreferencesSetValue(actionKey, snapshot.storedAction.map(NSNumber.init(value:)), domain,
                                  kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            guard CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else {
                throw FnControlError.writeFailed
            }
            unsafeBitCast(address, to: (@convention(c) (Int32) -> Void).self)(Int32(snapshot.effectiveAction))
        }
        guard try read() == snapshot else { throw FnControlError.writeFailed }
    }

    private func withLibrary<T>(_ body: (UnsafeMutableRawPointer) throws -> T) throws -> T {
        guard let handle = dlopen("/System/Library/Frameworks/Carbon.framework/Frameworks/HIToolbox.framework/HIToolbox", RTLD_LAZY) else {
            throw FnControlError.unavailable
        }
        defer { dlclose(handle) }
        return try body(handle)
    }
}
