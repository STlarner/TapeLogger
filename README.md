# TapeLogger

Logging for iOS that you can actually see: a colored console and a browsable
SwiftUI console, rendered from the same data model.

```swift
Tape.info("app launched")
Tape.warning("cache miss", metadata: ["key": "feed", "retry": 3])
Tape.error(error)
```

```
┌──────────────────────────────────────────────────
│ 🟣 info · http-request | 21:30:34.584 | 584ms
│ GET https://jsonplaceholder.typicode.com/users/1
└──────────────────────────────────────────────────
```

## Why

Xcode's console does not support ANSI escape codes: coloring text with them
there prints raw escape sequences (and can truncate the line). So the palette
is semantic and every destination degrades it the best way it can:

| Destination | How it looks |
| --- | --- |
| Terminal / CI | ANSI 256 color |
| Xcode console | emoji badge |
| In-app UI | full color, light and dark |

The badge is a shape, not a colored circle, so levels stay distinguishable
even when the console renders every emoji the same:

| Level | Badge | Level | Badge |
| --- | --- | --- | --- |
| trace | 🔍 | warning | ⚠️ |
| debug | 🐛 | error | ❌ |
| info | ℹ️ | critical | 🔥 |
| notice | 📣 | fault | 💀 |

## Console output

Every box is exactly `TapeConsoleCapabilities.maxWidth` wide (77 characters by
default, further capped to the terminal width when stdout is a terminal), so a
run of entries lines up instead of looking like a ragged stack. Text that does
not fit wraps on a space boundary and keeps the gutter; a single word wider
than the box is hard-broken.

```swift
TapeConsoleCapabilities(mode: .emoji, maxWidth: 72)
```

The right edge stays open on purpose: closing it would require counting
terminal columns, which breaks as soon as a message contains a wide character
or an emoji. The in-app UI draws a full border instead.

The boxes in this document are cropped for readability.

## Installation

```swift
.package(url: "https://github.com/STlarner/TapeLogger.git", from: "0.9.1")
```

Products: `TapeLogger` (core, no dependencies) and `TapeLoggerUI` (SwiftUI).

## Setup

```swift
import TapeLogger

@main
struct App: App {
    init() {
        Tape.installRecommendedSinks(
            subsystem: Bundle.main.bundleIdentifier ?? "com.example.app"
        )
    }
}
```

`installRecommendedSinks` picks the destinations for the current environment:

- **Debug build** → console output only. ANSI colors in a terminal, emoji
  badges in the Xcode console, which would print escape codes as garbage.
- **Release build** → unified log only, so entries stay readable in
  Console.app, Instruments and `log stream`.
- **Debug build outside the Xcode console** (device launched from springboard,
  CI) → both, since the emoji output would otherwise go nowhere.

The unified log is skipped while the Xcode console is the destination: the
same entry would show up twice, once as a box and once as a plain
`subsystem:category` line. Build the sink list by hand if you want a different
trade-off:

```swift
Tape.shared.removeAllSinks()
Tape.shared.addSink(TapeConsoleSink())
Tape.shared.addSink(
    TapeOSLogSink(subsystem: "com.example.app", category: "app")
)
```

Forwarding to the unified log works in one direction only: reading it back is
not possible on iOS, no public framework exposes it.

## Usage

```swift
import TapeLogger

// Levels match os.Logger: trace, debug, info, notice, warning, error,
// critical, fault.
Tape.debug("cache hit", metadata: ["key": "feed"])
Tape.notice("session refreshed")

// A custom log type brings its own header, level and color (see below).
Tape.log(NavigationLog("Push RoomRoute"))

// Measured duration.
let users = try await Tape.measure("load users") { try await api.users() }
```

Use `Tape.log(...)` for a custom log type or when the level comes from a
variable, and the `trace`/`debug`/`info`/`warning`/`error`/`critical`/`fault`
helpers otherwise.
`Tape.error(_:error:)` keeps the error description as an expandable
attachment instead of appending it to the message.

## Custom log types

A log type is a struct that describes itself: header, level, color, badge.
The same shape as a custom log class in talker, and the call site never names
a level.

