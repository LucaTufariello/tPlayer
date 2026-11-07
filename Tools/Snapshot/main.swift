import SwiftUI
import AppKit
import Foundation

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

let snapshotDir = URL(fileURLWithPath: "/tmp/tplayer_snapshots", isDirectory: true)
try? FileManager.default.createDirectory(at: snapshotDir, withIntermediateDirectories: true)

@MainActor
func copySampleAssets() {
    let fm = FileManager.default
    let thumbNames = ["quiet-coast.jpg", "paper-moons.jpg", "field-of-static.jpg", "northbound.jpg"]
    let mediaNames = ["quiet-coast.mp4", "paper-moons.mp4", "field-of-static.mp4", "northbound.mp4"]

    for name in thumbNames {
        let src = URL(fileURLWithPath: "/tmp/tplayer_samples/thumbs/\(name)")
        let dst = LibraryPaths.thumbnails.appendingPathComponent(name)
        try? fm.removeItem(at: dst)
        try? fm.copyItem(at: src, to: dst)
    }
    for name in mediaNames {
        let src = URL(fileURLWithPath: "/tmp/tplayer_samples/\(name)")
        let dst = LibraryPaths.media.appendingPathComponent(name)
        try? fm.removeItem(at: dst)
        try? fm.copyItem(at: src, to: dst)
    }
}

@MainActor
func writePNG<V: View>(_ view: V, name: String, width: CGFloat, height: CGFloat, settle: TimeInterval = 0.45, appearance: NSAppearance.Name? = nil) {
    let hosting = NSHostingView(rootView: view)
    hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
    if let appearance {
        hosting.appearance = NSAppearance(named: appearance)
    }

    let window = NSWindow(
        contentRect: hosting.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.isReleasedWhenClosed = false
    if let appearance {
        window.appearance = NSAppearance(named: appearance)
    }
    window.contentView = hosting
    window.setFrameOrigin(NSPoint(x: -4000, y: -4000))
    window.orderFront(nil)
    hosting.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(settle))
    hosting.layoutSubtreeIfNeeded()

    guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
        print("Failed to render \(name)")
        return
    }
    hosting.cacheDisplay(in: hosting.bounds, to: rep)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        print("Failed to encode \(name)")
        return
    }

    let url = snapshotDir.appendingPathComponent("\(name).png")
    do {
        try data.write(to: url)
        print("Wrote \(url.path) \(rep.pixelsWide)x\(rep.pixelsHigh)")
    } catch {
        print("Write failed \(name): \(error)")
    }
    window.orderOut(nil)
}

