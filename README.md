# Gainsayer

A tiny macOS menu bar utility that gives you a volume control for outputs macOS refuses to control,
such as HDMI and optical.

## Why

When the default output is an HDMI device (a TV, a monitor with a DAC behind it), macOS greys out
the volume slider and the keyboard volume keys do nothing, because the device exposes no hardware
level control. Gainsayer steps into the signal path only for those devices: it taps everything the
system is playing, scales it, and plays it out itself. When you switch back to a device that has its
own volume control, it steps aside again.

## How it works

- A **Core Audio process tap** (macOS 14.2+) captures all system audio, excluding Gainsayer itself.
  The tap is created with `mutedWhenTapped`, so the original signal to the device goes silent while
  the tap is being read.
- A private **aggregate device** contains both the tap (as input) and the real output device (as
  output). One IO callback receives input and output buffers together, so the engine is just
  "multiply by gain, copy across". See `Sources/Gainsayer/Audio/TapEngine.swift`.
- A session-level **event tap** intercepts the volume keys while Gainsayer is engaged, and lets them
  through untouched otherwise. See `Sources/Gainsayer/Input/MediaKeyMonitor.swift`.
- `VolumeController` watches the default output device and decides when to engage.

Gainsayer engages automatically for any default output that lacks a volume control. No configuration.

## Requirements

- macOS 15 or later (built and tested on macOS 26).
- Xcode 16 or later for the Swift toolchain.

## Permissions

On first launch macOS will ask for two things:

1. **System Audio Recording**: needed to create the tap. Prompted automatically.
2. **Accessibility**: needed to intercept the keyboard volume keys. Prompted automatically; the
   slider in the menu works without it.

## Building

```bash
make app        # builds build/Gainsayer.app
make run        # builds and launches it
make install    # builds, copies to /Applications, launches
```

### Code signing (do this once)

macOS ties an app's permissions to its code signature. Ad-hoc signatures change on every build, so
you would be re-granting permissions constantly. Create a stable self-signed identity instead:

1. Open Keychain Access. Menu: Keychain Access > Certificate Assistant > Create a Certificate.
2. Name: `Gainsayer Dev`. Identity Type: Self Signed Root. Certificate Type: Code Signing.
3. Create it in the login keychain.

The build script picks it up automatically. To use a different identity, set `SIGN_IDENTITY`.

## Roadmap

- [ ] First run against real hardware and confirm the audio path
- [ ] Volume bezel HUD to match the system one
- [ ] Launch at login
- [ ] Homebrew tap for install and updates