```swift
struct NavigationLog: TapeLog {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var title: String { "route" }
    var level: TapeLevel { .debug }
    var color: TapeColor? {
        TapeColor(light: 0x7B1FA2, dark: 0xAF5FFF, ansi: 135, emoji: "🧭")
    }
}

Tape.log(NavigationLog("Push RoomRoute"))
```

```
┌────────────────────────────────────────────────────────────────────────────
│ 🧭 debug · route | 21:30:34.584
│ Push RoomRoute
└────────────────────────────────────────────────────────────────────────────
```

Only `message` and `title` are required; `level` is `.info` by default and
`color` falls back to the level color. `key` defaults to `title` and is the
identity used for theme overrides and filtering.

A type can also carry its own severity, which is how a warning or an error
keeps its level without giving up the header:

```swift
struct SyncLog: TapeLog {
    let message: String
    let level: TapeLevel
    var title: String { "sync" }
}

Tape.log(SyncLog(message: "push failed", level: .error))
```

Because the entry keeps its key, one theme edit rebrands the stream across
the app without touching call sites:

```swift
var theme = TapeTheme.default
theme.keys["route"] = TapeColor(light: 0x0B6E99, dark: 0x64D2FF, ansi: 80, emoji: "🗺️")
```

```swift
TapeConsoleView(theme: theme)
```

For one-off calls that do not deserve a type, the level helpers still accept
a key, either one of the built-ins (`.httpRequest`, `.httpResponse`,
`.httpError`, `.navigation`, `.storage`, `.lifecycle`) or your own:

```swift
let payments = TapeKey("payments", level: .notice)
Tape.notice("charged 12.00", key: payments)
```

## UI

```swift
import TapeLoggerUI

WindowGroup {
    ContentView()
        #if DEBUG
        .tapeConsole(trigger: .shake)
        #endif
}
```

`trigger` chooses how the console opens:

- `.button` (default): floating button in the bottom right corner.
- `.shake`: shake the device, nothing visible on screen. Physical device only,
  the Simulator has no such gesture.
- `.none`: no trigger, present `TapeConsoleView()` yourself.

The screen offers search, a filter per level and cards that expand to show
metadata, source and attachments. It stays in sync with new entries and
scrolls to the newest one when it opens.

## Demo

`Demo/` holds a small SwiftUI app that is **not part of the package**: SwiftPM
only ships what is under `Sources/`, so nothing here reaches the consumers.

Open `Demo/TapeDemo.xcodeproj` and run it on a simulator or a device. The
screen has one row per level (`trace` through `fault`, including an error with
its details), a custom log type (`PaymentLog`) with its own badge and
metadata, a metadata row and a measured block. The last section chooses how
the console opens: floating ladybug button, shake, or never.

Shake needs a real device, the simulator has no motion gesture.

## Architecture

```
Tape.log ──► TapeEntry ──┬─► TapeStore ──► AsyncStream ──► TapeConsoleView
                         └─► TapeSink[] ──► TapeConsoleSink ──► TapeTextRenderer
                                          └─► TapeOSLogSink
```

- **`TapeEntry`**: content only (level, key, message, metadata, duration,
  attachment, source). It does not know how it will be displayed.
- **`TapeSink`**: destination. `record` is synchronous and must not block; it
  is called outside the locks, so it may log again (a thread-local guard
  prevents infinite recursion).
- **`TapeTextRenderer`**: turns an entry into text.
- **`TapeTheme`**: `levels` plus per-`key` overrides; renderers never hardcode
  a color.

Hot path: one unfair lock per entry, no actor and no task per log. History is
bounded (1000 entries by default) and the stream uses
`.bufferingNewest(2000)`.

## Tests

```bash
swift test
```

`Package.swift` declares `.macOS(.v14)` only so the tests can run locally: the
supported target is iOS 17+.

## Roadmap

Short version, in the order it will be tackled:

- [ ] `TapeLoggerAdapters`: `TapeAdapter` install/uninstall, lifecycle source
- [ ] Network logging: explicit `Tape.session` wrapper, then opt-in `URLProtocol`
- [ ] Console: filter by key, pause, entry detail, export
- [ ] File persistence (`TapeFileSink`) and loading a saved session
- [ ] Signposts, CI, DocC

The full list, with the decisions already taken and the non-goals, lives in
[ROADMAP.md](ROADMAP.md).

## License

MIT — see [LICENSE](LICENSE).
