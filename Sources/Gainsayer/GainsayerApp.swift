import SwiftUI

@main
struct GainsayerApp: App {
    @StateObject private var controller = VolumeController()

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(controller)
        } label: {
            Image(systemName: controller.menuBarSymbol)
        }
        .menuBarExtraStyle(.window)
    }
}
