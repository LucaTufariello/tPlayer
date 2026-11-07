import SwiftUI
import AppKit

// MARK: - Palette

extension NSColor {
    convenience init(srgbHex hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    static func adaptive(light: UInt32, lightAlpha: CGFloat = 1,
                         dark: UInt32, darkAlpha: CGFloat = 1) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(srgbHex: isDark ? dark : light,
                           alpha: isDark ? darkAlpha : lightAlpha)
        }
    }
}

private func adaptiveColor(light: UInt32, lightAlpha: Double = 1,
                           dark: UInt32, darkAlpha: Double = 1) -> Color {
    Color(nsColor: .adaptive(light: light, lightAlpha: lightAlpha,
                             dark: dark, darkAlpha: darkAlpha))
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    // Warm paper in light mode, warm charcoal in dark mode. Every surface and
    // type color resolves through the current appearance, so views that use
    // these names adapt automatically.
    static let paper        = adaptiveColor(light: 0xF2ECE1, dark: 0x1A1712)
    static let paperRaised  = adaptiveColor(light: 0xFAF6EE, dark: 0x24201A)
    static let paperDeep    = adaptiveColor(light: 0xE7DDCC, dark: 0x120F0B)
    static let ink          = adaptiveColor(light: 0x211E19, dark: 0xF2EADF)
    static let inkSecondary = adaptiveColor(light: 0x6F675A, dark: 0xB6AB99)
    static let inkTertiary  = adaptiveColor(light: 0x9A9082, dark: 0x8C8273)
    static let terracotta   = adaptiveColor(light: 0xB4552D, dark: 0xD9774C)
    static let terracottaDeep = adaptiveColor(light: 0x8E3F1F, dark: 0xB85E33)
    static let sage         = adaptiveColor(light: 0x6D7564, dark: 0x9DAE93)
    static let ochre        = adaptiveColor(light: 0xB48A3C, dark: 0xD6AC62)
    static let line         = adaptiveColor(light: 0x211E19, lightAlpha: 0.10,
                                            dark: 0xF2EADF, darkAlpha: 0.12)
    static let playerBg     = Color(hex: 0x0B0A09)
    static let playerPaper  = Color(hex: 0xF5EFE4)

    // Supporting roles that need their own dark-mode values.
    static let onAccent     = adaptiveColor(light: 0xFAF6EE, dark: 0x1A1712)
    static let shadow       = adaptiveColor(light: 0x5A4A33, dark: 0x000000)
    static let paperGlow    = adaptiveColor(light: 0xFFFFFF, lightAlpha: 0.28,
                                            dark: 0xFFFFFF, darkAlpha: 0.045)
    static let paperShade   = adaptiveColor(light: 0xD8C8AF, lightAlpha: 0.18,
                                            dark: 0x000000, darkAlpha: 0.30)
    static let paperVignette = adaptiveColor(light: 0x7A6A50, lightAlpha: 0.055,
                                             dark: 0x000000, darkAlpha: 0.30)
    static let scrim        = adaptiveColor(light: 0x211E19, lightAlpha: 0.34,
                                            dark: 0x000000, darkAlpha: 0.58)
}

extension NSColor {
    static let paper = NSColor.adaptive(light: 0xF2ECE1, dark: 0x1A1712)
}

// MARK: - Appearance

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Match System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Type

extension Font {
    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func bodyText(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color = .inkSecondary

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(1.7)
            .foregroundStyle(color)
    }
}

// MARK: - Paper surface

