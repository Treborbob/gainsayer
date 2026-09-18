import AppKit
import SwiftUI

@main
struct GainsayerApp: App {
    @StateObject private var controller: VolumeController

    init() {
        Self.exitIfAlreadyRunning()
        _controller = StateObject(wrappedValue: VolumeController())
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(controller)
        } label: {
            Image(systemName: controller.menuBarSymbol)
        }
        .menuBarExtraStyle(.window)

        Window("About Gainsayer", id: AboutView.windowID) {
            AboutView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }

    /// Two instances would both tap the system audio and fight over the output. Yield to the first.
    private static func exitIfAlreadyRunning() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let me = ProcessInfo.processInfo.processIdentifier
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != me }
        guard !others.isEmpty else { return }
        Log.app.notice("Another instance is already running (pid \(others[0].processIdentifier)); exiting")
        exit(0)
    }
}
