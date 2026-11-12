// Adapted from Kirchberg/Confetti at a876f3f725e4277ff648e58f30078a0b6e6610ff.
// Copyright (c) 2023 Kostarev Kirill. MIT license: ThirdParty/Confetti/LICENSE.

import AppKit
import QuartzCore

@MainActor
final class ConfettiView: NSView {
    enum Direction {
        case bottom

        var longitude: CGFloat { 0 }
        func position(in rect: CGRect) -> CGPoint { CGPoint(x: rect.midX, y: rect.maxY + 12) }
    }

    override var isFlipped: Bool { true }
    private let emitters: [ConfettiEmitter]
    private let direction: Direction
    private let configuration: ConfettiConfiguration
    private var hasEmitted = false
    private(set) var confettiLayer: CAEmitterLayer?

    init(emitters: [ConfettiEmitter], direction: Direction, configuration: ConfettiConfiguration) {
        self.emitters = emitters
        self.direction = direction
        self.configuration = configuration
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        guard bounds.width > 0, bounds.height > 0 else { return }
        if !hasEmitted { emit() }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        confettiLayer?.frame = bounds
        confettiLayer?.emitterPosition = configuration.origin ?? direction.position(in: bounds)
        CATransaction.commit()
    }

    func emit() {
        clear()
        guard !(configuration.respectReducedMotion && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion),
              bounds.width > 0, bounds.height > 0 else { return }
        let emitter = CAEmitterLayer()
        emitter.frame = bounds
        emitter.emitterMode = .outline
        emitter.emitterShape = .line
        emitter.emitterSize = CGSize(width: 1, height: 1)
        emitter.emitterPosition = configuration.origin ?? direction.position(in: bounds)
        emitter.beginTime = CACurrentMediaTime()
        emitter.emitterCells = emitters.map { content in
            let cell = CAEmitterCell()
            cell.name = content.id
            cell.contents = content.image
            cell.color = content.color.cgColor
            cell.beginTime = 0
            cell.birthRate = Float(configuration.particleCount)
            cell.lifetime = Float(configuration.lifetime)
            cell.velocity = configuration.startVelocity
            cell.velocityRange = configuration.startVelocity * (1 - configuration.velocityDecay)
            cell.xAcceleration = configuration.drift
            cell.yAcceleration = configuration.gravity
            cell.emissionRange = configuration.spread
            cell.emissionLongitude = configuration.angle ?? direction.longitude
            cell.scale = configuration.scale
            cell.scaleRange = configuration.scaleRange
            cell.spin = configuration.spin
            cell.spinRange = configuration.spinRange
            return cell
        }
        layer?.addSublayer(emitter)
        confettiLayer = emitter
        addGravityAnimation(to: emitter)
        addBirthrateAnimation(to: emitter)
    }

    func clear() {
        hasEmitted = true
        confettiLayer?.removeAllAnimations()
        confettiLayer?.removeFromSuperlayer()
        confettiLayer = nil
    }

    private func addGravityAnimation(to emitter: CAEmitterLayer) {
        for content in emitters {
            let animation = CABasicAnimation(keyPath: "emitterCells.\(content.id).yAcceleration")
            animation.duration = configuration.gravityAnimationDuration
            animation.fromValue = 0
            animation.toValue = configuration.gravity
            animation.timingFunction = CAMediaTimingFunction(name: .easeIn)
            emitter.add(animation, forKey: "gravity.\(content.id)")
        }
    }

    private func addBirthrateAnimation(to emitter: CAEmitterLayer) {
        let animation = CABasicAnimation(keyPath: "birthRate")
        animation.duration = configuration.birthRateAnimationDuration
        animation.fromValue = 1
        animation.toValue = 0
        emitter.add(animation, forKey: "birthRate")
        emitter.birthRate = 0
    }
}
