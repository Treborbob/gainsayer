import AppKit
import Combine
import CoreAudio
import Foundation

/// Owns the app's state: which device is current, whether we are managing it, and the user's volume.
@MainActor
final class VolumeController: ObservableObject {
    /// User-facing level, 0...1. Persisted.
    @Published private(set) var volume: Float
    @Published private(set) var isMuted = false
    /// True while the tap engine is running against the current default output.
    @Published private(set) var isEngaged = false
    @Published private(set) var deviceName = "No output device"
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var lastError: String?

    /// Keyboard step. macOS uses 16 steps; we use 32 for finer control over a fixed-gain amp chain.
    static let step: Float = 1.0 / 32.0
    private static let volumeKey = "volume"
    /// Exponent of the volume taper. 3 is the common "cubic" taper: 50% is about -18 dB, 25% about
    /// -36 dB. Lower it towards 2 for a louder mid-range, raise it for more resolution at the top.
    private static let taper: Float = 3

    private let engine = TapEngine()
    private let keys = MediaKeyMonitor()
    private let hud = VolumeHUD()
    private var listeners: [AudioSystem.ListenerToken] = []
    private var engagedDevice: AudioObjectID?
    private var accessibilityRetry: Timer?

    init() {
        let saved = UserDefaults.standard.object(forKey: Self.volumeKey) as? Float
        volume = saved ?? 0.5

        keys.shouldIntercept = { [weak self] in
            MainActor.assumeIsolated { self?.isEngaged ?? false }
        }
        keys.onKey = { [weak self] key, fine in
            MainActor.assumeIsolated {
                guard let self else { return }
                let step = fine ? Self.step / 4 : Self.step
                switch key {
                case .volumeUp: self.stepVolume(by: step)
                case .volumeDown: self.stepVolume(by: -step)
                case .mute: self.toggleMute()
                }
                self.hud.show(device: self.deviceName, level: self.volume, muted: self.isMuted || self.volume == 0)
            }
        }

        listeners = [
            AudioSystem.listen(AudioSystem.systemObject, kAudioHardwarePropertyDefaultOutputDevice) { [weak self] in
                MainActor.assumeIsolated { self?.evaluate() }
            },
            AudioSystem.listen(AudioSystem.systemObject, kAudioHardwarePropertyDevices) { [weak self] in
                MainActor.assumeIsolated { self?.evaluate() }
            },
        ].compactMap { $0 }

        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.disengage() }
        }

        startKeyMonitor(prompt: true)
        evaluate()
    }

    // MARK: Device tracking

    /// Looks at the current default output and decides whether Gainsayer should be in the signal path.
    func evaluate() {
        guard let device = AudioSystem.defaultOutputDevice() else {
            deviceName = "No output device"
            disengage()
            return
        }
        deviceName = AudioSystem.name(of: device)
        let needsUs = !AudioSystem.hasOutputVolumeControl(device)
        Log.app.notice("Default output is \(device) \(self.deviceName, privacy: .public); needs Gainsayer: \(needsUs)")

        if needsUs {
            if engagedDevice != device { engage(device) }
        } else {
            disengage()
        }
    }

    private func engage(_ device: AudioObjectID) {
        disengage()
        do {
            try engine.start(outputDevice: device)
            engagedDevice = device
            isEngaged = true
            lastError = nil
            applyGain()
        } catch {
            lastError = error.localizedDescription
            Log.app.error("Could not engage: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func disengage() {
        if isEngaged { Log.app.notice("Disengaging") }
        engine.stop()
        engagedDevice = nil
        isEngaged = false
    }

    // MARK: Volume

    func setVolume(_ value: Float) {
        volume = min(max(value, 0), 1)
        isMuted = false
        Log.app.debug("Volume set to \(self.volume)")
        UserDefaults.standard.set(volume, forKey: Self.volumeKey)
        applyGain()
    }

    func stepVolume(by delta: Float) {
        // Snap to the grid of the step being taken so keyboard and slider agree with each other.
        let grid = abs(delta)
        let snapped = (volume / grid).rounded() * grid
        setVolume(snapped + delta)
    }

    func toggleMute() {
        isMuted.toggle()
        Log.app.debug("Mute \(self.isMuted)")
        applyGain()
    }

    private func applyGain() {
        engine.setGain(isMuted ? 0 : Self.gain(for: volume))
    }

    /// Maps the 0...1 slider onto linear gain with a power-law taper, which is how a volume knob feels.
    /// 1.0 is unity: the signal passes through untouched.
    static func gain(for value: Float) -> Float {
        guard value > 0 else { return 0 }
        return pow(value, taper)
    }

    // MARK: Keys

    private func startKeyMonitor(prompt: Bool) {
        accessibilityGranted = MediaKeyMonitor.isTrusted(prompt: prompt)
        if accessibilityGranted, keys.start() {
            Log.keys.notice("Media key monitor running")
            accessibilityRetry?.invalidate()
            accessibilityRetry = nil
            return
        }
        // Not granted yet. Poll quietly until the user flips the switch in System Settings.
        if accessibilityRetry == nil {
            Log.keys.notice("Accessibility not granted (trusted=\(self.accessibilityGranted)); will retry")
            accessibilityRetry = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.startKeyMonitor(prompt: false) }
            }
        }
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    // MARK: Presentation

    var menuBarSymbol: String {
        guard isEngaged else { return "speaker.wave.2" }
        if isMuted || volume == 0 { return "speaker.slash.fill" }
        switch volume {
        case ..<0.34: return "speaker.wave.1.fill"
        case ..<0.67: return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
        }
    }

    var statusText: String {
        isEngaged ? "Controlling \(deviceName)" : deviceName
    }

    var explanation: String {
        if lastError != nil { return "Could not take over the output." }
        return "\(deviceName) has its own volume control, so Gainsayer is standing aside."
    }
}
