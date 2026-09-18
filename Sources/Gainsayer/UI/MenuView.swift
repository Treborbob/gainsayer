import SwiftUI

struct MenuView: View {
    @EnvironmentObject private var controller: VolumeController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(controller.statusText, systemImage: controller.menuBarSymbol)
                .font(.headline)
                .lineLimit(1)

            if controller.isEngaged {
                HStack(spacing: 8) {
                    Button {
                        controller.toggleMute()
                    } label: {
                        Image(systemName: controller.isMuted ? "speaker.slash.fill" : "speaker.fill")
                            .frame(width: 16)
                    }
                    .buttonStyle(.plain)
                    .help(controller.isMuted ? "Unmute" : "Mute")

                    Slider(
                        value: Binding(
                            get: { controller.volume },
                            set: { controller.setVolume($0) }
                        ),
                        in: 0...1
                    )

                    Text("\(Int((controller.volume * 100).rounded()))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }
            } else {
                Text(controller.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = controller.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if !controller.accessibilityGranted {
                VStack(alignment: .leading, spacing: 4) {
                    Text("The keyboard volume keys need Accessibility access.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Open Accessibility Settings") {
                        controller.openAccessibilitySettings()
                    }
                    .controlSize(.small)
                }
            }

            Divider()

            Button("Quit Gainsayer") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 280)
    }
}
