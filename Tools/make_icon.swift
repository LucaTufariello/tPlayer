import AppKit
import CoreGraphics
import Foundation

let size = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("Could not create context") }

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))

let inset: CGFloat = 74
let square = CGRect(x: inset, y: inset, width: CGFloat(size) - inset * 2, height: CGFloat(size) - inset * 2)
let radius: CGFloat = 196
let squarePath = CGPath(roundedRect: square, cornerWidth: radius, cornerHeight: radius, transform: nil)

// Soft paper shadow
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 38, color: color(0x2B2117, 0.30))
ctx.addPath(squarePath)
ctx.setFillColor(color(0xF2ECE1))
ctx.fillPath()
ctx.restoreGState()

// Paper gradient
ctx.saveGState()
ctx.addPath(squarePath)
ctx.clip()
let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [color(0xFCF8F0), color(0xEDE3D3)] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: 180, y: 900),
    end: CGPoint(x: 850, y: 110),
    options: []
)

// Grain
var rng = SystemRandomNumberGenerator()
for _ in 0..<2600 {
    let x = CGFloat.random(in: square.minX...square.maxX, using: &rng)
    let y = CGFloat.random(in: square.minY...square.maxY, using: &rng)
    let r = CGFloat.random(in: 0.4...1.5, using: &rng)
    ctx.setFillColor(color(0x211E19, CGFloat.random(in: 0.012...0.04, using: &rng)))
    ctx.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
}
ctx.restoreGState()

// Border
ctx.addPath(squarePath)
ctx.setStrokeColor(color(0x211E19, 0.16))
ctx.setLineWidth(6)
ctx.strokePath()

// Inner hairline
let inner = square.insetBy(dx: 26, dy: 26)
ctx.addPath(CGPath(roundedRect: inner, cornerWidth: radius - 26, cornerHeight: radius - 26, transform: nil))
ctx.setStrokeColor(color(0x211E19, 0.07))
ctx.setLineWidth(3)
ctx.strokePath()

// Terracotta disc
let center = CGPoint(x: 512, y: 500)
let discRadius: CGFloat = 254
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: color(0x6B2C12, 0.32))
ctx.setFillColor(color(0xB4552D))
ctx.fillEllipse(in: CGRect(x: center.x - discRadius, y: center.y - discRadius, width: discRadius * 2, height: discRadius * 2))
ctx.restoreGState()

// Disc gradient
ctx.saveGState()
ctx.addEllipse(in: CGRect(x: center.x - discRadius, y: center.y - discRadius, width: discRadius * 2, height: discRadius * 2))
ctx.clip()
let discGradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [color(0xC96B3F), color(0x9E4422)] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(
    discGradient,
    start: CGPoint(x: center.x - 160, y: center.y + 190),
    end: CGPoint(x: center.x + 160, y: center.y - 190),
    options: []
)
ctx.restoreGState()

// Inner ring
ctx.setStrokeColor(color(0xF5EFE4, 0.22))
ctx.setLineWidth(4)
ctx.strokeEllipse(in: CGRect(x: center.x - discRadius + 22, y: center.y - discRadius + 22, width: (discRadius - 22) * 2, height: (discRadius - 22) * 2))

// Play triangle
let triangle = CGMutablePath()
triangle.move(to: CGPoint(x: 442, y: 378))
triangle.addLine(to: CGPoint(x: 442, y: 622))
triangle.addLine(to: CGPoint(x: 646, y: 500))
triangle.closeSubpath()
ctx.addPath(triangle)
ctx.setFillColor(color(0x211E19))
ctx.setLineJoin(.round)
ctx.setLineWidth(18)
ctx.fillPath()

// Small paper glint on the triangle
ctx.addPath(CGPath(roundedRect: CGRect(x: 468, y: 430, width: 8, height: 140), cornerWidth: 4, cornerHeight: 4, transform: nil))
ctx.setFillColor(color(0xF5EFE4, 0.10))
ctx.fillPath()

guard let image = ctx.makeImage() else { fatalError("Could not render image") }
let rep = NSBitmapImageRep(cgImage: image)
guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("Could not encode PNG") }
let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png")
try data.write(to: output)
print("Wrote \(output.path)")
