# Confetti — macOS adaptation

Source: https://github.com/Kirchberg/Confetti
Revision: `a876f3f725e4277ff648e58f30078a0b6e6610ff`
Author: Kostarev Kirill
License: MIT; see [LICENSE](LICENSE).

The configuration, emitter shapes/colors and Core Animation gravity/birth-rate animation flow are adapted from the upstream ConfettiConfiguration.swift, ConfettiEmitter.swift, ConfettiLayer.swift and ConfettiView.swift. The app uses the bottom direction.

UIKit views and image rendering are replaced by AppKit NSView and Core Graphics. Layer setup/layout is owned by ConfettiView instead of a CALayer subclass. Only public particle spin APIs are used; upstream private particleType/orientation KVC is omitted. Layer/cell timing is relative to the burst start. Particle settings and lifetime are tuned for a 360×320 macOS window. Reduced Motion, hit testing and deterministic cleanup are handled by the macOS adapter.

The license is also copied into the built app bundle.
