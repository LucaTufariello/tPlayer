import Foundation
import AVFoundation
import CoreGraphics
import CoreText
import AppKit

struct Sample {
    let title: String
    let subtitle: String
    let slug: String
    let top: UInt32
    let bottom: UInt32
    let accent: UInt32
}

let samples: [Sample] = [
    Sample(title: "The Quiet Coast", subtitle: "a study in salt and light", slug: "quiet-coast", top: 0x3B4A47, bottom: 0x101817, accent: 0xD8A878),
    Sample(title: "Paper Moons", subtitle: "letters from a small orbit", slug: "paper-moons", top: 0x6B3F2E, bottom: 0x1D120E, accent: 0xE3B98C),
    Sample(title: "A Field of Static", subtitle: "the last broadcast of summer", slug: "field-of-static", top: 0x3E4658, bottom: 0x121620, accent: 0xB9C7DA),
    Sample(title: "Northbound", subtitle: "a journey in three winters", slug: "northbound", top: 0x6C5A35, bottom: 0x1D180F, accent: 0xE2C992)
]

let width = 1280
let height = 720
let W = CGFloat(width)
let H = CGFloat(height)
let fps: Int32 = 30
let seconds = 8
let frameCount = Int(fps) * seconds

let outputDir = URL(fileURLWithPath: "/tmp/tplayer_samples", isDirectory: true)
let thumbDir = outputDir.appendingPathComponent("thumbs", isDirectory: true)
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(at: thumbDir, withIntermediateDirectories: true)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func drawText(_ text: String, in ctx: CGContext, at point: CGPoint, size: CGFloat, color: CGColor, tracking: CGFloat = 0) {
    let font = CTFontCreateWithName("NewYork-Regular" as CFString, size, nil)
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        NSAttributedString.Key(kCTKernAttributeName as String): tracking
    ]
    let attributed = NSAttributedString(string: text, attributes: attributes)
    let line = CTLineCreateWithAttributedString(attributed)
    ctx.textPosition = point
    CTLineDraw(line, ctx)
}

func drawFrame(_ ctx: CGContext, sample: Sample, frame: Int) {
    let t = CGFloat(frame) / CGFloat(frameCount)
    let rect = CGRect(x: 0, y: 0, width: W, height: H)

    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [color(sample.top), color(sample.bottom)] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: H),
        end: CGPoint(x: W, y: 0),
        options: []
    )

    // Soft drifting light
    ctx.saveGState()
    ctx.setBlendMode(.screen)
    for i in 0..<3 {
        let phase = t * .pi * 2 + CGFloat(i) * 2.1
        let cx = W * 0.5 + cos(phase) * CGFloat(260 + i * 70)
        let cy = H * 0.58 + sin(phase * 0.8) * CGFloat(110 + i * 30)
        let radius = CGFloat(150 + i * 55)
        let glow = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [color(sample.accent, 0.20 - CGFloat(i) * 0.04), color(sample.accent, 0)] as CFArray,
            locations: [0, 1]
        )!
        ctx.drawRadialGradient(
            glow,
            startCenter: CGPoint(x: cx, y: cy),
            startRadius: 0,
            endCenter: CGPoint(x: cx, y: cy),
            endRadius: radius,
            options: []
        )
    }
    ctx.restoreGState()

    // Thin horizon line
    ctx.setStrokeColor(color(0xFFFFFF, 0.12))
    ctx.setLineWidth(1)
    ctx.move(to: CGPoint(x: 0, y: H * 0.34))
    ctx.addLine(to: CGPoint(x: W, y: H * 0.34))
    ctx.strokePath()

    // Vignette
    let vignette = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [color(0x000000, 0), color(0x000000, 0.48)] as CFArray,
        locations: [0.45, 1]
    )!
    ctx.drawRadialGradient(
        vignette,
        startCenter: CGPoint(x: W / 2, y: H / 2),
        startRadius: 160,
        endCenter: CGPoint(x: W / 2, y: H / 2),
        endRadius: 760,
        options: []
    )

    // Grain
    var rng = SystemRandomNumberGenerator()
    for _ in 0..<1500 {
        let x = CGFloat.random(in: 0..<W, using: &rng)
        let y = CGFloat.random(in: 0..<H, using: &rng)
        let r = CGFloat.random(in: 0.4...1.4, using: &rng)
        ctx.setFillColor(color(0xFFFFFF, CGFloat.random(in: 0.008...0.03, using: &rng)))
        ctx.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
    }

    // Wordmark only. The app draws the film's title over the artwork itself,
    // so baking one into the frame would collide with it in the library grid.
    drawText("tPLAYER ORIGINAL", in: ctx, at: CGPoint(x: 82, y: 648), size: 11, color: color(0xF5EFE4, 0.46), tracking: 2.4)

    // Frame border
    ctx.setStrokeColor(color(0xFFFFFF, 0.10))
    ctx.setLineWidth(1)
    ctx.stroke(rect.insetBy(dx: 34, dy: 34))
}

func makeVideo(_ sample: Sample) throws -> URL {
    let url = outputDir.appendingPathComponent("\(sample.slug).mp4")
    try? FileManager.default.removeItem(at: url)

    let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
    let settings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 2_400_000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
        ]
    ]

    let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    input.expectsMediaDataInRealTime = false

    let attributes: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height
    ]
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: input,
        sourcePixelBufferAttributes: attributes
    )

    writer.add(input)
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    for frame in 0..<frameCount {
        while !input.isReadyForMoreMediaData {
            usleep(500)
        }

        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attributes as CFDictionary,
            &pixelBuffer
        )
        guard let buffer = pixelBuffer else { continue }

        CVPixelBufferLockBaseAddress(buffer, [])
        if let base = CVPixelBufferGetBaseAddress(buffer),
           let ctx = CGContext(
               data: base,
               width: width,
               height: height,
               bitsPerComponent: 8,
               bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
               space: colorSpace,
               bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
           ) {
            drawFrame(ctx, sample: sample, frame: frame)
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])

        let time = CMTime(value: Int64(frame), timescale: fps)
        adaptor.append(buffer, withPresentationTime: time)
    }

    input.markAsFinished()
    let semaphore = DispatchSemaphore(value: 0)
    writer.finishWriting {
        semaphore.signal()
    }
    semaphore.wait()

    if writer.status != .completed {
        throw writer.error ?? NSError(domain: "samples", code: 1)
    }
    return url
}

func makeThumbnail(for url: URL, sample: Sample) {
    let asset = AVURLAsset(url: url)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 1400, height: 1400)
    do {
        let cg = try generator.copyCGImage(at: CMTime(seconds: 2.4, preferredTimescale: 600), actualTime: nil)
        let rep = NSBitmapImageRep(cgImage: cg)
        if let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.88]) {
            let thumbURL = thumbDir.appendingPathComponent("\(sample.slug).jpg")
            try data.write(to: thumbURL)
            print("Thumbnail \(thumbURL.path)")
        }
    } catch {
        print("Thumbnail failed: \(error)")
    }
}

for sample in samples {
    do {
        let url = try makeVideo(sample)
        print("Wrote \(url.path)")
        makeThumbnail(for: url, sample: sample)
    } catch {
        print("Failed \(sample.slug): \(error)")
    }
}
