// Adapted from Kirchberg/Confetti at a876f3f725e4277ff648e58f30078a0b6e6610ff.
// Copyright (c) 2023 Kostarev Kirill. MIT license: ThirdParty/Confetti/LICENSE.

import AppKit

@MainActor
enum ConfettiEmitter {
    enum Shape: Hashable {
        case circle, square, rectangle
        @MainActor private static var cache: [Shape: CGImage] = [:]

        @MainActor var image: CGImage {
            if let image = Self.cache[self] { return image }
            guard let context = CGContext(data: nil, width: 20, height: 20, bitsPerComponent: 8, bytesPerRow: 0,
                                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                fatalError("Could not allocate confetti shape bitmap")
            }
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            let rect = CGRect(x: 0, y: 0, width: 20, height: 20)
            switch self {
            case .circle: context.fillEllipse(in: rect)
            case .square: context.fill(rect)
            case .rectangle: context.fill(CGRect(x: 0, y: 0, width: 20, height: 10))
            }
            guard let image = context.makeImage() else { fatalError("Could not create confetti shape image") }
            Self.cache[self] = image
            return image
        }
    }

    case shape(Shape, color: NSColor, id: String = UUID().uuidString)

    var id: String { switch self { case let .shape(_, _, id): id } }
    var color: NSColor { switch self { case let .shape(_, color, _): color } }
    var image: CGImage { switch self { case let .shape(shape, _, _): shape.image } }

    static var defaultEmitters: [ConfettiEmitter] {
        let colors: [NSColor] = [.systemRed, .systemPink, .systemYellow, .systemTeal, .systemBlue, .systemGreen]
        return colors.map { .shape(.rectangle, color: $0) } + colors.map { .shape(.circle, color: $0) }
    }
}
