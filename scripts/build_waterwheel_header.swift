import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum Pose { case running, windUp, waterWheel, none }

struct FrameSpec {
    let x: CGFloat
    let rotation: CGFloat
    let waterScale: CGFloat
    let delay: Double
    let pose: Pose
    let bob: CGFloat
}

// A thin transparent strip: the original Capsule Render header remains remote
// and unchanged beneath this image in README.
let canvasSize = CGSize(width: 960, height: 64)
let waterWheelInputURL = URL(fileURLWithPath: "assets/tanjiro-mini-water-sprite-v2.png")
let runningInputURL = URL(fileURLWithPath: "assets/tanjiro-running-sprite-v3.png")
let windUpInputURL = URL(fileURLWithPath: "assets/tanjiro-waterwheel-windup-sprite-v1.png")
let outputURL = URL(fileURLWithPath: "assets/tanjiro-waterwheel-top.gif")

func loadImage(at url: URL) -> CGImage {
    guard let image = NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fputs("Could not load \(url.path)\n", stderr)
        exit(1)
    }
    return image
}

func alphaBounds(of image: CGImage) -> CGRect {
    let bytesPerRow = image.width * 4
    var pixels = [UInt8](repeating: 0, count: bytesPerRow * image.height)
    guard let context = CGContext(data: &pixels, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        return CGRect(x: 0, y: 0, width: image.width, height: image.height)
    }
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    var minX = image.width, minY = image.height, maxX = 0, maxY = 0
    for y in 0..<image.height {
        for x in 0..<image.width where pixels[y * bytesPerRow + x * 4 + 3] > 8 {
            minX = min(minX, x); minY = min(minY, y)
            maxX = max(maxX, x); maxY = max(maxY, y)
        }
    }
    guard minX <= maxX, minY <= maxY else {
        return CGRect(x: 0, y: 0, width: image.width, height: image.height)
    }
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}

func croppedSprite(_ source: CGImage) -> CGImage {
    let bounds = alphaBounds(of: source).insetBy(dx: -8, dy: -8).intersection(CGRect(x: 0, y: 0, width: source.width, height: source.height))
    guard let cropped = source.cropping(to: bounds.integral) else { fatalError("Could not crop sprite.") }
    return cropped
}

let waterWheelSprite = croppedSprite(loadImage(at: waterWheelInputURL))
let runningSprite = croppedSprite(loadImage(at: runningInputURL))
let windUpSprite = croppedSprite(loadImage(at: windUpInputURL))

// One character: run left, prepare the sword, complete a turn, run out, reset.
let frames: [FrameSpec] = [
    .init(x: 875, rotation: 0, waterScale: 0, delay: 0.15, pose: .running, bob: 0),
    .init(x: 802, rotation: 0, waterScale: 0, delay: 0.12, pose: .running, bob: 2),
    .init(x: 730, rotation: 0, waterScale: 0, delay: 0.12, pose: .running, bob: 0),
    .init(x: 657, rotation: 0, waterScale: 0, delay: 0.12, pose: .running, bob: 2),
    .init(x: 580, rotation: 0, waterScale: 0, delay: 0.18, pose: .windUp, bob: 0),
    .init(x: 520, rotation: 0, waterScale: 0, delay: 0.16, pose: .windUp, bob: 0),
    .init(x: 456, rotation: -40, waterScale: 0.4, delay: 0.14, pose: .waterWheel, bob: 0),
    .init(x: 350, rotation: -145, waterScale: 0.88, delay: 0.16, pose: .waterWheel, bob: 0),
    .init(x: 244, rotation: -255, waterScale: 1, delay: 0.16, pose: .waterWheel, bob: 0),
    .init(x: 144, rotation: -360, waterScale: 0.55, delay: 0.14, pose: .waterWheel, bob: 0),
    .init(x: 66, rotation: 0, waterScale: 0, delay: 0.12, pose: .running, bob: 2),
    .init(x: -12, rotation: 0, waterScale: 0, delay: 0.12, pose: .running, bob: 0),
    .init(x: -88, rotation: 0, waterScale: 0, delay: 0.15, pose: .running, bob: 2),
    .init(x: 0, rotation: 0, waterScale: 0, delay: 0.16, pose: .none, bob: 0)
]

func clear(_ context: CGContext) {
    context.setBlendMode(.copy)
    context.setFillColor(NSColor.clear.cgColor)
    context.fill(CGRect(origin: .zero, size: canvasSize))
    context.setBlendMode(.normal)
}

func drawWater(center: CGPoint, scale: CGFloat, rotation: CGFloat, in context: CGContext) {
    guard scale > 0 else { return }
    let radius = 26 * scale
    context.saveGState()
    context.translateBy(x: center.x, y: center.y)
    context.rotate(by: rotation * .pi / 180)
    context.setLineCap(.round)
    context.setLineWidth(1.8)
    context.setStrokeColor(NSColor(red: 133 / 255, green: 235 / 255, blue: 240 / 255, alpha: 0.92).cgColor)
    context.addArc(center: .zero, radius: radius, startAngle: 0.35, endAngle: 5.75, clockwise: false)
    context.strokePath()
    context.setLineWidth(0.9)
    context.setStrokeColor(NSColor(red: 71 / 255, green: 191 / 255, blue: 208 / 255, alpha: 0.82).cgColor)
    context.addArc(center: .zero, radius: max(7, radius - 4), startAngle: 2.05, endAngle: 6.1, clockwise: false)
    context.strokePath()
    context.restoreGState()
}

func image(for spec: FrameSpec) -> CGImage {
    let context = CGContext(data: nil, width: Int(canvasSize.width), height: Int(canvasSize.height), bitsPerComponent: 8, bytesPerRow: Int(canvasSize.width) * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.interpolationQuality = .none
    clear(context)
    guard spec.pose != .none else { return context.makeImage()! }

    let sprite: CGImage
    switch spec.pose {
    case .running: sprite = runningSprite
    case .windUp: sprite = windUpSprite
    case .waterWheel: sprite = waterWheelSprite
    case .none: fatalError("Empty frame has no sprite.")
    }
    let spriteHeight: CGFloat = 54
    let spriteWidth = spriteHeight * CGFloat(sprite.width) / CGFloat(sprite.height)
    let center = CGPoint(x: spec.x + spriteWidth / 2, y: 29 + spec.bob)
    if spec.pose == .waterWheel {
        drawWater(center: center, scale: spec.waterScale, rotation: spec.rotation, in: context)
    }
    context.saveGState()
    context.translateBy(x: center.x, y: center.y)
    context.rotate(by: spec.rotation * .pi / 180)
    context.draw(sprite, in: CGRect(x: -spriteWidth / 2, y: -spriteHeight / 2, width: spriteWidth, height: spriteHeight))
    context.restoreGState()
    return context.makeImage()!
}

guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else {
    fputs("Could not create GIF destination.\n", stderr)
    exit(1)
}
CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
for frame in frames {
    CGImageDestinationAddImage(destination, image(for: frame), [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: frame.delay]] as CFDictionary)
}
guard CGImageDestinationFinalize(destination) else {
    fputs("Could not write GIF.\n", stderr)
    exit(1)
}
print("Wrote \(outputURL.path)")
