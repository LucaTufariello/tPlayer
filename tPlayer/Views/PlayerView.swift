import SwiftUI
import AVKit
import AVFoundation
import Combine
import AppKit

struct PlayerView: View {
    @EnvironmentObject private var store: LibraryStore
    @Environment(\.scenePhase) private var scenePhase

    let film: Film
    let startAt: Double
    let onClose: () -> Void

    @StateObject private var model: PlayerModel
    @State private var controlsVisible = true
    @State private var hideTask: Task<Void, Never>?
    @State private var noteTask: Task<Void, Never>?
    @State private var lastSaved: Double
    @State private var showResumeNote: Bool
    @State private var wasPlayingBeforeScrub = false
    @State private var isFullScreen = false
    @FocusState private var focused: Bool

    init(film: Film, startAt: Double, onClose: @escaping () -> Void) {
        self.film = film
        self.startAt = startAt
        self.onClose = onClose
        _model = StateObject(
            wrappedValue: PlayerModel(
                url: film.mediaURL,
                startAt: startAt,
                knownDuration: film.duration
            )
        )
        _lastSaved = State(initialValue: startAt)
        _showResumeNote = State(initialValue: startAt > 15)
    }

    var body: some View {
        ZStack {
            Color.playerBg
                .ignoresSafeArea()

            PlayerLayerView(player: model.player)
                .ignoresSafeArea()

            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    TapGesture(count: 2)
                        .onEnded { toggleFullscreen() }
                        .exclusively(
                            before: TapGesture(count: 1)
                                .onEnded {
                                    model.togglePlay()
                                    bumpControls()
                                }
                        )
                )

            if model.isBuffering && !model.didEnd {
                ProgressView()
                    .controlSize(.large)
                    .tint(Color.paperRaised)
            }

            if !model.isPlaying && !model.didEnd && !model.isBuffering {
                Button {
                    model.togglePlay()
                    bumpControls()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(Color.ink)
                        .offset(x: 2)
                        .frame(width: 78, height: 78)
                        .background(Circle().fill(Color.paperRaised.opacity(0.94)))
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.28), radius: 24, x: 0, y: 10)
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
                .zIndex(1)
            }

            controls

