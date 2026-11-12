import Foundation

struct FnSettingsSnapshot: Codable, Equatable {
    let storedAction: Int?
    let effectiveAction: Int

    var isValid: Bool {
        (0...3).contains(effectiveAction) && (storedAction.map { (0...3).contains($0) } ?? true)
    }
}
