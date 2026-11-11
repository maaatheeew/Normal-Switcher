import Foundation
import ServiceManagement

@MainActor
final class LoginItemManager {
    var status: SMAppService.Status { SMAppService.mainApp.status }
    var isEnabled: Bool { [.enabled, .requiresApproval].contains(status) }

    @discardableResult
    func setEnabled(_ enabled: Bool) throws -> SMAppService.Status {
        if enabled != isEnabled {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        }
        return status
    }

    /// Uses the same service as the toggle, and leaves the original registration intact.
    func verifyRoundTrip() throws {
        let before = status
        guard before == .enabled || before == .notRegistered else {
            throw NSError(domain: "NormalSwitcher.LoginCheck", code: 1, userInfo: [NSLocalizedDescriptionKey: "Login item requires manual approval or is unavailable: \(before.rawValue)"])
        }
        defer { _ = try? setEnabled(before == .enabled) }
        let on = try setEnabled(true)
        guard on == .enabled else { throw NSError(domain: "NormalSwitcher.LoginCheck", code: 2, userInfo: [NSLocalizedDescriptionKey: "Registration needs approval: \(on.rawValue)"]) }
        let off = try setEnabled(false)
        guard off == .notRegistered else { throw NSError(domain: "NormalSwitcher.LoginCheck", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unregister did not clear login item: \(off.rawValue)"]) }
        let restored = try setEnabled(before == .enabled)
        guard restored == before else { throw NSError(domain: "NormalSwitcher.LoginCheck", code: 4) }
        print("PASS: SMAppService register -> enabled -> unregister -> notRegistered; original state restored (\(before.rawValue))")
    }
}
