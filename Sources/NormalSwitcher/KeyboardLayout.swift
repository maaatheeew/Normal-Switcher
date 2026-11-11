import Foundation

struct KeyboardLayout: Identifiable, Equatable {
    let id: String
    let name: String
    let shortName: String
    var isASCIICapable: Bool = false
}
