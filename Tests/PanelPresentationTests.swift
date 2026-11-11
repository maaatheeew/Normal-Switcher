@main
struct PanelPresentationTests {
    static func main() {
        var state = PanelPresentation()
        precondition(!state.isPresented)
        for _ in 0..<1000 {
            precondition(state.toggle(), "First status click opens")
            state.focusLost(pointerOnStatusItem: true)
            precondition(state.isPresented, "Status click focus loss must not dismiss before toggle")
            precondition(!state.toggle(), "Second status click closes rather than reopening")
        }
        _ = state.toggle()
        state.focusLost(pointerOnStatusItem: false)
        precondition(!state.isPresented, "Moving to another app dismisses")
        state.present()
        state.dismiss()
        precondition(!state.isPresented, "Escape/outside click dismiss")
        print("PASS: 1,000 open/status-focus-loss/close sequences, outside focus and Escape state")
    }
}
