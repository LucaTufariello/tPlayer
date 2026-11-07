import SwiftUI
import AppKit

@main
struct TPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = LibraryStore()
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.system.rawValue

    var body: some Scene {
        Window("tPlayer", id: "main") {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(
                    AppearanceMode(rawValue: appearanceModeRaw)?.colorScheme
                )
                .frame(minWidth: 1040, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            TPlayerCommands(store: store)
        }
    }
}

@MainActor
enum OpenURLQueue {
    static let didReceive = Notification.Name("tPlayerDidReceiveOpenURLs")
    private static var pending: [URL] = []

    static func enqueue(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        pending.append(contentsOf: urls)
        NotificationCenter.default.post(name: didReceive, object: nil)
    }

    static func drain() -> [URL] {
        defer { pending.removeAll() }
        return pending
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        NSApp.activate()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        OpenURLQueue.enqueue(urls)
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        OpenURLQueue.enqueue(filenames.map { URL(fileURLWithPath: $0) })
        sender.reply(toOpenOrPrint: .success)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

struct TPlayerCommands: Commands {
    @ObservedObject var store: LibraryStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Import Films…") {
                store.chooseAndImport()
            }
            .keyboardShortcut("o", modifiers: .command)
        }

        CommandGroup(after: .appInfo) {
            Divider()
            Button("Reveal Library Folder") {
                NSWorkspace.shared.open(LibraryPaths.root)
            }
        }
    }
}
