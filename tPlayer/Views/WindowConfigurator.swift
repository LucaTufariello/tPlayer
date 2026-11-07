import SwiftUI
import AppKit

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        ConfiguringView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class ConfiguringView: NSView {
    private var didConfigure = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window, !didConfigure else { return }
        didConfigure = true

        window.title = "tPlayer"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.styleMask.insert(.fullSizeContentView)
        window.backgroundColor = .paper
        window.isOpaque = true
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 1040, height: 700)
        window.contentMinSize = NSSize(width: 1040, height: 700)
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.standardWindowButton(.zoomButton)?.isEnabled = true

        if !window.setFrameUsingName("tPlayerMainWindow") {
            window.setContentSize(NSSize(width: 1280, height: 840))
            window.center()
        }
        window.setFrameAutosaveName("tPlayerMainWindow")
    }
}
