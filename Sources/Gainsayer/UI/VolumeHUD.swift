import AppKit
import SwiftUI

/// The floating volume bezel shown near the top-right of the screen when a volume key is pressed,
/// standing in for the system one that macOS does not show for devices it cannot control.
@MainActor
final class VolumeHUD {
    private final class Model: ObservableObject {
        @Published var level: Float = 0
        @Published var muted = false
    }

    private static let size = NSSize(width: 220, height: 44)
    private static let margin = NSPoint(x: 12, y: 8)
    private static let holdDuration: TimeInterval = 1.5

    private let model = Model()
    private var panel: NSPanel?
    private var hideTimer: Timer?

    func show(level: Float, muted: Bool) {
        model.level = level
        model.muted = muted

        let panel = panel ?? makePanel()
        position(panel)
        if !panel.isVisible || panel.alphaValue < 1 {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                panel.animator().alphaValue = 1
            }
        }

        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: Self.holdDuration, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }
    }

    private func hide() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            panel.animator().alphaValue = 0
        }, completionHandler: {
            if panel.alphaValue == 0 { panel.orderOut(nil) }
        })
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .screenSaver
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: HUDView(model: model))
        self.panel = panel
        return panel
    }

    /// Top-right of the screen holding the key window, tucked under the menu bar like the system bezel.
    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let frame = screen.visibleFrame
        let origin = NSPoint(
            x: frame.maxX - Self.size.width - Self.margin.x,
            y: frame.maxY - Self.size.height - Self.margin.y
        )
        panel.setFrameOrigin(origin)
    }

    private struct HUDView: View {
        @ObservedObject var model: Model

        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: model.muted ? "speaker.slash.fill" : symbol)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 22)
                    .foregroundStyle(.primary)

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.primary.opacity(0.18))
                        Capsule()
                            .fill(.primary)
                            .frame(width: proxy.size.width * CGFloat(model.muted ? 0 : model.level))
                    }
                }
                .frame(height: 6)
                .animation(.easeOut(duration: 0.12), value: model.level)
                .animation(.easeOut(duration: 0.12), value: model.muted)
            }
            .padding(.horizontal, 16)
            .frame(width: VolumeHUD.size.width, height: VolumeHUD.size.height)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }

        private var symbol: String {
            switch model.level {
            case 0: "speaker.fill"
            case ..<0.34: "speaker.wave.1.fill"
            case ..<0.67: "speaker.wave.2.fill"
            default: "speaker.wave.3.fill"
            }
        }
    }
}