            if showResumeNote {
                VStack {
                    Text("Resumed from \(TimeFormat.clock(startAt))")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Color.playerPaper.opacity(0.82))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.white.opacity(0.10)))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                        .padding(.top, 20)
                    Spacer()
                }
                .transition(.opacity)
                .allowsHitTesting(false)
            }

            if model.didEnd {
                EndOfFilmView(
                    film: film,
                    onReplay: {
                        store.resetProgress(id: film.id)
                        model.replay()
                        lastSaved = 0
                        bumpControls()
                    },
                    onClose: close
                )
                .zIndex(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.playerBg)
        .onContinuousHover { phase in
            if case .active = phase {
                bumpControls()
            }
        }
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear {
            focused = true
            isFullScreen = NSApp.keyWindow?.styleMask.contains(.fullScreen) ?? false
            bumpControls()

            if showResumeNote {
                noteTask = Task {
                    try? await Task.sleep(nanoseconds: 3_200_000_000)
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.3)) {
                        showResumeNote = false
                    }
                }
            }
        }
        .onDisappear {
            hideTask?.cancel()
            noteTask?.cancel()
            saveProgress(force: true)
            model.teardown()
        }
        .onChange(of: model.currentTime) { _, time in
            if time - lastSaved >= 5 {
                saveProgress()
            }
        }
        .onChange(of: model.isPlaying) { _, playing in
            if playing {
                bumpControls()
            } else {
                hideTask?.cancel()
                withAnimation(.easeOut(duration: 0.16)) {
                    controlsVisible = true
                }
                saveProgress(force: true)
            }
        }
        .onChange(of: model.didEnd) { _, ended in
            guard ended else { return }
            hideTask?.cancel()
            withAnimation(.easeOut(duration: 0.2)) {
                controlsVisible = true
            }
            store.markWatched(id: film.id)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                saveProgress(force: true)
            }
        }
        .onKeyPress(.space) {
            model.togglePlay()
            bumpControls()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            model.seek(by: -10)
            bumpControls()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            model.seek(by: 10)
            bumpControls()
            return .handled
        }
        .onKeyPress(.upArrow) {
            model.setVolume(min(1, model.volume + 0.05))
            bumpControls()
            return .handled
        }
        .onKeyPress(.downArrow) {
            model.setVolume(max(0, model.volume - 0.05))
            bumpControls()
            return .handled
        }
        .onKeyPress(KeyEquivalent("f")) {
            toggleFullscreen()
            return .handled
        }
        .onKeyPress(.escape) {
            close()
            return .handled
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in
            isFullScreen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
            isFullScreen = false
        }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            bottomBar
        }
        .opacity(controlsVisible || !model.isPlaying || model.didEnd ? 1 : 0)
        .allowsHitTesting(controlsVisible || !model.isPlaying || model.didEnd)
        .animation(.easeOut(duration: 0.2), value: controlsVisible)
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button(action: close) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.playerPaper)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white.opacity(0.10)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("Back to library  (esc)")

            VStack(alignment: .leading, spacing: 2) {
                Text(film.title)
                    .font(.display(18, weight: .medium))
                    .foregroundStyle(Color.playerPaper)
                    .lineLimit(1)

                Text("NOW PLAYING")
                    .font(.system(size: 8.5, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(Color.playerPaper.opacity(0.42))
            }

            Spacer()

            if store.pinnedFilmID == film.id {
                BadgePill(
                    text: "Up next",
                    icon: "pin.fill",
                    foreground: Color.playerPaper,
                    background: Color.white.opacity(0.10)
                )
            }

            Menu {
                if store.pinnedFilmID == film.id {
                    Button("Unpin from Up next") { store.unpin() }
                } else {
                    Button("Pin as next watch") { store.pin(film.id) }
                }
                Button("Reveal in Finder") { store.revealInFinder(id: film.id) }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.playerPaper)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white.opacity(0.10)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.leading, isFullScreen ? 24 : 92)
        .padding(.trailing, 24)
        .padding(.top, 14)
        .padding(.bottom, 26)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.58), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var bottomBar: some View {
        VStack(spacing: 14) {
            Scrubber(
                duration: model.duration,
                currentTime: model.currentTime,
                onScrubStart: {
                    wasPlayingBeforeScrub = model.isPlaying
                    model.pause()
                    hideTask?.cancel()
                    withAnimation(.easeOut(duration: 0.16)) {
                        controlsVisible = true
                    }
                },
                onSeek: { time in
                    model.seek(to: time)
                    lastSaved = time
                },
                onScrubEnd: {
                    if wasPlayingBeforeScrub {
                        model.play()
                    }
                    bumpControls()
                }
            )

            HStack(spacing: 16) {
                Button {
                    model.togglePlay()
                    bumpControls()
                } label: {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.ink)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.playerPaper))
                }
                .buttonStyle(.plain)
                .help(model.isPlaying ? "Pause  (space)" : "Play  (space)")

                Button {
                    model.seek(by: -10)
                    bumpControls()
                } label: {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color.playerPaper.opacity(0.82))
                }
                .buttonStyle(.plain)
                .help("Back 10 seconds  (←)")

                Button {
                    model.seek(by: 10)
                    bumpControls()
                } label: {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color.playerPaper.opacity(0.82))
                }
                .buttonStyle(.plain)
                .help("Forward 10 seconds  (→)")

                Text("\(TimeFormat.clock(model.currentTime)) / \(TimeFormat.clock(model.duration))")
                    .font(.mono(11))
                    .foregroundStyle(Color.playerPaper.opacity(0.62))
                    .padding(.leading, 2)

                Spacer()

                speedMenu

                HStack(spacing: 7) {
                    Button {
                        model.toggleMute()
                    } label: {
                        Image(systemName: volumeIcon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.playerPaper.opacity(0.82))
                            .frame(width: 22)
                    }
                    .buttonStyle(.plain)
                    .help(model.isMuted ? "Unmute" : "Mute")

                    Slider(
                        value: Binding(
                            get: { model.volume },
                            set: { model.setVolume($0) }
                        ),
                        in: 0...1
                    )
                    .frame(width: 72)
                    .tint(Color.terracotta)
                    .controlSize(.mini)
                }

                Button(action: toggleFullscreen) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.playerPaper.opacity(0.82))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Toggle full screen  (f)")
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 50)
        .padding(.bottom, 24)
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.76)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var speedMenu: some View {
        Menu {
            ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                Button {
                    model.setRate(speed)
                } label: {
                    if abs(model.rate - speed) < 0.001 {
                        Label(rateLabel(speed), systemImage: "checkmark")
                    } else {
                        Text(rateLabel(speed))
                    }
                }
            }
        } label: {
            Text(rateLabel(model.rate))
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Color.playerPaper.opacity(0.78))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(0.09)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Playback speed")
    }

    private var volumeIcon: String {
        if model.isMuted || model.volume <= 0.001 { return "speaker.slash.fill" }
        if model.volume < 0.34 { return "speaker.wave.1.fill" }
        if model.volume < 0.67 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    private func rateLabel(_ rate: Double) -> String {
        if abs(rate - rate.rounded()) < 0.001 {
            return "\(Int(rate.rounded()))×"
        }
        return String(format: "%.2g×", rate)
    }

    // MARK: - Actions

    private func bumpControls() {
        withAnimation(.easeOut(duration: 0.16)) {
            controlsVisible = true
        }
        hideTask?.cancel()

        guard model.isPlaying, !model.didEnd else { return }

        hideTask = Task {
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.24)) {
                controlsVisible = false
            }
            NSCursor.setHiddenUntilMouseMoves(true)
        }
    }

    private func saveProgress(force: Bool = false) {
        guard model.duration > 0 else { return }
        let time = min(max(model.currentTime, 0), model.duration)
        if !force, abs(time - lastSaved) < 1 { return }
        store.updateProgress(id: film.id, seconds: time, duration: model.duration)
        lastSaved = time
    }

    private func close() {
        saveProgress(force: true)
        model.pause()
        exitFullscreenIfNeeded()
        onClose()
    }

    private func toggleFullscreen() {
        NSApp.keyWindow?.toggleFullScreen(nil)
    }

    private func exitFullscreenIfNeeded() {
        if let window = NSApp.keyWindow, window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }
    }
}

