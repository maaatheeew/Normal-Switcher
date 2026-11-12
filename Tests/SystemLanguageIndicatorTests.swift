import Foundation

@MainActor
private final class MemoryIndicatorSettings: IndicatorSettingsAccess {
    var value: IndicatorPreference
    var writes = 0
    var reloads = 0
    var failWrites = false
    var ignoreWrites = false
    var failReloads = false
    init(_ value: IndicatorPreference) { self.value = value }
    func read() throws -> IndicatorPreference { value }
    func apply(_ newValue: IndicatorPreference) throws {
        if failWrites { throw NSError(domain: "TestIndicator", code: 1) }
        writes += 1
        if !ignoreWrites { value = newValue }
    }
    func reloadAgent() throws {
        if failReloads { throw NSError(domain: "TestIndicator", code: 2) }
        reloads += 1
    }
}

@main @MainActor
struct SystemLanguageIndicatorTests {
    static func main() throws {
        let domain = "NormalSwitcher.IndicatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let key = "originalLanguageIndicator.v1"
        for initial: IndicatorPreference in [.absent, .integer(1), .boolean(true), .integer(2), .integer(0), .boolean(false)] {
            let access = MemoryIndicatorSettings(initial)
            let owner = SystemLanguageIndicator(access: access, defaults: defaults)
            try owner.start()
            try owner.start()
            precondition(access.value.isHidden)
            if initial.isHidden {
                precondition(access.writes == 0 && access.reloads == 0 && defaults.object(forKey: key) == nil)
            } else {
                precondition(access.writes == 1 && access.reloads == 1 && defaults.data(forKey: key) != nil)
            }
            try owner.restore()
            precondition(access.value == initial, "Restore absence/bool/int exactly")
            let writes = access.writes
            try owner.restore()
            precondition(access.writes == writes && defaults.object(forKey: key) == nil)
        }
        let access = MemoryIndicatorSettings(.absent)
        let crashed = SystemLanguageIndicator(access: access, defaults: defaults)
        try crashed.start()
        let resumed = SystemLanguageIndicator(access: access, defaults: defaults)
        try resumed.start()
        try resumed.restore()
        precondition(access.value == .absent, "A crash must not replace the original snapshot with hidden")

        try resumed.start()
        access.value = .boolean(true)
        let writes = access.writes
        try resumed.restore()
        precondition(access.value == .boolean(true) && access.writes == writes, "Preserve manual change while running")

        try resumed.start()
        access.value = .integer(2)
        let afterManualReset = SystemLanguageIndicator(access: access, defaults: defaults)
        try afterManualReset.start()
        try afterManualReset.restore()
        precondition(access.value == .integer(2), "Manual change after a crash becomes the new baseline")

        try afterManualReset.start()
        access.failWrites = true
        do { try afterManualReset.restore(); fatalError("Failed restore must throw") } catch {}
        precondition(defaults.data(forKey: key) != nil)
        do { try afterManualReset.start(); fatalError("Unresolved recovery must block start") } catch {}
        access.failWrites = false
        try afterManualReset.restore()
        precondition(access.value == .integer(2))

        access.ignoreWrites = true
        let ignored = SystemLanguageIndicator(access: access, defaults: defaults)
        do { try ignored.start(); fatalError("Ignored hide must throw") } catch {}
        precondition(access.value == .integer(2) && defaults.object(forKey: key) == nil)
        access.ignoreWrites = false

        try ignored.start()
        access.failReloads = true
        do { try ignored.restore(); fatalError("Agent refresh failure must throw") } catch {}
        precondition(defaults.data(forKey: key) != nil, "Retain recovery until the restored setting is refreshed")
        access.failReloads = false
        try ignored.restore()
        precondition(access.value == .integer(2) && defaults.object(forKey: key) == nil)

        defaults.set(Data("invalid".utf8), forKey: key)
        let corrupt = SystemLanguageIndicator(access: access, defaults: defaults)
        let writesBefore = access.writes
        do { try corrupt.start(); fatalError("Corrupt recovery must throw") } catch {}
        precondition(access.writes == writesBefore)
        print("PASS: indicator hide/restore preserves absent/bool/int; crash recovery, manual changes, write/refresh failure, corruption and repeat lifecycle; fake settings/agent only")
    }
}
