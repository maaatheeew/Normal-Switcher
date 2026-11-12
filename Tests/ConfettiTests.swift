import AppKit
import QuartzCore

@main @MainActor
struct ConfettiTests {
    static func main() {
        NSApplication.shared.setActivationPolicy(.prohibited)
        var configuration = ConfettiBurst.configuration
        configuration.respectReducedMotion = false // Do not depend on the machine's accessibility preferences.
        let view = ConfettiView(emitters: ConfettiEmitter.defaultEmitters, direction: .bottom, configuration: configuration)
        view.layout()
        precondition(view.confettiLayer == nil, "No emission until layout has nonzero bounds")
        view.frame = CGRect(x: 0, y: 0, width: 360, height: 320)
        view.layout()
        guard let layer = view.confettiLayer, let cells = layer.emitterCells else { fatalError("No emitter") }
        precondition(view.isFlipped, "Preserve upstream UIKit geometry on macOS")
        precondition(layer.emitterPosition.x == 180 && layer.emitterPosition.y > 320, "Bottom source must be below the window's lower edge")
        precondition(cells.count == 12 && cells.allSatisfy { $0.contents != nil })
        precondition(cells.allSatisfy { $0.emissionLongitude == 0 && $0.emissionRange == .pi / 2 })
        precondition(cells.allSatisfy { $0.yAcceleration > 0 && $0.velocity > 0 && $0.beginTime == 0 })
        precondition(layer.birthRate == 0, "Stop emission after the initial burst")
        guard let birth = layer.animation(forKey: "birthRate") as? CABasicAnimation else { fatalError("No birth-rate animation") }
        precondition(birth.duration == 0.45 && (birth.toValue as? NSNumber)?.doubleValue == 0)
        precondition(layer.animationKeys()?.filter { $0.hasPrefix("gravity.") }.count == cells.count)
        precondition(view.hitTest(CGPoint(x: 180, y: 160)) == nil, "Confetti must never intercept switch or checkbox clicks")
        view.frame.size = CGSize(width: 420, height: 400)
        view.layout()
        precondition(view.confettiLayer === layer && layer.emitterPosition.x == 210 && layer.emitterPosition.y > 400, "Resize must reposition without emitting another layer")
        view.clear()
        precondition(view.confettiLayer == nil && layer.superlayer == nil && layer.animationKeys() == nil)
        view.layout()
        precondition(view.confettiLayer == nil, "Layout must not resurrect a cleared burst")
        view.emit()
        precondition(view.confettiLayer != nil && view.confettiLayer !== layer, "A new activation can create a fresh burst")
        view.clear()
        print("PASS: Kirchberg Confetti macOS port, bottom source, 12 emitters, gravity/birth-rate animations, resize, click-through and cleanup; particle trajectories not visually verified")
    }
}
