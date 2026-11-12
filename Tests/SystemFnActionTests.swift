import Foundation

@MainActor
final class FakeFnSettings: FnSettingsAccess {
    var current: FnSettingsSnapshot
    var writes: [FnSettingsSnapshot] = []
    init(_ initial: FnSettingsSnapshot) { current = initial }
    func read() -> FnSettingsSnapshot { current }
    var ignoredWrites = false
    var failWrites = false
    var failNextWritePartially = false
    func apply(_ snapshot: FnSettingsSnapshot) throws {
        if failWrites { throw FnControlError.writeFailed }
        if failNextWritePartially {
            failNextWritePartially = false
            current = FnSettingsSnapshot(storedAction: snapshot.storedAction, effectiveAction: current.effectiveAction)
            throw FnControlError.writeFailed
        }
        writes.append(snapshot)
        if !ignoredWrites { current = snapshot }
    }
}

@main
@MainActor
struct SystemFnActionTests {
    static func main() throws {
        let domain = "NormalSwitcher.Tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: domain) else { fatalError("Test preferences unavailable") }
        defer { defaults.removePersistentDomain(forName: domain) }
        let takeover = FnSettingsSnapshot(storedAction: 0, effectiveAction: 0)
        for value in [0, 1, 2, 3] {
            let original = FnSettingsSnapshot(storedAction: value, effectiveAction: value)
            let access = FakeFnSettings(original)
            let controller = SystemFnAction(access: access, defaults: defaults)
            try controller.restore()
            precondition(access.writes.isEmpty, "Off must not alter a setting it never owned")
            try controller.takeOver()
            try controller.takeOver()
            precondition(access.current == takeover && access.writes.count == 1, "Take over once")
            try controller.restore()
            precondition(access.current == original, "Restore the exact original action")
            try controller.restore()
            precondition(access.writes.count == 2, "Repeated off has no side effect")
        }
        let absent = FnSettingsSnapshot(storedAction: nil, effectiveAction: 1)
        let access = FakeFnSettings(absent)
        let first = SystemFnAction(access: access, defaults: defaults)
        try first.takeOver()
        let afterCrash = SystemFnAction(access: access, defaults: defaults)
        try afterCrash.recover()
        precondition(access.current == absent, "Recover missing preference and actual pre-existing behavior")
        let changed = FnSettingsSnapshot(storedAction: 3, effectiveAction: 3)
        access.current = changed
        try afterCrash.takeOver()
        try afterCrash.restore()
        precondition(access.current == changed, "Each enable saves the latest user setting")
        // A manual reset after a crash must win over an old recovery snapshot.
        let manual = FnSettingsSnapshot(storedAction: 2, effectiveAction: 2)
        let old = SystemFnAction(access: access, defaults: defaults)
        try old.takeOver()
        access.current = manual
        let fresh = SystemFnAction(access: access, defaults: defaults)
        let writesBeforeRecovery = access.writes.count
        try fresh.recover()
        precondition(access.current == manual && access.writes.count == writesBeforeRecovery)
        precondition(defaults.data(forKey: "originalFnSettings.v1") == nil)

        // A failed restore keeps its snapshot, and a later attempt can restore it.
        let retry = SystemFnAction(access: access, defaults: defaults)
        try retry.takeOver()
        access.failWrites = true
        do { try retry.restore(); fatalError("Restore must fail") } catch {}
        precondition(defaults.data(forKey: "originalFnSettings.v1") != nil)
        do { try retry.takeOver(); fatalError("Unresolved restore must block enabling") } catch {}
        access.failWrites = false
        try retry.restore()
        precondition(access.current == manual)

        // A silently ignored takeover must not be reported as success.
        access.ignoredWrites = true
        let ignored = SystemFnAction(access: access, defaults: defaults)
        do { try ignored.takeOver(); fatalError("Ignored write must fail verification") } catch {}
        precondition(access.current == manual)
        precondition(defaults.data(forKey: "originalFnSettings.v1") == nil)
        access.ignoredWrites = false

        let partial = SystemFnAction(access: access, defaults: defaults)
        access.failNextWritePartially = true
        do { try partial.takeOver(); fatalError("Partial write must fail") } catch {}
        precondition(access.current == manual, "Partial takeover must roll back both preference and cache")
        precondition(defaults.data(forKey: "originalFnSettings.v1") == nil)

        let silentRestore = SystemFnAction(access: access, defaults: defaults)
        try silentRestore.takeOver()
        access.ignoredWrites = true
        do { try silentRestore.restore(); fatalError("Ignored restore must fail") } catch {}
        precondition(defaults.data(forKey: "originalFnSettings.v1") != nil)
        access.ignoredWrites = false
        try silentRestore.restore()
        precondition(access.current == manual)

        defaults.set(Data("broken snapshot".utf8), forKey: "originalFnSettings.v1")
        let corrupt = SystemFnAction(access: access, defaults: defaults)
        let writesBeforeCorrupt = access.writes.count
        do { try corrupt.recover(); fatalError("Corrupt recovery must fail") } catch {}
        do { try corrupt.takeOver(); fatalError("Corrupt recovery must block takeover") } catch {}
        precondition(access.writes.count == writesBeforeCorrupt)
        defaults.removeObject(forKey: "originalFnSettings.v1")

        // A changed action during a live session is also the user's property.
        try fresh.takeOver()
        access.current = changed
        let writesBeforeStop = access.writes.count
        try fresh.restore()
        precondition(access.current == changed && access.writes.count == writesBeforeStop)
        print("PASS: manual changes preserved; failed restore retains recovery; ignored takeover rejected")
        print("PASS: exact restore for actions 0/1/2/3, absent setting, crash recovery, fresh enable snapshot")
    }
}
