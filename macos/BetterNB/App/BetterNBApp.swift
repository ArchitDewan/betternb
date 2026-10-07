import SwiftUI
import AppKit

@main
struct BetterNBApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appearance = WorkspaceAppearance()
    @StateObject private var authentication: AuthenticationSession
    @AppStorage("lemmaAppearance") private var lemmaAppearance = "dark"

    init() {
        _authentication = StateObject(wrappedValue: AppDependencies.makeAuthenticationSession())
    }

    var body: some Scene {
        WindowGroup {
            AuthenticationGateView(session: authentication)
                .preferredColorScheme(colorScheme)
                .environment(\.workspaceZoom, appearance.factor)
                .frame(
                    minWidth: WorkspaceLayout.minimumWindowSize.width,
                    minHeight: WorkspaceLayout.minimumWindowSize.height
                )
                .background(WindowLaunchHook())
                .background(ZoomKeyShortcuts(appearance: appearance))
        }
        .defaultSize(
            width: WorkspaceLayout.launchWindowSize.width,
            height: WorkspaceLayout.launchWindowSize.height
        )
        .defaultPosition(.center)
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            ZoomCommands(appearance: appearance)
            CommandMenu("Appearance") {
                Button("Light") { lemmaAppearance = "light" }
                    .disabled(lemmaAppearance == "light")
                Button("Dark") { lemmaAppearance = "dark" }
                    .disabled(lemmaAppearance == "dark")
                Button("Follow System") { lemmaAppearance = "system" }
                    .disabled(lemmaAppearance == "system")
            }
        }
    }

    private var colorScheme: ColorScheme? {
        switch lemmaAppearance {
        case "light": .light
        case "dark": .dark
        case "system": nil
        default: .dark
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        false
    }
}

private struct WindowLaunchHook: NSViewRepresentable {
    private static var didApplyLaunchFrame = false

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            Self.applyChrome(to: view.window)
            Self.applyLaunchFrame(to: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            Self.applyChrome(to: nsView.window)
        }
    }

    private static func applyChrome(to window: NSWindow?) {
        guard let window else { return }
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
    }

    private static func applyLaunchFrame(to window: NSWindow?) {
        guard !didApplyLaunchFrame, let window, !window.isMiniaturized else { return }
        didApplyLaunchFrame = true
        window.isRestorable = false
        window.setFrameAutosaveName("")
        let contentSize = WorkspaceLayout.launchWindowSize
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize))
        if let visible = (window.screen ?? NSScreen.main)?.visibleFrame {
            frame.size.width = min(frame.width, visible.width)
            frame.size.height = min(frame.height, visible.height)
            frame.origin.x = visible.midX - frame.width / 2
            frame.origin.y = visible.midY - frame.height / 2
        }
        window.setFrame(frame, display: true)
    }
}
