import Foundation

struct Film: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var year: Int?
    var sourceFileName: String
    var mediaFileName: String
    var thumbnailFileName: String?
    var duration: Double
    var progress: Double = 0
    var lastWatched: Date?
    var addedAt: Date = Date()
    var fileSize: Int64 = 0
    var isWatched: Bool = false
    var aspectRatio: Double = 16.0 / 9.0

    var mediaURL: URL {
        LibraryPaths.media.appendingPathComponent(mediaFileName)
    }

    var thumbnailURL: URL? {
        guard let thumbnailFileName else { return nil }
        return LibraryPaths.thumbnails.appendingPathComponent(thumbnailFileName)
    }

    var hasProgress: Bool {
        guard !isWatched, progress > 0 else { return false }
        guard duration > 0 else { return progress > 15 }

        // Scale the "worth resuming" window to the film's length so short
        // films can appear in Keep Watching too. `updateProgress` uses the
        // same end threshold to decide when a film counts as watched.
        let startThreshold = min(15, duration * 0.05)
        let endThreshold = min(12, max(1, duration * 0.08))
        return progress > startThreshold && progress < duration - endThreshold
    }

    var progressFraction: Double {
        guard duration > 0 else { return 0 }
        return min(max(progress / duration, 0), 1)
    }

    var remaining: Double {
        max(duration - progress, 0)
    }

    var metaLine: String {
        var parts: [String] = []
        if let year { parts.append(String(year)) }
        parts.append(TimeFormat.short(duration))
        return parts.joined(separator: "  ·  ")
    }

    var sortTitle: String {
        title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}

struct LibrarySnapshot: Codable {
    var films: [Film] = []
    var pinnedFilmID: UUID?
}

struct PlaybackRequest: Identifiable {
    let id = UUID()
    let filmID: UUID
    let startAt: Double
}

struct ImportState: Equatable {
    var current: Int
    var total: Int
    var fileName: String

    var label: String {
        total > 1 ? "Adding \(current) of \(total)" : "Adding film"
    }
}

struct Toast: Identifiable, Equatable {
    enum Kind: Equatable {
        case success
        case info
        case error

        var icon: String {
            switch self {
            case .success: return "checkmark"
            case .info: return "info"
            case .error: return "exclamationmark"
            }
        }
    }

    let id = UUID()
    let message: String
    var kind: Kind = .success
}

enum LibraryPaths {
    static let root: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("tPlayer", isDirectory: true)
    }()

    static let media = root.appendingPathComponent("Media", isDirectory: true)
    static let thumbnails = root.appendingPathComponent("Thumbnails", isDirectory: true)
    static let libraryFile = root.appendingPathComponent("library.json")

    static func ensureDirectories() {
        let fm = FileManager.default
        try? fm.createDirectory(at: media, withIntermediateDirectories: true)
        try? fm.createDirectory(at: thumbnails, withIntermediateDirectories: true)
    }
}
