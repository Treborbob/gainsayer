# Gainsayer

macOS menu bar app that adds a volume control for HDMI/optical outputs by tapping system audio,
scaling it, and playing it back out. Personal project, single user, no App Store, no sandbox.

## Ground rules

- Swift Package only. Do not add an Xcode project; `Package.swift` is the source of truth.
- Swift language mode 5 for now, because the Core Audio callback layer fights strict concurrency.
- Nothing in the realtime path (`TapEngine.render`) may allocate, lock, or touch Swift runtime
  features like arrays, closures, or classes. It runs on the audio thread.
- Read the four-character OSStatus codes back to the user when a Core Audio call fails; they are
  the only diagnostic Core Audio gives you.
- The app must never leave the user with no audio. Every engage path has a matching disengage,
  and the tap is torn down on quit.
- Keep the scope narrow: HDMI volume and mute, keyboard keys, menu slider. Push back on features.

## Layout

- `Sources/Gainsayer/Audio/AudioSystem.swift`: HAL property helpers and listeners.
- `Sources/Gainsayer/Audio/TapEngine.swift`: tap + aggregate device + IO callback.
- `Sources/Gainsayer/Input/MediaKeyMonitor.swift`: CGEventTap for the volume keys.
- `Sources/Gainsayer/VolumeController.swift`: state, device tracking, engage/disengage.
- `Sources/Gainsayer/UI/`: SwiftUI menu bar UI and the floating volume HUD.
- `Tests/GainsayerTests/`: Swift Testing unit tests for the pure parts (taper, error formatting).
- `Support/`: Info.plist, app icon. Regenerate the icon with `swift scripts/make-icon.swift`.
- `scripts/build-app.sh`: assembles and signs `build/Gainsayer.app`.
- `.github/workflows/ci.yml`: lint, test and bundle build on `macos-26`.

## Commands

- `swift build` compiles. `make app` builds the bundle. `make run` builds and launches.
- `make check` runs `swift format lint --strict` and `swift test`. Run it before committing; CI
  fails on either. `make format` rewrites sources to the `.swift-format` style (4 spaces, 120 cols).
- Unit tests cover only the pure parts. The audio path can only be verified against real hardware
  with the HDMI device as the default output. Say so plainly rather than claiming it works.
- Never run the bare binary from `.build/`: it is the app without its bundle, and it will start a
  second instance whose permission prompts get attributed to the wrong app. Use `make run`.
- Use `/usr/bin/log`, not `log`: zsh has a builtin of that name.

## Testing checklist for audio changes

1. `make run`, grant the permissions if prompted.
2. With the HDMI device selected, play audio, move the slider, press the volume keys, mute.
3. Switch output to the built-in speakers and confirm Gainsayer disengages and the keys work normally.
4. Switch back and confirm it re-engages.
5. Quit the app and confirm audio to the HDMI device returns at full level.