// MARK: - Scrubber

private struct Scrubber: View {
    let duration: Double
    let currentTime: Double
    let onScrubStart: () -> Void
    let onSeek: (Double) -> Void
    let onScrubEnd: () -> Void

    @State private var dragFraction: Double?
    @State private var hoverFraction: Double?
    @State private var dragging = false

    private var fraction: Double {
        if let dragFraction { return dragFraction }
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let thumbX = width * fraction

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 4)

                Capsule()
                    .fill(Color.terracotta)
                    .frame(width: max(0, thumbX), height: 4)

                Circle()
                    .fill(Color.playerPaper)
                    .frame(width: 11, height: 11)
                    .shadow(color: Color.black.opacity(0.22), radius: 4, x: 0, y: 1)
                    .offset(x: max(0, min(width - 11, thumbX - 5.5)))
                    .opacity(dragging || hoverFraction != nil ? 1 : 0)
                    .animation(.easeOut(duration: 0.12), value: dragging)
            }
            .frame(height: 24)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !dragging {
                            dragging = true
                            onScrubStart()
                        }
                        dragFraction = min(max(value.location.x / width, 0), 1)
                        hoverFraction = dragFraction
                    }
                    .onEnded { value in
                        let target = min(max(value.location.x / width, 0), 1)
                        dragFraction = nil
                        dragging = false
                        onSeek(duration * target)
                        onScrubEnd()
                    }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let point):
                    hoverFraction = min(max(point.x / width, 0), 1)
                case .ended:
                    hoverFraction = nil
                }
            }
            .overlay(alignment: .topLeading) {
                if let hoverFraction, duration > 0 {
                    Text(TimeFormat.clock(duration * hoverFraction))
                        .font(.mono(9.5))
                        .foregroundStyle(Color.playerPaper.opacity(0.88))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.72)))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                        .offset(
                            x: min(max(width * hoverFraction - 30, 0), width - 60),
                            y: -22
                        )
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(height: 24)
        .accessibilityElement()
        .accessibilityLabel("Playback position")
        .accessibilityValue("\(TimeFormat.clock(currentTime)) of \(TimeFormat.clock(duration))")
    }
}

