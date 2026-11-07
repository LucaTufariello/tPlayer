import SwiftUI
import AppKit

struct FilmArtwork: View {
    let film: Film
    var alignment: Alignment = .center

    var body: some View {
        GeometryReader { proxy in
            Group {
                if let image = ThumbnailCache.shared.image(for: film) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    FilmPlaceholder(title: film.title)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: alignment)
            .clipped()
        }
    }
}

struct FilmPlaceholder: View {
    let title: String

    private var palette: FilmPalette { FilmPalette.forTitle(title) }
    private var initial: String {
        String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased()
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [palette.top, palette.bottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(palette.accent.opacity(0.22))
                .frame(width: 260, height: 260)
                .blur(radius: 55)
                .offset(x: 80, y: -60)

            Circle()
                .stroke(palette.accent.opacity(0.18), lineWidth: 1)
                .frame(width: 180, height: 180)
                .offset(x: -60, y: 50)

            Text(initial)
                .font(.display(96, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.13))
                .offset(x: -2, y: 4)

            VStack {
                Spacer()
                HStack {
                    Text("tPlayer")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.8)
                        .foregroundStyle(Color.white.opacity(0.34))
                    Spacer()
                }
                .padding(14)
            }
        }
    }
}

struct ThinProgressBar: View {
    var progress: Double
    var track: Color = Color.white.opacity(0.22)
    var fill: Color = .terracotta
    var height: CGFloat = 3

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(fill)
                    .frame(width: max(0, min(proxy.size.width, proxy.size.width * progress)))
            }
        }
        .frame(height: height)
    }
}

struct BadgePill: View {
    let text: String
    var icon: String?
    var foreground: Color = .ink
    var background: Color = Color.paperRaised.opacity(0.92)

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 8.5, weight: .bold))
            }
            Text(text.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.1)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(background))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
    }
}

struct SectionHeader: View {
    let title: String
    var trailing: AnyView?

    init(_ title: String) {
        self.title = title
        self.trailing = nil
    }

    init<T: View>(_ title: String, @ViewBuilder trailing: () -> T) {
        self.title = title
        self.trailing = AnyView(trailing())
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Eyebrow(text: title)
            Rectangle()
                .fill(Color.ink.opacity(0.09))
                .frame(height: 1)
            if let trailing {
                trailing
            }
        }
    }
}
