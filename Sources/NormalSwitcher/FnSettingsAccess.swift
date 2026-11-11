import Foundation

@MainActor
protocol FnSettingsAccess: AnyObject {
    func read() -> FnSettingsSnapshot
    func apply(_ snapshot: FnSettingsSnapshot)
}
