import Foundation

@MainActor
protocol IndicatorSettingsAccess: AnyObject {
    func read() throws -> IndicatorPreference
    func apply(_ value: IndicatorPreference) throws
    func reloadAgent() throws
}
