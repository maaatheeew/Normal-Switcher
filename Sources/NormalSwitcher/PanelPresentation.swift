struct PanelPresentation {
    private(set) var isPresented = false

    mutating func toggle() -> Bool {
        isPresented.toggle()
        return isPresented
    }

    mutating func present() { isPresented = true }
    mutating func dismiss() { isPresented = false }

    mutating func focusLost(pointerOnStatusItem: Bool) {
        // The button click will toggle the existing state; don't dismiss first.
        if !pointerOnStatusItem { dismiss() }
    }
}