Task { @MainActor in
    copySampleAssets()

    let now = Date()
    let films: [Film] = [
        Film(
            id: UUID(),
            title: "The Quiet Coast",
            year: 2024,
            sourceFileName: "quiet-coast.mp4",
            mediaFileName: "quiet-coast.mp4",
            thumbnailFileName: "quiet-coast.jpg",
            duration: 6_420,
            progress: 2_520,
            lastWatched: now.addingTimeInterval(-3_600),
            addedAt: now.addingTimeInterval(-86_400 * 2),
            fileSize: 0,
            isWatched: false,
            aspectRatio: 16.0 / 9.0
        ),
        Film(
            id: UUID(),
            title: "Paper Moons",
            year: 2023,
            sourceFileName: "paper-moons.mp4",
            mediaFileName: "paper-moons.mp4",
            thumbnailFileName: "paper-moons.jpg",
            duration: 5_580,
            progress: 1_860,
            lastWatched: now.addingTimeInterval(-7_200),
            addedAt: now.addingTimeInterval(-86_400 * 5),
            fileSize: 0,
            isWatched: false,
            aspectRatio: 16.0 / 9.0
        ),
        Film(
            id: UUID(),
            title: "A Field of Static",
            year: 2025,
            sourceFileName: "field-of-static.mp4",
            mediaFileName: "field-of-static.mp4",
            thumbnailFileName: "field-of-static.jpg",
            duration: 7_020,
            progress: 900,
            lastWatched: now.addingTimeInterval(-86_400),
            addedAt: now.addingTimeInterval(-86_400 * 9),
            fileSize: 0,
            isWatched: false,
            aspectRatio: 16.0 / 9.0
        ),
        Film(
            id: UUID(),
            title: "Northbound",
            year: 2022,
            sourceFileName: "northbound.mp4",
            mediaFileName: "northbound.mp4",
            thumbnailFileName: "northbound.jpg",
            duration: 4_980,
            progress: 0,
            lastWatched: now.addingTimeInterval(-86_400 * 4),
            addedAt: now.addingTimeInterval(-86_400 * 12),
            fileSize: 0,
            isWatched: true,
            aspectRatio: 16.0 / 9.0
        )
    ]

    let store = LibraryStore(previewFilms: films, pinnedFilmID: films[0].id)
    let emptyStore = LibraryStore(previewFilms: [])

    let home = ZStack {
        PaperBackground()
        HomeView(
            onOpenFilm: { _ in },
            onStartOver: { _ in },
            onPinPicker: {}
        )
        .environmentObject(store)
    }

    writePNG(home, name: "home-populated", width: 1280, height: 840, appearance: .aqua)
    writePNG(home, name: "home-full", width: 1280, height: 1240, appearance: .aqua)
    writePNG(home, name: "home-full-dark", width: 1280, height: 1240, appearance: .darkAqua)
    writePNG(home, name: "home-populated-dark", width: 1280, height: 840, appearance: .darkAqua)

    let emptyHome = ZStack {
        PaperBackground()
        HomeView(
            onOpenFilm: { _ in },
            onStartOver: { _ in },
            onPinPicker: {}
        )
        .environmentObject(emptyStore)
    }
    writePNG(emptyHome, name: "home-empty", width: 1280, height: 840, appearance: .aqua)
    writePNG(emptyHome, name: "home-empty-dark", width: 1280, height: 840, appearance: .darkAqua)

    let resume = ZStack {
        PaperBackground()
        HomeView(
            onOpenFilm: { _ in },
            onStartOver: { _ in },
            onPinPicker: {}
        )
        .environmentObject(store)
        ResumePromptView(
            film: films[0],
            onResume: {},
            onStartOver: {},
            onCancel: {}
        )
    }
    writePNG(resume, name: "resume-prompt", width: 1280, height: 840, appearance: .aqua)
    writePNG(resume, name: "resume-prompt-dark", width: 1280, height: 840, appearance: .darkAqua)

    let picker = ZStack {
        PaperBackground()
        HomeView(
            onOpenFilm: { _ in },
            onStartOver: { _ in },
            onPinPicker: {}
        )
        .environmentObject(store)
        PinPickerOverlay(
            films: films,
            pinnedID: films[0].id,
            onPin: { _ in },
            onUnpin: {},
            onClose: {}
        )
    }
    writePNG(picker, name: "pin-picker", width: 1280, height: 840, appearance: .aqua)
    writePNG(picker, name: "pin-picker-dark", width: 1280, height: 840, appearance: .darkAqua)

    let playerFilm = Film(
        id: UUID(),
        title: "The Quiet Coast",
        year: 2024,
        sourceFileName: "quiet-coast.mp4",
        mediaFileName: "quiet-coast.mp4",
        thumbnailFileName: "quiet-coast.jpg",
        duration: 8,
        progress: 3,
        lastWatched: now,
        addedAt: now,
        fileSize: 0,
        isWatched: false,
        aspectRatio: 16.0 / 9.0
    )
    let playerStore = LibraryStore(previewFilms: [playerFilm], pinnedFilmID: playerFilm.id)
    let player = PlayerView(film: playerFilm, startAt: 3, onClose: {})
        .environmentObject(playerStore)

    try? await Task.sleep(nanoseconds: 1_200_000_000)
    writePNG(player, name: "player", width: 1280, height: 840, settle: 1.4)

    exit(0)
}

RunLoop.main.run()
