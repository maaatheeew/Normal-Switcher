import AppKit
import SwiftUI

@main @MainActor
struct NativeMenuTests {
    static func main() {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let model = SwitcherModel()
        var opened = 0
        let controller = NativeMenuController(model: model, openApplication: { opened += 1 })
        let menu = controller.menu
        precondition(menu.items.map(\.title) == ["Status: Off", "Quit Normal Switcher"])
        precondition(menu.items.allSatisfy { $0.view == nil && !$0.isSeparatorItem }, "Only standard native commands")
        precondition(!menu.showsStateColumn)
        menu.performActionForItem(at: 0)
        precondition(opened == 1 && !model.fnEnabled, "Status opens controls without toggling Fn")
        model.fnEnabled = true
        controller.refreshStates()
        precondition(menu.items[0].title == "Status: On")
        menu.performActionForItem(at: 0)
        precondition(opened == 2 && model.fnEnabled, "Repeated status action opens the same controls route")
        model.fnEnabled = false
        controller.refreshStates()
        precondition(menu.items[0].title == "Status: Off")
        let quit = menu.items[1]
        precondition(quit.keyEquivalent == "q" && quit.keyEquivalentModifierMask.contains(.command))
        for item in menu.items {
            guard let target = item.target as? NSObject, let action = item.action else { fatalError("Missing target") }
            precondition(target.responds(to: action))
        }
        let controls = ApplicationWindowController(model: model)
        guard let window = controls.window else { fatalError("No application window") }
        precondition(window.styleMask.contains(.titled) && window.styleMask.contains(.closable))
        precondition(!(window is NSPanel) && !window.isVisible, "Constructing controls must not show or activate a window")
        precondition(window.contentView is NSVisualEffectView)
        guard let hosting = window.contentView?.subviews.first as? NSHostingView<ApplicationView> else { fatalError("No app view") }
        hosting.layoutSubtreeIfNeeded()
        precondition(hosting.fittingSize.width <= 360 && hosting.fittingSize.height <= 320, "Content must fit the compact window")
        for isOn in [false, true] {
            let control = NSHostingView(rootView: LargeFnSwitch(isOn: .constant(isOn), toggle: {})
                .fixedSize().scaleEffect(3).frame(width: 180, height: 90))
            precondition(control.fittingSize.width == 180 && control.fittingSize.height == 90)
            control.layoutSubtreeIfNeeded()
            guard let native = findSwitch(in: control) else { fatalError("Must use the actual macOS NSSwitch") }
            precondition(native.state == (isOn ? .on : .off))
            precondition(native.intrinsicContentSize.width * 3 <= 180 && native.intrinsicContentSize.height * 3 <= 90,
                         "Scaled native control must fit without clipping")
        }
        var actual = false
        var requested = 0
        let coordinator = LargeFnSwitch.Coordinator(isOn: Binding(get: { actual }, set: { actual = $0 }), toggle: { requested += 1 })
        let native = NSSwitch()
        native.state = .on
        coordinator.changed(native)
        precondition(requested == 1 && native.state == .off, "Denied enable must reset the native switch even if model stays false")
        coordinator.toggle = { actual.toggle() }
        coordinator.changed(native)
        precondition(actual && native.state == .on)
        coordinator.changed(native)
        precondition(!actual && native.state == .off)
        for language in ["EN", "RU", "FR", "FIL", "ZH"] {
            for filled in [true, false] {
                let image = StatusLanguageIcon.image(language: language, filled: filled)
                precondition(image.isTemplate && image.size.height == 18 && image.size.width <= 38)
                precondition(image.tiffRepresentation != nil)
            }
        }
        print("PASS: native Status On/Off + Quit menu; status opens controls without changing Fn; compact window, scaled native NSSwitch with denied-state rollback, language icons; no screen/click verification")
    }

    private static func findSwitch(in view: NSView) -> NSSwitch? {
        if let control = view as? NSSwitch { return control }
        for child in view.subviews {
            if let found = findSwitch(in: child) { return found }
        }
        return nil
    }

}
