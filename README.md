<p align="center">
  <img src="Support/icon.png" width="96" height="96" alt="Gainsayer icon">
</p>

<h1 align="center">Gainsayer</h1>

<p align="center">
  A menu bar volume control for the outputs macOS won't let you adjust. HDMI, optical, anything that reports no volume control: Gainsayer gives it a slider, the keyboard keys and a mute.
</p>

<p align="center">
  <a href="https://github.com/Treborbob/gainsayer/actions/workflows/ci.yml"><img src="https://github.com/Treborbob/gainsayer/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/licence-MIT-blue.svg" alt="MIT licence"></a>
  <img src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white" alt="Swift 6">
  <img src="https://img.shields.io/badge/macOS-15%2B-000000?logo=apple&logoColor=white" alt="macOS 15+">
  <img src="https://img.shields.io/badge/contributions-not%20accepted-lightgrey" alt="Contributions not accepted">
</p>

---

## Why

Send your Mac's audio over HDMI to a TV or monitor and the volume slider greys out. The device
exposes no hardware level control, so macOS shows a bezel with a disabled slider and the keyboard
keys do nothing. If the far end of that cable is a fixed-level optical feed into a DAC and amp,
you're left reaching for a knob every time a video is louder than the last one.

Gainsayer fixes exactly that and nothing else.

- **Automatic.** It engages when the default output has no volume control and stands aside when
  it does. Switch to the built-in speakers and macOS is back in charge, keys included.
- **Native feel.** The keyboard volume keys, mute, and Shift+Option quarter-steps work as they do
  everywhere else, with a bezel under the menu bar styled after the system one. Ours has a 💪 on it.
- **Transparent at full volume.** At 100% the audio passes through untouched. Below that it is
  scaled along a cubic taper, which is how a volume knob feels.
- **No drivers.** It uses Core Audio process taps, the API Apple added in macOS 14.2 so apps like
  this no longer need a virtual audio device or a system extension. Nothing to install or uninstall
  beyond the app.
- **Fails safe.** If the app quits or crashes, the tap is torn down and the device plays at its
  normal level again.

Built for one desk: a MacBook Pro into an LG OLED over HDMI, with optical out to an amp. It should
work for any device in the same situation, but it will never grow into an audio suite.

## How it works

Gainsayer lives in the menu bar. Click it for the device name, a slider, a mute button and a
launch-at-login toggle. While it is engaged the keyboard keys drive the same level, in 32 steps, and
each press shows the bezel.

Under the hood there are three parts.

**The tap.** A global Core Audio process tap captures everything the system is playing, excluding
Gainsayer itself. It is created with `mutedWhenTapped`, so the original signal to the device goes
silent while the tap is being read.

**The aggregate device.** A private aggregate device contains both the tap, as input, and the real
output device, as output. Core Audio hands one IO callback the input and output buffers together, so
the whole engine is "multiply by gain, copy across". No resampling, no extra buffering, no locks.

**The key tap.** A session-level event tap intercepts the volume keys only while Gainsayer is
engaged. Otherwise the events pass through untouched and macOS handles them as normal.

`VolumeController` watches the default output device and the device list, engages when the current
default reports no volume control, and disengages when it does or when the device disappears.

## Stack

Swift 6 · SwiftUI `MenuBarExtra` · AppKit for the bezel and event tap · Core Audio process taps and
aggregate devices · Swift Package Manager · `swift format` · Swift Testing · GitHub Actions on
macOS 26

No third-party dependencies.

## Installing

Gainsayer is not on the App Store and is not notarised. It is built from source.

```bash
git clone https://github.com/Treborbob/gainsayer.git
cd gainsayer
make install      # builds, copies to /Applications, launches
```

On first launch macOS asks for two permissions:

1. **System Audio Recording**, needed to create the tap.
2. **Accessibility**, needed to intercept the keyboard volume keys. The slider works without it.

Then tick "Launch at login" in the menu. Do this from the copy in `/Applications`, because the login
item is registered by path.

### Code signing, once

macOS ties permissions to the app's code signature, and ad-hoc signatures change on every build.
Create a stable self-signed identity so you are not re-granting permissions after each rebuild:

1. Open Keychain Access. Menu: Keychain Access > Certificate Assistant > Create a Certificate.
2. Name: `Gainsayer Dev`. Identity Type: Self Signed Root. Certificate Type: Code Signing.
3. Create it in the login keychain.

The build script uses it automatically. It does not need to be trusted. The first build prompts for
keychain access; choose Always Allow.

A Homebrew tap for install and updates is on the list.

## Project layout

```
Sources/Gainsayer/
  Audio/AudioSystem.swift       HAL property helpers, listeners, error formatting
  Audio/TapEngine.swift         tap + aggregate device + the realtime IO callback
  Input/MediaKeyMonitor.swift   CGEventTap for the volume keys
  UI/                           menu bar view and the floating bezel
  VolumeController.swift        state, device tracking, engage/disengage, taper
Tests/GainsayerTests/           unit tests for the pure parts
Support/                        Info.plist, app icon
scripts/                        bundle build and icon generator
```

## Quality

```bash
make check        # swift format lint + swift test
```

The taper and error formatting are covered by unit tests. The audio path is verified by hand
against real hardware, following the checklist in `CLAUDE.md`. CI lints, tests and builds the app
bundle on every push.

## Troubleshooting

**The volume keys stopped working after a rebuild, and Accessibility shows Gainsayer as ticked.**
The ticked row belongs to an earlier code signature. Reset the record and grant it again:

```bash
tccutil reset Accessibility dev.robblack.gainsayer
```

**Reading the log.** State changes are logged at notice level:

```bash
/usr/bin/log show --last 10m --predicate 'subsystem == "dev.robblack.gainsayer"' --style compact
```

Use the full path: zsh has a builtin named `log` that silently swallows the command otherwise.

**Two instances.** A second launch exits immediately, because two taps would fight over the device.

## Contributing

Gainsayer is a personal project and I'm the only one working on it. Forks are very welcome, and so
are bug reports via issues, but I'm not accepting pull requests. If you want to take it somewhere,
fork it and make it yours. See [CONTRIBUTING.md](CONTRIBUTING.md) if you're setting up a fork.

Things on the maybe-later list: a Homebrew tap, per-device volume memory, a finer taper setting.

## Licence

[MIT](LICENSE). Do what you like with it; a mention is appreciated.

## Acknowledgements

The tap-plus-aggregate-device approach follows Apple's Core Audio taps documentation and Guilherme
Rambo's [AudioCap](https://github.com/insidegui/AudioCap) sample, which is the clearest worked
example of the API. The app was built with [Claude Code](https://claude.com/claude-code). The name
is because a gainsayer is someone who contradicts, and this one contradicts macOS about whether
HDMI has a volume control.
