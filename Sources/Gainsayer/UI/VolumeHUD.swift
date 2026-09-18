import AppKit
import SwiftUI

/// The floating volume bezel shown under the menu bar on the right when a volume key is pressed.
/// Styled after the macOS 26 system bezel, which for these devices only shows a greyed-out slider.
@MainActor
final class VolumeHUD {
    private final class Model: ObservableObject {
        @Published var device = ""
        @Published var level: Float = 0
        @Published var muted = false
    }

    private static let size = NSSize(width: 290, height: 62)
    private static let margin = NSPoint(x: 12, y: 10)
    private static let holdDuration: TimeInterval = 1.5

    private let model = Model()
    private var panel: NSPanel?
    private var hideTimer: Timer?

    func show(device: String, level: Float, muted: Bool) {
        model.device = device
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
        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = 0.25
                panel.animator().alphaValue = 0
            },
            completionHandler: {
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

        private let tickCount = 16
        private let trackHeight: CGFloat = 5

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(model.device)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    // Gains. Our signature, so the two bezels are never confused.
                    Text("\u{1F4AA}")
                        .font(.system(size: 14))
                }

                HStack(spacing: 10) {
                    Image(systemName: model.muted ? "speaker.slash.fill" : "speaker.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 16)

                    track

                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 20)
                }
                .foregroundStyle(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(width: VolumeHUD.size.width, height: VolumeHUD.size.height, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
            )
        }

        private var track: some View {
            VStack(spacing: 5) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.primary.opacity(0.2))
                        Capsule()
                            .fill(.primary)
                            .frame(width: proxy.size.width * CGFloat(model.muted ? 0 : model.level))
                    }
                }
                .frame(height: trackHeight)
                .animation(.easeOut(duration: 0.12), value: model.level)
                .animation(.easeOut(duration: 0.12), value: model.muted)

                HStack(spacing: 0) {
                    ForEach(0..<tickCount, id: \.self) { index in
                        Circle()
                            .fill(.primary.opacity(0.35))
                            .frame(width: 2, height: 2)
                        if index < tickCount - 1 { Spacer(minLength: 0) }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
}
