import Foundation

@MainActor
final class FakeFnSettings: FnSettingsAccess {
    var current: FnSettingsSnapshot
    var writes: [FnSettingsSnapshot] = []
    init(_ initial: FnSettingsSnapshot) { current = initial }
    func read() -> FnSettingsSnapshot { current }
    func apply(_ snapshot: FnSettingsSnapshot) { current = snapshot; writes.append(snapshot) }
}

@main
@MainActor
struct SystemFnActionTests {
    static func main() {
        let domain = "NormalSwitcher.Tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: domain) else { fatalError("Test preferences unavailable") }
        defer { defaults.removePersistentDomain(forName: domain) }
        let takeover = FnSettingsSnapshot(storedAction: 0, effectiveAction: 0, languageIndicator: nil)
        for value in [0, 1, 2, 3] {
            let original = FnSettingsSnapshot(storedAction: value, effectiveAction: value, languageIndicator: nil)
            let access = FakeFnSettings(original)
            let controller = SystemFnAction(access: access, defaults: defaults)
            controller.restore()
            precondition(access.writes.isEmpty, "Off must not alter a setting it never owned")
            controller.takeOver()
            controller.takeOver()
            precondition(access.current == takeover && access.writes.count == 1, "Take over once")
            controller.restore()
            precondition(access.current == original, "Restore the exact original action")
            controller.restore()
            precondition(access.writes.count == 2, "Repeated off has no side effect")
        }
        let absent = FnSettingsSnapshot(storedAction: nil, effectiveAction: 1, languageIndicator: 1)
        let access = FakeFnSettings(absent)
        let first = SystemFnAction(access: access, defaults: defaults)
        first.takeOver()
        let afterCrash = SystemFnAction(access: access, defaults: defaults)
        afterCrash.recover()
        precondition(access.current == absent, "Recover missing preference and actual pre-existing behavior")
        let changed = FnSettingsSnapshot(storedAction: 3, effectiveAction: 3, languageIndicator: 0)
        access.current = changed
        afterCrash.takeOver()
        afterCrash.restore()
        precondition(access.current == changed, "Each enable saves the latest user setting")
        print("PASS: exact restore for actions 0/1/2/3, absent setting, crash recovery, fresh enable snapshot")
    }
}
