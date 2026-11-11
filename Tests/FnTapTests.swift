@main
struct FnTapTests {
    static func main() {
        var tap = FnTap()
        check(tap.up() == nil, "Unmatched release")
        tap.down(destination: "en", withModifiers: false)
        tap.down(destination: "ru", withModifiers: false)
        check(tap.up() == "en", "Fixed destination survives duplicate down/system switch")
        check(tap.up() == nil, "Duplicate release")
        tap.down(destination: "ru", withModifiers: false)
        tap.usedInChord()
        check(tap.up() == nil, "Fn plus key stays a chord")
        tap.down(destination: "ru", withModifiers: true)
        check(tap.up() == nil, "Modifier already held")
        tap.down(destination: "ru", withModifiers: false)
        check(tap.up() == "ru", "Next tap after a chord")
        tap.down(destination: "en", withModifiers: false)
        tap.cancel()
        check(tap.up() == nil, "Pause cancels an in-flight press")
        tap.down(destination: nil, withModifiers: false)
        check(tap.up() == nil, "One/no input source")
        for i in 0..<1000 {
            let id = i.isMultiple(of: 2) ? "en" : "ru"
            tap.down(destination: id, withModifiers: false)
            check(tap.up() == id, "Rapid sequential taps")
        }
        print("PASS: 8 regression scenarios, 1,000 sequential taps")
    }
    static func check(_ result: @autoclosure () -> Bool, _ message: String) {
        precondition(result(), message)
    }
}
