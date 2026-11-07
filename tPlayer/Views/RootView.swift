import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct RootView: View {
    @EnvironmentObject private var store: LibraryStore

    @State private var playback: PlaybackRequest?
    @State private var resumeCandidate: Film?
    @State private var showPinPicker = false
    @State private var isDropTargeted = false

    var body: some View {
        ZStack {
            PaperBackground()

            HomeView(
                onOpenFilm: requestOpen,
                onStartOver: startOver,
                onPinPicker: { showPinPicker = true }
            )
            .opacity(playback == nil ? 1 : 0)
            .allowsHitTesting(playback == nil)

            if let playback, let film = store.film(id: playback.filmID) {
                PlayerView(
                    film: film,
                    startAt: playback.startAt,
                    onClose: closePlayback
                )
                .id(playback.id)
                .transition(.opacity)
                .zIndex(2)
            }

            if let film = resumeCandidate {
                ResumePromptView(
                    film: film,
                    onResume: {
                        startPlayback(film, at: film.progress)
                    },
                    onStartOver: {
                        store.resetProgress(id: film.id)
                        startPlayback(film, at: 0)
                    },
                    onCancel: {
                        withAnimation(.easeOut(duration: 0.16)) {
                            resumeCandidate = nil
                        }
                    }
                )
                .zIndex(3)
            }

            if showPinPicker {
                PinPickerOverlay(
                    films: store.films,
                    pinnedID: store.pinnedFilmID,
                    onPin: { film in store.pin(film.id) },
                    onUnpin: { store.unpin() },
                    onClose: {
                        withAnimation(.easeOut(duration: 0.16)) {
                            showPinPicker = false
                        }
                    }
                )
                .zIndex(3)
            }

            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    if let importState = store.importState {
                        ImportOverlay(state: importState)
                    }
                    Spacer()
                    if let toast = store.toast {
                        ToastView(toast: toast, onDismiss: { store.dismissToast() })
                    }
                }
                .padding(24)
            }
            .zIndex(4)

            if isDropTargeted {
                DropOverlay()
                    .zIndex(5)
            }
        }
        .background(WindowConfigurator())
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
        .onOpenURL { url in
            store.importFilms(urls: [url])
        }
        .onReceive(NotificationCenter.default.publisher(for: OpenURLQueue.didReceive)) { _ in
            let urls = OpenURLQueue.drain()
            if !urls.isEmpty {
                store.importFilms(urls: urls)
            }
        }
        .onAppear {
            let urls = OpenURLQueue.drain()
            if !urls.isEmpty {
                store.importFilms(urls: urls)
            }
        }
        .animation(.easeOut(duration: 0.22), value: playback?.id)
        .animation(.easeOut(duration: 0.18), value: resumeCandidate?.id)
        .animation(.easeOut(duration: 0.18), value: showPinPicker)
        .animation(.easeOut(duration: 0.18), value: isDropTargeted)
        .onExitCommand {
            if resumeCandidate != nil {
                withAnimation(.easeOut(duration: 0.16)) { resumeCandidate = nil }
            } else if showPinPicker {
                withAnimation(.easeOut(duration: 0.16)) { showPinPicker = false }
            }
        }
    }

    private func requestOpen(_ film: Film) {
        guard let current = store.film(id: film.id) else { return }
        if current.hasProgress {
            withAnimation(.easeOut(duration: 0.18)) {
                resumeCandidate = current
            }
        } else {
            startPlayback(current, at: 0)
        }
    }

    private func startOver(_ film: Film) {
        store.resetProgress(id: film.id)
        startPlayback(film, at: 0)
    }

    private func startPlayback(_ film: Film, at seconds: Double) {
        withAnimation(.easeOut(duration: 0.18)) {
            resumeCandidate = nil
            playback = PlaybackRequest(filmID: film.id, startAt: seconds)
        }
    }

    private func closePlayback() {
        withAnimation(.easeOut(duration: 0.22)) {
            playback = nil
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        let lock = NSLock()
        var urls: [URL] = []

        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }

                var url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let nsURL = item as? NSURL {
                    url = nsURL as URL
                } else if let direct = item as? URL {
                    url = direct
                }

                if let url {
                    lock.lock()
                    urls.append(url)
                    lock.unlock()
                }
            }
        }

        group.notify(queue: .main) {
            store.importFilms(urls: urls)
        }

        return true
    }
}
