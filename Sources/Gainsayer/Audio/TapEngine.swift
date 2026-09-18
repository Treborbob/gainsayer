import Accelerate
import AudioToolbox
import CoreAudio
import Foundation
import Synchronization

/// Captures everything the system is playing, scales it, and plays it out to the target device.
///
/// The trick: one aggregate device that contains both the process tap (as input) and the real output
/// device (as output). Core Audio then hands us input and output buffers in a single IO callback, and
/// the whole audio engine is "multiply by gain, copy across". The tap is created with
/// `mutedWhenTapped`, so the original signal to the device goes silent and ours replaces it.
final class TapEngine {
    enum EngineError: LocalizedError {
        case noDeviceUID

        var errorDescription: String? {
            switch self {
            case .noDeviceUID: "The output device has no UID"
            }
        }
    }

    private static let aggregateUID = "dev.robblack.gainsayer.aggregate"

    /// Linear gain 0...1, read from the realtime audio thread. Stored as bits so it can be atomic.
    private let gainBits = Atomic<UInt32>(Float(1).bitPattern)

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var tapUUID = UUID()
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private let ioQueue = DispatchQueue(label: "dev.robblack.gainsayer.io", qos: .userInteractive)

    private(set) var isRunning = false

    deinit { stop() }

    func setGain(_ gain: Float) {
        gainBits.store(min(max(gain, 0), 1).bitPattern, ordering: .relaxed)
    }

    func start(outputDevice: AudioObjectID) throws {
        stop()
        guard let outputUID = AudioSystem.uid(of: outputDevice) else { throw EngineError.noDeviceUID }
        Log.audio.notice("Starting engine for device \(outputDevice) uid=\(outputUID, privacy: .public)")
        do {
            try createTap()
            try createAggregate(outputUID: outputUID)
            try startIO()
            isRunning = true
            Log.audio.notice("Engine running: tap=\(self.tapID) aggregate=\(self.aggregateID)")
        } catch {
            Log.audio.error("Engine start failed: \(error.localizedDescription, privacy: .public)")
            stop()
            throw error
        }
    }

    func stop() {
        if isRunning { Log.audio.notice("Stopping engine") }
        if let ioProcID {
            AudioDeviceStop(aggregateID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
            self.ioProcID = nil
        }
        if aggregateID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = kAudioObjectUnknown
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = kAudioObjectUnknown
        }
        isRunning = false
    }

    // MARK: Setup

    private func createTap() throws {
        // Exclude ourselves, otherwise our own output would be tapped, muted, and fed back to us.
        let excluded = [AudioSystem.ownProcessObject()].compactMap { $0 }
        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: excluded)
        description.uuid = UUID()
        description.name = "Gainsayer"
        description.muteBehavior = .mutedWhenTapped
        description.isPrivate = true

        var id = AudioObjectID(kAudioObjectUnknown)
        try check(AudioHardwareCreateProcessTap(description, &id), "Creating the system audio tap")
        tapID = id
        tapUUID = description.uuid
        Log.audio.debug("Created tap \(id) excluding processes \(excluded)")
    }

    private func createAggregate(outputUID: String) throws {
        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Gainsayer Output",
            kAudioAggregateDeviceUIDKey: Self.aggregateUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceSubDeviceListKey: [
                [kAudioSubDeviceUIDKey: outputUID],
            ],
            kAudioAggregateDeviceTapListKey: [
                [
                    kAudioSubTapUIDKey: tapUUID.uuidString,
                    kAudioSubTapDriftCompensationKey: true,
                ],
            ],
            kAudioAggregateDeviceTapAutoStartKey: true,
        ]
        var id = AudioObjectID(kAudioObjectUnknown)
        try check(AudioHardwareCreateAggregateDevice(description as CFDictionary, &id), "Creating the aggregate device")
        aggregateID = id
    }

    private func startIO() throws {
        var procID: AudioDeviceIOProcID?
        let status = AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, ioQueue) { [unowned self] _, input, _, output, _ in
            self.render(input: input, output: output)
        }
        try check(status, "Creating the IO callback")
        ioProcID = procID
        try check(AudioDeviceStart(aggregateID, procID), "Starting the aggregate device")
    }

    // MARK: Realtime path

    /// Runs on the audio thread. No allocation, no locks, no Swift runtime surprises.
    private func render(input: UnsafePointer<AudioBufferList>, output: UnsafeMutablePointer<AudioBufferList>) {
        var gain = Float(bitPattern: gainBits.load(ordering: .relaxed))
        let inBuffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        let outBuffers = UnsafeMutableAudioBufferListPointer(output)

        // Silence first, so anything we don't fill is quiet rather than stale.
        for buffer in outBuffers {
            if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) }
        }
        guard gain > 0, !inBuffers.isEmpty else { return }

        // Fast path: identical buffer layout on both sides. This is the expected case for a stereo tap
        // feeding a stereo device.
        let sameLayout = inBuffers.count == outBuffers.count
            && zip(inBuffers, outBuffers).allSatisfy { $0.mNumberChannels == $1.mNumberChannels }
        if sameLayout {
            for (i, o) in zip(inBuffers, outBuffers) {
                guard let ip = i.mData, let op = o.mData else { continue }
                let count = min(Int(i.mDataByteSize), Int(o.mDataByteSize)) / MemoryLayout<Float>.size
                vDSP_vsmul(ip.assumingMemoryBound(to: Float.self), 1, &gain,
                           op.assumingMemoryBound(to: Float.self), 1, vDSP_Length(count))
            }
            return
        }

        // Slow path: layouts differ (interleaved vs planar, or channel counts). Map input channels onto
        // output channels in order, wrapping if the output has more channels than the input.
        let inChannelCount = inBuffers.reduce(0) { $0 + Int($1.mNumberChannels) }
        guard inChannelCount > 0 else { return }
        var outChannelBase = 0
        for o in outBuffers {
            let oChannels = Int(o.mNumberChannels)
            guard oChannels > 0, let op = o.mData?.assumingMemoryBound(to: Float.self) else { continue }
            let oFrames = Int(o.mDataByteSize) / MemoryLayout<Float>.size / oChannels
            for oc in 0..<oChannels {
                let target = (outChannelBase + oc) % inChannelCount
                var seen = 0
                for i in inBuffers {
                    let iChannels = Int(i.mNumberChannels)
                    if target < seen + iChannels, iChannels > 0, let ip = i.mData?.assumingMemoryBound(to: Float.self) {
                        let ic = target - seen
                        let iFrames = Int(i.mDataByteSize) / MemoryLayout<Float>.size / iChannels
                        for f in 0..<min(iFrames, oFrames) {
                            op[f * oChannels + oc] = ip[f * iChannels + ic] * gain
                        }
                        break
                    }
                    seen += iChannels
                }
            }
            outChannelBase += oChannels
        }
    }
}
