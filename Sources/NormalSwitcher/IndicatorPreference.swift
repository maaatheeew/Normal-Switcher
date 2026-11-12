import Foundation

enum IndicatorPreference: Codable, Equatable {
    case absent
    case boolean(Bool)
    case integer(Int)

    var isHidden: Bool {
        switch self {
        case .boolean(false), .integer(0): true
        default: false
        }
    }
}