struct PaperBackground: View {
    var body: some View {
        ZStack {
            Color.paper

            LinearGradient(
                stops: [
                    .init(color: Color.paperGlow, location: 0),
                    .init(color: Color.clear, location: 0.42),
                    .init(color: Color.paperShade, location: 1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            PaperGrain()
                .opacity(0.85)

            RadialGradient(
                colors: [Color.clear, Color.paperVignette],
                center: .center,
                startRadius: 260,
                endRadius: 980
            )
        }
        .ignoresSafeArea()
    }
}

struct PaperGrain: View {
    var body: some View {
        Canvas { context, size in
            var rng = SeededRandom(seed: 0x5EED_C0DE)

            let speckCount = min(Int(size.width * size.height / 620), 5_000)
            for _ in 0..<speckCount {
                let x = rng.nextDouble() * size.width
                let y = rng.nextDouble() * size.height
                let r = 0.25 + rng.nextDouble() * 0.85
                let alpha = 0.012 + rng.nextDouble() * 0.035
                let rect = CGRect(x: x, y: y, width: r, height: r)
                context.fill(Path(ellipseIn: rect), with: .color(Color.ink.opacity(alpha)))
            }

            for _ in 0..<22 {
                var path = Path()
                let x = rng.nextDouble() * size.width
                let y = rng.nextDouble() * size.height
                let length = 30 + rng.nextDouble() * 110
                path.move(to: CGPoint(x: x, y: y))
                path.addCurve(
                    to: CGPoint(x: x + length, y: y + rng.nextDouble() * 18 - 9),
                    control1: CGPoint(x: x + length * 0.3, y: y - 8),
                    control2: CGPoint(x: x + length * 0.7, y: y + 8)
                )
                context.stroke(
                    path,
                    with: .color(Color.ink.opacity(0.018)),
                    lineWidth: 0.55
                )
            }
        }
        .allowsHitTesting(false)
    }
}

struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    mutating func nextDouble() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}

// MARK: - Surfaces & controls

struct PaperCardModifier: ViewModifier {
    var radius: CGFloat = 18
    var raised: Bool = true

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(raised ? Color.paperRaised : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.ink.opacity(0.085), lineWidth: 1)
            )
            .shadow(color: Color.shadow.opacity(0.075), radius: 20, x: 0, y: 10)
    }
}

extension View {
    func paperCard(radius: CGFloat = 18, raised: Bool = true) -> some View {
        modifier(PaperCardModifier(radius: radius, raised: raised))
    }
}

struct InkButtonStyle: ButtonStyle {
    var filled: Bool = true
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 13, weight: .semibold))
            .foregroundStyle(filled ? Color.paperRaised : Color.ink)
            .padding(.horizontal, compact ? 13 : 18)
            .padding(.vertical, compact ? 7 : 10)
            .background(
                Capsule(style: .continuous)
                    .fill(filled ? Color.ink : Color.clear)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.ink.opacity(filled ? 0 : 0.16), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.13), value: configuration.isPressed)
    }
}

struct AccentButtonStyle: ButtonStyle {
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 13, weight: .semibold))
            .foregroundStyle(Color.onAccent)
            .padding(.horizontal, compact ? 14 : 20)
            .padding(.vertical, compact ? 7 : 11)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.terracotta)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.terracottaDeep.opacity(0.22), radius: 10, x: 0, y: 5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.easeOut(duration: 0.13), value: configuration.isPressed)
    }
}

struct RoundIconButton: View {
    let systemName: String
    var size: CGFloat = 34
    var foreground: Color = .ink
    var background: Color = .paperRaised
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: size, height: size)
                .background(Circle().fill(background))
                .overlay(Circle().strokeBorder(Color.ink.opacity(0.10), lineWidth: 1))
                .scaleEffect(hovering ? 1.06 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.16), value: hovering)
    }
}

// MARK: - Formatting

enum TimeFormat {
    static func clock(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    static func short(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0m" }
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        if minutes > 0 { return "\(minutes)m" }
        return "\(total)s"
    }

    static func remaining(_ seconds: Double) -> String {
        "\(short(seconds)) left"
    }
}

enum StableHash {
    static func of(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }
}

struct FilmPalette {
    let top: Color
    let bottom: Color
    let accent: Color

    static let all: [FilmPalette] = [
        FilmPalette(top: Color(hex: 0x3B4A47), bottom: Color(hex: 0x141B1A), accent: Color(hex: 0xC58B63)),
        FilmPalette(top: Color(hex: 0x6B3F2E), bottom: Color(hex: 0x241510), accent: Color(hex: 0xD8A878)),
        FilmPalette(top: Color(hex: 0x3E4658), bottom: Color(hex: 0x161A22), accent: Color(hex: 0xA8B6C9)),
        FilmPalette(top: Color(hex: 0x6C5A35), bottom: Color(hex: 0x241E12), accent: Color(hex: 0xD9C08A)),
        FilmPalette(top: Color(hex: 0x5D4A52), bottom: Color(hex: 0x1F181C), accent: Color(hex: 0xC9A6B0)),
        FilmPalette(top: Color(hex: 0x3F5548), bottom: Color(hex: 0x141D18), accent: Color(hex: 0xA9C0A0))
    ]

    static func forTitle(_ title: String) -> FilmPalette {
        let index = Int(StableHash.of(title) % UInt64(all.count))
        return all[index]
    }
}
