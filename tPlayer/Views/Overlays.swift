import SwiftUI
import AppKit

// MARK: - Resume

struct ResumePromptView: View {
    let film: Film
    let onResume: () -> Void
    let onStartOver: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.scrim
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    FilmArtwork(film: film)
                        .frame(height: 224)
                        .clipped()

                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.42)],
                        startPoint: .center,
                        endPoint: .bottom
                    )

                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(Color.playerPaper)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.black.opacity(0.38)))
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .padding(14)
                    .help("Cancel")

                    VStack(alignment: .leading, spacing: 5) {
                        Text(film.title)
                            .font(.display(22, weight: .medium))
                            .foregroundStyle(Color.playerPaper)
                            .lineLimit(1)
                            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 3)
                        Text(film.metaLine)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(Color.playerPaper.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(22)
                }
                .frame(height: 224)

                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        Eyebrow(text: "Continue watching", color: .terracotta)
                        Text("Pick up where you left off?")
                            .font(.display(29, weight: .regular))
                            .foregroundStyle(Color.ink)
                        Text("You stopped at \(TimeFormat.clock(film.progress)) — \(TimeFormat.remaining(film.remaining)) to go.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Color.inkSecondary)
                    }

                    VStack(spacing: 7) {
                        ThinProgressBar(
                            progress: film.progressFraction,
                            track: Color.ink.opacity(0.10),
                            fill: Color.terracotta,
                            height: 5
                        )
                        HStack {
                            Text(TimeFormat.clock(film.progress))
                            Spacer()
                            Text(TimeFormat.clock(film.duration))
                        }
                        .font(.mono(10))
                        .foregroundStyle(Color.inkTertiary)
                    }

                    HStack(spacing: 12) {
                        Button(action: onResume) {
                            Label("Resume", systemImage: "play.fill")
                        }
                        .buttonStyle(AccentButtonStyle())
                        .keyboardShortcut(.defaultAction)

                        Button(action: onStartOver) {
                            Label("Start over", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(InkButtonStyle(filled: false))

                        Spacer()

                        Button("Cancel", action: onCancel)
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
                .padding(26)
            }
            .frame(width: 566)
            .background(Color.paperRaised)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.ink.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: Color.shadow.opacity(0.28), radius: 46, x: 0, y: 24)
            .padding(36)
        }
        .transition(.opacity)
        .onExitCommand(perform: onCancel)
    }
}

// MARK: - Pin picker

struct PinPickerOverlay: View {
    let films: [Film]
    let pinnedID: UUID?
    let onPin: (Film) -> Void
    let onUnpin: () -> Void
    let onClose: () -> Void

    @State private var searchText = ""

    private var filtered: [Film] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return films }
        return films.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var pickerHeight: CGFloat {
        let rows = ceil(Double(filtered.count) / 2.0)
        return min(600, 330 + CGFloat(rows) * 78)
    }

    var body: some View {
        ZStack {
            Color.scrim
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 7) {
                        Eyebrow(text: "Up next", color: .terracotta)
                        Text("Pin your next watch")
                            .font(.display(30, weight: .regular))
                            .foregroundStyle(Color.ink)
                        Text("One film, waiting at the top of your library.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Color.inkSecondary)
                    }

                    Spacer()

                    if pinnedID != nil {
                        Button("Unpin current", action: onUnpin)
                            .buttonStyle(InkButtonStyle(compact: true))
                    }

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(Color.inkSecondary)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.paperDeep.opacity(0.7)))
                    }
                    .buttonStyle(.plain)
                    .help("Close")
                }
                .padding(24)

                pickerSearch
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                Rectangle()
                    .fill(Color.ink.opacity(0.08))
                    .frame(height: 1)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(filtered) { film in
                            PinPickerRow(
                                film: film,
                                isPinned: film.id == pinnedID,
                                onSelect: {
                                    onPin(film)
                                    onClose()
                                }
                            )
                        }
                    }
                    .padding(20)
                }

                HStack(spacing: 7) {
                    Image(systemName: "pin")
                        .font(.system(size: 9.5, weight: .semibold))
                    Text("Your pinned film appears in the “Up next” spot on the home page.")
                        .font(.system(size: 10.5))
                }
                .foregroundStyle(Color.inkTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.paperDeep.opacity(0.35))
            }
            .frame(width: 760, height: pickerHeight)
            .background(Color.paperRaised)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.ink.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: Color.shadow.opacity(0.28), radius: 46, x: 0, y: 24)
            .padding(36)
        }
        .transition(.opacity)
        .onExitCommand(perform: onClose)
    }

    private var pickerSearch: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Color.inkTertiary)
            TextField("Find a film", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .tint(Color.terracotta)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.inkTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(Capsule().fill(Color.paper))
        .overlay(Capsule().strokeBorder(Color.ink.opacity(0.10), lineWidth: 1))
    }
}

private struct PinPickerRow: View {
    let film: Film
    let isPinned: Bool
    let onSelect: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                FilmArtwork(film: film)
                    .frame(width: 106, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(film.title)
                        .font(.display(15, weight: .medium))
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                    Text(film.metaLine)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.inkSecondary)
                    if film.hasProgress {
                        Text("\(TimeFormat.clock(film.progress)) in")
                            .font(.mono(9.5))
                            .foregroundStyle(Color.terracotta)
                    }
                }

                Spacer(minLength: 4)

                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isPinned ? Color.terracotta : Color.inkTertiary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(isPinned ? Color.terracotta.opacity(0.12) : Color.clear))
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(hovering ? Color.paper : Color.paper.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(
                        isPinned ? Color.terracotta.opacity(0.35) : Color.ink.opacity(0.075),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

// MARK: - Status overlays

struct ToastView: View {
    let toast: Toast
    let onDismiss: () -> Void

    private var tint: Color {
        switch toast.kind {
        case .success: return .sage
        case .info: return .inkSecondary
        case .error: return .terracotta
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 24, height: 24)
                Image(systemName: toast.kind.icon)
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(tint)
            }

            Text(toast.message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(Color.inkTertiary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.paperRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.ink.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.shadow.opacity(0.16), radius: 18, x: 0, y: 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

struct ImportOverlay: View {
    let state: ImportState

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
                .tint(Color.terracotta)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.label)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Color.ink)
                Text(state.fileName)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 220, alignment: .leading)
            }

            Text("\(state.current)/\(state.total)")
                .font(.mono(10))
                .foregroundStyle(Color.inkTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.paperRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.ink.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.shadow.opacity(0.16), radius: 18, x: 0, y: 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

struct DropOverlay: View {
    var body: some View {
        ZStack {
            Color.paper.opacity(0.97)

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(
                    Color.terracotta,
                    style: StrokeStyle(lineWidth: 2, dash: [10, 8])
                )
                .padding(26)

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.terracotta.opacity(0.12))
                        .frame(width: 66, height: 66)
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(Color.terracotta)
                }

                Text("Drop to add to your library")
                    .font(.display(32, weight: .regular))
                    .foregroundStyle(Color.ink)

                Text("MP4  ·  M4V  ·  MOV")
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(Color.inkTertiary)
            }
        }
        .ignoresSafeArea()
        .transition(.opacity)
        .allowsHitTesting(false)
    }
}
