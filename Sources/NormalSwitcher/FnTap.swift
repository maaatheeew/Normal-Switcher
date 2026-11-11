/// A tap has a destination fixed at key-down, never a second relative toggle.
struct FnTap {
    private var held = false
    private var chord = false
    private var destination: String?

    mutating func down(destination: String?, withModifiers: Bool) {
        guard !held else { return }
        held = true
        chord = withModifiers
        self.destination = destination
    }

    mutating func usedInChord() { if held { chord = true } }

    mutating func up() -> String? {
        let result = held && !chord ? destination : nil
        self = FnTap()
        return result
    }

    mutating func cancel() { self = FnTap() }
}
