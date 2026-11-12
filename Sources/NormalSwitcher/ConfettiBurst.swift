import SwiftUI

struct ConfettiBurst: NSViewRepresentable {
    // Keep the view alive until the last particles from the short emission have fallen.
    static let duration: Duration = .seconds(3)

    static var configuration: ConfettiConfiguration {
        var configuration = ConfettiConfiguration()
        configuration.particleCount = 25
        configuration.startVelocity = 500
        configuration.gravity = 700
        configuration.gravityAnimationDuration = 0.5
        configuration.birthRateAnimationDuration = 0.45
        configuration.lifetime = 2.5
        configuration.scale = 0.24
        configuration.scaleRange = 0.1
        configuration.respectReducedMotion = true
        return configuration
    }

    func makeNSView(context: Context) -> ConfettiView {
        ConfettiView(emitters: ConfettiEmitter.defaultEmitters, direction: .bottom, configuration: Self.configuration)
    }

    func updateNSView(_ view: ConfettiView, context: Context) {}

    static func dismantleNSView(_ view: ConfettiView, coordinator: Void) { view.clear() }
}
