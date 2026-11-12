import AppKit
import SwiftUI

/// Use the macOS control itself so its glass rendering follows the installed OS.
struct LargeFnSwitch: NSViewRepresentable {
    @Binding var isOn: Bool
    let toggle: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(isOn: $isOn, toggle: toggle) }

    func makeNSView(context: Context) -> NSSwitch {
        let control = NSSwitch()
        control.controlSize = .regular
        control.state = isOn ? .on : .off
        control.target = context.coordinator
        control.action = #selector(Coordinator.changed(_:))
        control.setAccessibilityLabel("Switch with Fn")
        control.setAccessibilityHelp("Use Fn to switch keyboard languages. Turn off to restore the previous macOS Fn action.")
        control.setContentHuggingPriority(.required, for: .horizontal)
        control.setContentHuggingPriority(.required, for: .vertical)
        return control
    }

    func updateNSView(_ control: NSSwitch, context: Context) {
        context.coordinator.isOn = $isOn
        context.coordinator.toggle = toggle
        let state: NSControl.StateValue = isOn ? .on : .off
        guard control.state != state else { return }
        if context.environment.accessibilityReduceMotion || control.window == nil {
            control.state = state
        } else {
            NSAnimationContext.runAnimationGroup { animation in
                animation.duration = 0.18
                control.animator().state = state
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        var isOn: Binding<Bool>
        var toggle: () -> Void

        init(isOn: Binding<Bool>, toggle: @escaping () -> Void) {
            self.isOn = isOn
            self.toggle = toggle
        }

        @objc func changed(_ sender: NSSwitch) {
            toggle()
            // A denied request can leave the model unchanged. Reset the native control
            // immediately instead of depending on a SwiftUI value change to redraw it.
            sender.state = isOn.wrappedValue ? .on : .off
        }
    }
}