// MARK: - Video surface

private struct PlayerLayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        view.videoGravity = .resizeAspect
        view.allowsPictureInPicturePlayback = true
        view.showsFullScreenToggleButton = false
        view.showsFrameSteppingButtons = false
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }
}

// MARK: - End card

private struct EndOfFilmView: View {
    let film: Film
    let onReplay: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.68)
                .ignoresSafeArea()

            VStack(spacing: 15) {
                Eyebrow(text: "That’s a wrap", color: .terracotta)

                Text(film.title)
                    .font(.display(36, weight: .regular))
                    .foregroundStyle(Color.playerPaper)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text("Marked as watched. It will be waiting in your library.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.playerPaper.opacity(0.58))

                HStack(spacing: 12) {
                    Button(action: onReplay) {
                        Label("Watch again", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(AccentButtonStyle())

                    Button(action: onClose) {
                        Text("Back to library")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.playerPaper)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.white.opacity(0.10)))
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 6)
            }
            .padding(40)
        }
        .transition(.opacity)
    }
}

// MARK: - Playback model

@MainActor
final class PlayerModel: ObservableObject {
    let player: AVPlayer

    @Published var isPlaying = false
    @Published var isBuffering = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var didEnd = false
    @Published var volume: Double = 1
    @Published var isMuted = false
    @Published var rate: Double = 1

    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()
    private var tornDown = false

    init(url: URL, startAt: Double, knownDuration: Double) {
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player
        self.duration = knownDuration

        player.actionAtItemEnd = .pause
        player.volume = 1
        player.defaultRate = 1

        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let seconds = time.seconds
            if seconds.isFinite {
                self.currentTime = max(0, seconds)
            }
            if let itemDuration = self.player.currentItem?.duration.seconds,
               itemDuration.isFinite,
               itemDuration > 0 {
                self.duration = itemDuration
            }
        }

        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.isPlaying = status == .playing
                self?.isBuffering = status == .waitingToPlayAtSpecifiedRate
            }
            .store(in: &cancellables)

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.didEnd = true
            self?.isPlaying = false
        }

        if startAt > 1 {
            player.seek(
                to: CMTime(seconds: startAt, preferredTimescale: 600),
                toleranceBefore: .zero,
                toleranceAfter: .zero
            ) { [weak player] _ in
                player?.play()
            }
        } else {
            player.play()
        }
    }

    func togglePlay() {
        if didEnd {
            replay()
            return
        }
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
            player.rate = Float(rate)
        }
    }

    func play() {
        if didEnd {
            didEnd = false
            seek(to: 0)
        }
        player.play()
        player.rate = Float(rate)
    }

    func pause() {
        player.pause()
    }

    func seek(to seconds: Double) {
        let upper = duration > 0 ? duration : seconds
        let clamped = min(max(seconds, 0), upper)
        player.seek(
            to: CMTime(seconds: clamped, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        currentTime = clamped
        if didEnd, clamped < upper - 1 {
            didEnd = false
        }
    }

    func seek(by delta: Double) {
        seek(to: currentTime + delta)
    }

    func setRate(_ newRate: Double) {
        rate = newRate
        player.defaultRate = Float(newRate)
        if player.timeControlStatus == .playing {
            player.rate = Float(newRate)
        }
    }

    func setVolume(_ newVolume: Double) {
        let clamped = min(max(newVolume, 0), 1)
        volume = clamped
        player.volume = Float(clamped)
        if clamped > 0 {
            isMuted = false
            player.isMuted = false
        }
    }

    func toggleMute() {
        isMuted.toggle()
        player.isMuted = isMuted
    }

    func replay() {
        didEnd = false
        seek(to: 0)
        player.play()
        player.rate = Float(rate)
    }

    func teardown() {
        guard !tornDown else { return }
        tornDown = true

        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        cancellables.removeAll()
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }
}
