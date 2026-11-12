import Foundation

@MainActor
protocol FnSettingsAccess: AnyObject {
    func read() throws -> FnSettingsSnapshot
    func apply(_ snapshot: FnSettingsSnapshot) throws
}

enum FnControlError: Error {
    case unavailable, readFailed, writeFailed, recoveryFailed
}
