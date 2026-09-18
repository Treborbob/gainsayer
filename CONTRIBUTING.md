# Contributing

Gainsayer is a personal project with one committer and no roadmap beyond one desk. Pull requests
are not accepted, but forks are welcome, and bug reports via issues are useful. This file is for
anyone setting up a fork.

## Prerequisites

- macOS 15 or later. It is built and used on macOS 26.
- Xcode 16 or later, for the Swift 6 toolchain, `swift format` and `swift test`.
- No dependencies. The package uses only system frameworks.

## Build and run

```bash
git clone https://github.com/<you>/gainsayer.git
cd gainsayer
make run          # builds build/Gainsayer.app and launches it
```

Before your first run, create a self-signed code signing certificate named `Gainsayer Dev` in
Keychain Access (Certificate Assistant, Create a Certificate, type Code Signing). macOS ties an
app's permissions to its signature, and ad-hoc signatures change on every build. The build script
picks the certificate up automatically. If you name it something else, set `SIGN_IDENTITY`.

The first launch asks for System Audio Recording and Accessibility. Both stick across rebuilds once
the certificate is in place.

## Checks

```bash
make check        # swift format lint + swift test
make lint         # formatting only
make format       # rewrite sources to the project style
make test         # unit tests for the pure parts
```

The audio path itself has no automated tests. Verify it against real hardware with a device that
lacks a volume control selected as the default output: play something, move the slider, press the
keys, mute, switch to the built-in speakers and back, then quit and confirm audio returns at full
level.

## Where things are

See the "Project layout" section of the README. `CLAUDE.md` holds the working rules for the
codebase, including what the realtime audio callback is and is not allowed to do.
