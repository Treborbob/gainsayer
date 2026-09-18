import AppKit
import SwiftUI

/// The About window: what this is, who made it, where it lives, and who to thank.
struct AboutView: View {
    static let windowID = "about"

    private static let repository = URL(string: "https://github.com/Treborbob/gainsayer")!
    private static let author = URL(string: "https://robblack.dev")!
    private static let licence = URL(string: "https://github.com/Treborbob/gainsayer/blob/main/LICENSE")!
    private static let audioCap = URL(string: "https://github.com/insidegui/AudioCap")!
    private static let claudeCode = URL(string: "https://claude.com/claude-code")!

    private var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let short = info["CFBundleShortVersionString"] as? String ?? "dev"
        let build = info["CFBundleVersion"] as? String ?? "0"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            VStack(spacing: 4) {
                Text("Gainsayer")
                    .font(.system(size: 22, weight: .bold))
                Text(version)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Volume for the outputs macOS won't let you adjust.")
                .font(.headline)

            Text(
                """
                Over HDMI or optical the volume keys go dead, because the device has no level control. \
                Gainsayer steps in for exactly those devices and hands you back the slider, the keys and mute.
                """
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            HStack(spacing: 18) {
                Link("Source on GitHub", destination: Self.repository)
                Link("Made by Rob Black", destination: Self.author)
                Link("MIT licence", destination: Self.licence)
            }
            .font(.callout)

            Divider()
                .padding(.horizontal, 40)

            VStack(spacing: 4) {
                Text(
                    "Core Audio process taps, no drivers. Thanks to [AudioCap](\(Self.audioCap)) for the "
                        + "worked example. Made with [Claude Code](\(Self.claudeCode))."
                )
                Text("A gainsayer contradicts. This one contradicts macOS about HDMI having a volume.")
                    .italic()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 28)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .frame(width: 440)
    }
}
