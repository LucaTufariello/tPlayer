import Foundation
import AVFoundation
import AppKit

enum FilmImporterError: LocalizedError {
    case unsupportedFile(String)
    case noVideoTrack
    case copyFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedFile(let name):
            return "\(name) isn't an MP4, M4V, or MOV film."
        case .noVideoTrack:
            return "That file doesn't contain a video track."
        case .copyFailed:
            return "The film couldn't be copied into your library."
        }
    }
}

enum FilmImporter {
    static let allowedExtensions: Set<String> = ["mp4", "m4v", "mov"]

    static func isSupported(_ url: URL) -> Bool {
        allowedExtensions.contains(url.pathExtension.lowercased())
    }

    static func importFilm(from sourceURL: URL) async throws -> Film {
        guard isSupported(sourceURL) else {
            throw FilmImporterError.unsupportedFile(sourceURL.lastPathComponent)
        }

        LibraryPaths.ensureDirectories()

        let id = UUID()
        let ext = sourceURL.pathExtension.lowercased()
        let mediaName = "\(id.uuidString).\(ext.isEmpty ? "mp4" : ext)"
        let destination = LibraryPaths.media.appendingPathComponent(mediaName)

        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess { sourceURL.stopAccessingSecurityScopedResource() }
        }

        do {
            try await Task.detached(priority: .userInitiated) {
                let fm = FileManager.default
                if fm.fileExists(atPath: destination.path) {
                    try fm.removeItem(at: destination)
                }
                try fm.copyItem(at: sourceURL, to: destination)
            }.value
        } catch {
            throw FilmImporterError.copyFailed
        }

        do {
            let asset = AVURLAsset(url: destination)
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let videoTrack = tracks.first else {
                try? FileManager.default.removeItem(at: destination)
                throw FilmImporterError.noVideoTrack
            }

            let duration = (try? await asset.load(.duration).seconds) ?? 0
            let naturalSize = (try? await videoTrack.load(.naturalSize)) ?? CGSize(width: 16, height: 9)
            let transform = (try? await videoTrack.load(.preferredTransform)) ?? .identity
            let transformed = naturalSize.applying(transform)
            let width = abs(transformed.width)
            let height = abs(transformed.height)
            let aspect = height > 0 ? width / height : 16.0 / 9.0

            let thumbnailName = "\(id.uuidString).jpg"
            let thumbnailURL = LibraryPaths.thumbnails.appendingPathComponent(thumbnailName)
            let hasThumbnail = await ThumbnailGenerator.generate(
                asset: asset,
                duration: duration,
                to: thumbnailURL
            )

            let attributes = try? FileManager.default.attributesOfItem(atPath: destination.path)
            let fileSize = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
            let parsed = TitleParser.parse(sourceURL.lastPathComponent)

            return Film(
                id: id,
                title: parsed.title,
                year: parsed.year,
                sourceFileName: sourceURL.lastPathComponent,
                mediaFileName: mediaName,
                thumbnailFileName: hasThumbnail ? thumbnailName : nil,
                duration: duration.isFinite ? max(duration, 0) : 0,
                fileSize: fileSize,
                aspectRatio: aspect.isFinite && aspect > 0 ? aspect : 16.0 / 9.0
            )
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }
}

enum ThumbnailGenerator {
    static func generate(asset: AVAsset, duration: Double, to url: URL) async -> Bool {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1400, height: 1400)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 1.5, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 1.5, preferredTimescale: 600)

        let safeDuration = duration.isFinite ? max(duration, 0) : 0
        var candidates: [Double] = []
        if safeDuration > 0 {
            candidates.append(safeDuration * 0.28)
            candidates.append(safeDuration * 0.52)
            candidates.append(min(3.0, safeDuration * 0.8))
        }
        candidates.append(0.5)

        for seconds in candidates {
            let time = CMTime(seconds: max(seconds, 0.05), preferredTimescale: 600)
            guard let image = try? await generator.image(at: time).image else { continue }
            let rep = NSBitmapImageRep(cgImage: image)
            guard let data = rep.representation(
                using: .jpeg,
                properties: [.compressionFactor: 0.84]
            ) else { continue }
            do {
                try data.write(to: url, options: .atomic)
                return true
            } catch {
                return false
            }
        }

        return false
    }
}
