import Testing

@testable import Gainsayer

@MainActor
struct TaperTests {
    @Test func unityAtFullScale() {
        #expect(VolumeController.gain(for: 1) == 1)
    }

    @Test func silenceAtZero() {
        #expect(VolumeController.gain(for: 0) == 0)
    }

    @Test func strictlyIncreasing() {
        let steps = stride(from: 0, through: 1, by: VolumeController.step).map { VolumeController.gain(for: $0) }
        for pair in zip(steps, steps.dropFirst()) {
            #expect(pair.0 < pair.1)
        }
    }

    @Test func midpointIsQuieterThanLinear() {
        // A taper exists so that the mid-range is usable; half the slider must be well under half the gain.
        #expect(VolumeController.gain(for: 0.5) < 0.25)
    }
}

struct CoreAudioErrorTests {
    @Test func fourCharCodesArePrintable() {
        #expect(CoreAudioError.describe(0x6E6F_7065) == "'nope'")
    }

    @Test func otherStatusesAreNumeric() {
        #expect(CoreAudioError.describe(-50) == "-50")
    }
}
