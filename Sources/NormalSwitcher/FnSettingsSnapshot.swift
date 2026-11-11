import Foundation

struct FnSettingsSnapshot: Codable, Equatable {
    let storedAction: Int?
    let effectiveAction: Int
}
