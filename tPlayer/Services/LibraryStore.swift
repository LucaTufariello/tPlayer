import Foundation
import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var films: [Film] = []
    @Published private(set) var pinnedFilmID: UUID?
    @Published private(set) var importState: ImportState?
    @Published var toast: Toast?

    private var toastTask: Task<Void, Never>?
    private var pendingImportURLs: [URL] = []
    private var isDrainingImports = false

    init() {
        LibraryPaths.ensureDirectories()
        load()
    }

    init(previewFilms: [Film], pinnedFilmID: UUID? = nil) {
        LibraryPaths.ensureDirectories()
        self.films = previewFilms
        self.pinnedFilmID = pinnedFilmID
    }

    // MARK: - Derived

    var pinnedFilm: Film? {
        guard let pinnedFilmID else { return nil }
        return films.first { $0.id == pinnedFilmID }
    }

    var continueFilms: [Film] {
        films
            .filter(\.hasProgress)
            .sorted { ($0.lastWatched ?? .distantPast) > ($1.lastWatched ?? .distantPast) }
    }

    var isImporting: Bool {
        importState != nil
    }

    func film(id: UUID) -> Film? {
        films.first { $0.id == id }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: LibraryPaths.libraryFile) else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let snapshot = try? decoder.decode(LibrarySnapshot.self, from: data) else { return }

        let fm = FileManager.default
        let existing = snapshot.films.filter { fm.fileExists(atPath: $0.mediaURL.path) }
        films = existing

        if let pinned = snapshot.pinnedFilmID, existing.contains(where: { $0.id == pinned }) {
            pinnedFilmID = pinned
        } else {
            pinnedFilmID = nil
        }

        if existing.count != snapshot.films.count {
            save()
        }
    }

    private func save() {
        let snapshot = LibrarySnapshot(films: films, pinnedFilmID: pinnedFilmID)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(snapshot)
            try data.write(to: LibraryPaths.libraryFile, options: .atomic)
        } catch {
            print("tPlayer: could not save library — \(error)")
        }
    }

    // MARK: - Import

    func chooseAndImport() {
        let panel = NSOpenPanel()
        panel.title = "Add films to tPlayer"
        panel.message = "Choose MP4, M4V, or MOV files to keep in your library."
        panel.prompt = "Import"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.canCreateDirectories = false
        panel.allowedContentTypes = [
            .mpeg4Movie,
            .quickTimeMovie,
            UTType(filenameExtension: "m4v")
        ].compactMap { $0 }

        guard panel.runModal() == .OK else { return }
        importFilms(urls: panel.urls)
    }

    func importFilms(urls: [URL]) {
        let supported = urls.filter(FilmImporter.isSupported)
        guard !supported.isEmpty else {
            showToast("Choose an MP4, M4V, or MOV file.", kind: .error)
            return
        }

        var seen = Set(pendingImportURLs.map { $0.standardizedFileURL.path })
        let candidates = supported.filter { url in
            let key = url.standardizedFileURL.path
            guard seen.insert(key).inserted else { return false }
            return !isDuplicate(url)
        }

        guard !candidates.isEmpty else {
            if importState == nil {
                showToast("That film is already in your library.", kind: .info)
            }
            return
        }

        pendingImportURLs.append(contentsOf: candidates)

        // A single import task drains the queue, so a multi-file open or drop
        // that arrives as several calls still imports everything.
        guard !isDrainingImports else { return }
        isDrainingImports = true
        Task { @MainActor in
            await drainImportQueue()
            isDrainingImports = false
        }
    }

    private func drainImportQueue() async {
        var added: [Film] = []
        var failures: [String] = []
        var processed = 0

        while !pendingImportURLs.isEmpty {
            let url = pendingImportURLs.removeFirst()
            processed += 1

            importState = ImportState(
                current: processed,
                total: processed + pendingImportURLs.count,
                fileName: url.lastPathComponent
            )

            do {
                let film = try await FilmImporter.importFilm(from: url)
                films.append(film)
                added.append(film)
                save()
            } catch {
                failures.append(error.localizedDescription)
            }
        }

        importState = nil

        if !added.isEmpty {
            let message: String
            if added.count == 1 {
                message = "Added “\(added[0].title)” to your library."
            } else {
                message = "Added \(added.count) films to your library."
            }
            showToast(message, kind: .success)
        }

        if !failures.isEmpty {
            let message = failures.count == 1
                ? failures[0]
                : "\(failures.count) files couldn’t be imported."
            showToast(message, kind: .error)
        }
    }

    private func isDuplicate(_ url: URL) -> Bool {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes?[.size] as? NSNumber)?.int64Value ?? -1
        return films.contains { film in
            film.sourceFileName == url.lastPathComponent
                && (size < 0 || film.fileSize == size)
        }
    }

    // MARK: - Pinning

    func pin(_ id: UUID) {
        guard films.contains(where: { $0.id == id }) else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            pinnedFilmID = id
        }
        save()
    }

    func unpin() {
        withAnimation(.easeOut(duration: 0.2)) {
            pinnedFilmID = nil
        }
        save()
    }

    func togglePin(_ id: UUID) {
        if pinnedFilmID == id {
            unpin()
        } else {
            pin(id)
        }
    }

    // MARK: - Playback state

    func updateProgress(id: UUID, seconds: Double, duration: Double) {
        guard let index = films.firstIndex(where: { $0.id == id }) else { return }
        var film = films[index]

        let safeDuration = duration.isFinite && duration > 0 ? duration : film.duration
        let safeSeconds = seconds.isFinite ? max(seconds, 0) : 0

        let endThreshold = min(12, max(1, safeDuration * 0.08))
        if safeDuration > 0, safeSeconds >= safeDuration - endThreshold {
            film.progress = 0
            film.isWatched = true
            film.lastWatched = Date()
            if pinnedFilmID == id {
                pinnedFilmID = nil
            }
        } else {
            film.progress = safeSeconds
            film.isWatched = false
            film.lastWatched = Date()
        }

        films[index] = film
        save()
    }

    func resetProgress(id: UUID) {
        guard let index = films.firstIndex(where: { $0.id == id }) else { return }
        films[index].progress = 0
        films[index].isWatched = false
        films[index].lastWatched = nil
        save()
    }

    func markWatched(id: UUID) {
        guard let index = films.firstIndex(where: { $0.id == id }) else { return }
        films[index].progress = 0
        films[index].isWatched = true
        films[index].lastWatched = Date()
        if pinnedFilmID == id {
            pinnedFilmID = nil
        }
        save()
    }

    func markUnwatched(id: UUID) {
        guard let index = films.firstIndex(where: { $0.id == id }) else { return }
        films[index].progress = 0
        films[index].isWatched = false
        films[index].lastWatched = nil
        save()
    }

    // MARK: - Library editing

    func rename(id: UUID, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = films.firstIndex(where: { $0.id == id }) else { return }
        films[index].title = trimmed
        save()
    }

    func remove(id: UUID) {
        guard let film = films.first(where: { $0.id == id }) else { return }

        ThumbnailCache.shared.invalidate(for: film)
        try? FileManager.default.removeItem(at: film.mediaURL)
        if let thumbnailURL = film.thumbnailURL {
            try? FileManager.default.removeItem(at: thumbnailURL)
        }

        films.removeAll { $0.id == id }
        if pinnedFilmID == id {
            pinnedFilmID = nil
        }
        save()
        showToast("Removed “\(film.title)” from your library.", kind: .info)
    }

    func revealInFinder(id: UUID) {
        guard let film = film(id: id) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([film.mediaURL])
    }

    // MARK: - Toast

    func showToast(_ message: String, kind: Toast.Kind = .success) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            toast = Toast(message: message, kind: kind)
        }

        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.22)) {
                self?.toast = nil
            }
        }
    }

    func dismissToast() {
        toastTask?.cancel()
        withAnimation(.easeOut(duration: 0.18)) {
            toast = nil
        }
    }
}
