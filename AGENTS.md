# AGENTS.md

Instructions for anyone — human or agent — working on this repository.

## What this is

TapeLogger is a logging package for Apple platforms: a dependency-free core
that records entries, plus a SwiftUI console to read them inside the app.
One entry model is shared by the output destinations and in-app console.

- Repository: <https://github.com/STlarner/TapeLogger> (public, MIT).
- Minimum iOS 17. macOS 14 is declared only so `swift test` can run on a Mac.
- Swift 6 language mode for every target.
- Everything in this repository is written in English: code, comments,
  documentation, commit messages, issues. There is no Italian anywhere.

## Golden rules

1. **`TapeLogger` stays dependency-free and UI-free.** No UIKit, no SwiftUI,
   no third-party package. `TapeLoggerUI` is the only target that imports
   SwiftUI.
2. **Renderers never hardcode colors.** They ask `TapeTheme`. A new visual
   decision means a new `TapeColor` (light, dark, ANSI 256 index, emoji), not
   a literal in a renderer.
3. **The hot path must not block.** Recording takes a lock, copies the sinks,
   then calls them outside the lock. Do not introduce an actor hop for
   ingestion, and do not allocate more than necessary per entry.
4. **Sinks are `Sendable` and may log.** A sink that records an entry must not
   recurse: `TapeReentrancyGuard` already covers this, keep using it.
5. **Logging is forward-only.** TapeLogger records explicit calls and events
   from installed adapters. Do not add unified-log imports or interception of
   third-party `os_log` or `print` calls as part of unrelated changes.
6. **Public API changes are deliberate.** This package is consumed by real
   apps; renaming a type or a parameter is a breaking change and needs a
   minor or major version bump and a README update.

## Layout

```
Package.swift              products: TapeLogger, TapeLoggerUI, TapeLoggerAdapters
Sources/TapeLogger/        core (Foundation + os only)
  Tape.swift               facade + hot path (record, log, levels, measure)
  Tape+Global.swift        static forwarders to Tape.shared
  Tape+Install.swift       installRecommendedSinks
  TapeEntry.swift          the entry: level, key, message, metadata, source,
                           duration, attachment; heading/copyText
  TapeLog.swift            protocol for app-defined log types
  TapeKey.swift            stream identity: id, title, level, color
  TapeLevel.swift          trace, debug, info, notice, warning, error,
                           critical, fault (mirrors os.Logger)
  TapeValue.swift          metadata values (string, int, double, bool,
                           array, object, null, raw)
  TapeTheme.swift          TapeColor + semantic palette and overrides
  TapeStore.swift          bounded history + AsyncStream for the UI
  TapeSink.swift           destination protocol
  TapeTimeFormatter.swift  HH:mm:ss.SSS
  TapeReentrancyGuard.swift
  Render/TapeTextRenderer.swift  capabilities (mode, width), detect()
  Render/TapeBoxRenderer.swift   the console box
  Sinks/TapeConsoleSink.swift
  Sinks/TapeOSLogSink.swift
Sources/TapeLoggerUI/      SwiftUI console (TapeConsoleView, TapeEntryCard,
                           TapeConsoleModel, tapeConsole modifier, triggers)
Sources/TapeLoggerAdapters/ opt-in URLSession, UIKit navigation and app lifecycle
Tests/TapeLoggerTests/     Swift Testing suites
Demo/                      Xcode app, local package reference, not shipped
```

The demo is part of the repository but is not included in the package products.

## Commands

```sh
swift build
swift test                       # runs on macOS
xcodebuild -scheme TapeLoggerUI \
  -destination 'generic/platform=iOS Simulator' build
```

Build and run the demo (use the simulator that is already open; do not boot
another one):

```sh
xcodebuild -project Demo/TapeDemo.xcodeproj -scheme TapeDemo \
  -destination 'platform=iOS Simulator,id=BE4551D2-761D-4F87-99A1-6DD1103F7B8C' \
  -derivedDataPath "$TMPDIR/TapeLogger/demo-dd" build
xcrun simctl install BE4551D2-761D-4F87-99A1-6DD1103F7B8C \
  "$TMPDIR/TapeLogger/demo-dd/Build/Products/Debug-iphonesimulator/TapeDemo.app"
xcrun simctl launch BE4551D2-761D-4F87-99A1-6DD1103F7B8C com.example.TapeDemo
```

To see the console output the way Xcode shows it (emoji badges, no escape
codes), launch through a pseudo terminal:

```sh
SIMCTL_CHILD_IDE_DISABLED_OS_ACTIVITY_DT_MODE=YES \
  xcrun simctl launch --console-pty <device> com.example.TapeDemo
```

`timeout` is not available in zsh on this machine: background the launch,
`sleep`, then `pkill -f console-pty`.

After bumping a dependency in an Xcode project, a stale module interface
causes confusing "no member" errors. Fix with a clean build folder
(`xcodebuild clean build` or ⇧⌘K), not by editing the package.

## Conventions

- Four-space indentation, 80 columns, imports alphabetical, no force unwrap,
  no `try!`, no `as!`, `.isEmpty` instead of `.count == 0`.
- Tests use Swift Testing (`@Suite`, `@Test`, `#expect`, `#require`), never
  XCTest. Test names are sentences: `@Test("Every box has the same width")`.
- Commit messages read as imperatives: `Add a demo app...`, `Narrow the
  default console box...`, `Show a pressed state...`.
- Doc comments explain *why*, and show a small usage example when the type is
  part of the public API.
- README code samples must be copy-pasteable and match the shipped API.

## Documentation

- Public API comments are required, including extension members and defaults.
- Describe implemented behavior and its scope. Do not infer platform-wide
  impossibilities, automatic privacy guarantees or unmeasured performance claims.
- Keep the Talker attribution and link in the README; API comments should explain
  TapeLogger without requiring familiarity with another package.
- Workflow guides live in the module's `.docc` catalog, not a duplicate manual.
- `python3 Scripts/build_documentation.py` builds all iOS APIs and checks comment
  coverage with DocC warnings treated as errors.
- `python3 Scripts/check_examples.py` compiles Swift examples from source
  comments, DocC articles and the README after the documentation build.
- GitHub Actions validates pull requests and publishes `/TapeLogger/api/` only
  from `main`. The website is labeled as main-branch documentation, not a release.

## Behaviour that is easy to break

- **Console width** is fixed (`maxWidth`, default 77) so a column of entries
  lines up; text wraps on spaces and hard-breaks words longer than the row.
  The renderer enforces a minimum of 24 columns and leaves the right edge open
  to tolerate terminal differences in glyph width.
- **Level badge lives inside the header row**, not before the box, so wide
  glyphs do not shift the left border.
- **Automatic ANSI detection** requires terminal stdout, a nonempty `TERM`
  other than `dumb`, and no recognized Xcode console markers. Explicit
  capabilities can select a mode without detection.
- **Color resolution**: theme override by key, then the color carried by the
  key or log type, then the level color. A key color without an emoji keeps
  the level badge.
- **`Tape.installRecommendedSinks`** skips the unified log while the Xcode
  console is detected to avoid duplicate output across destinations.
- **`TapeEntry.heading`** hides the key title when the key is the generic
  `.log`, so a plain `Tape.info` prints just `info`.

## Releasing

1. `swift test` and the iOS build of `TapeLoggerUI` must pass.
2. Update the `from:` version in README.
3. Commit, `git tag vX.Y.Z`, push `main` and the tag.
4. Tag meaning: patch for fixes and wording, minor for new API, major for
   breaking changes.
