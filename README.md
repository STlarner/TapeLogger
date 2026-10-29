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
│ 📤 info · http-request | 21:30:34.584 | 584ms
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
.package(url: "https://github.com/STlarner/TapeLogger.git", from: "0.9.2")
```

Products: `TapeLogger` (core, no dependencies), `TapeLoggerUI` (SwiftUI), and
`TapeLoggerAdapters` (opt-in event sources, upcoming v0.10.0).

The latest published release is v0.9.2. The adapter and navigation APIs below
are implemented in this checkout for **v0.10.0, not yet released**. Until that
tag exists, try them through a local package reference, as the demo does.

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

- `.button` (default): draggable floating button, initially half-hidden at the
  right edge, raised above bottom bars. The docked handle shows an inward arrow:
  tap it to reveal the full ladybug button, then tap again to open the console.
  Drop it near the left or right edge to tuck half of it off-screen. Drag the
  visible half inward to reveal it again; dropping it in the interior leaves
  it fully visible there. During a drag, the arrow becomes the centered bug as
  soon as the whole button is inside the screen (22 points inward), without
  waiting for release. Position is kept while
  the button is mounted and adapts to rotation/resizing, not persisted across
  app launches. VoiceOver actions can dock or reveal the button without a drag.
- `.shake`: shake the device, nothing visible on screen. Physical device only,
  the Simulator has no such gesture.
- `.none`: no trigger, present `TapeConsoleView()` yourself.

The screen offers search, a filter per level and cards that expand to show
metadata, source and attachments. It stays in sync with new entries and
scrolls to the newest one when it opens.

## Automatic event sources (upcoming v0.10.0)

One explicit connection per source, then automatic entries. No swizzling,
global navigation hooks, or third-party dependencies. Adapters accept a custom
`Tape` instance; `.shared` is the default.

### Ownership and app lifecycle

Add the `TapeLoggerAdapters` product to the app target. Installation and removal
run on the main actor. Keep one owner for the lifetime of the app:

```swift
import TapeLogger
import TapeLoggerAdapters

@MainActor
final class LoggingSources {
    let adapters = TapeAdapters()

    init() throws {
        try adapters.install(TapeLifecycleAdapter())
    }

    func stop() {
        adapters.removeAll()
    }
}
```

The owner retains installed adapters; installing the same instance twice does
nothing. `removeAll()` uninstalls in reverse order and can be called repeatedly.
Call it before releasing the owner; do not rely on deinitialization to restore
delegates or stop network capture. Individual adapters also expose
`install()` / `uninstall()` when the app manages their lifetime itself.

`TapeLifecycleAdapter` (UIKit platforms) observes foreground, background,
active and inactive application notifications under `.lifecycle`. It does not
infer launch or termination: iOS may kill an app without a callback. No battery,
thermal, or other device-state monitoring is installed.

For SwiftUI windows, attach `.tapeSceneLifecycle(name: "main")` to the root view.
It records the initial `scenePhase` and subsequent changes, with `scope: scene`
and the supplied name. App and scene events are distinct, not duplicates; use
stable, different names for multiple windows.

### URLSession

Install one network adapter and opt in each session **before creating it**:

```swift
import Foundation
import TapeLoggerAdapters

@MainActor
func makeLoggedSession(adapters: TapeAdapters) throws -> URLSession {
    let network = TapeURLSessionAdapter(
        options: TapeNetworkOptions(
            allowedHosts: ["api.example.com"]
        )
    )
    try adapters.install(network)

    let configuration = URLSessionConfiguration.default
    network.configure(configuration)
    return URLSession(configuration: configuration)
}
```

Use the returned session normally, including `data(for:)` and `data(from:)`.
The adapter logs `.httpRequest`, then `.httpResponse` or `.httpError`, with a
shared `requestID`, duration and an HTTP attachment. HTTP 4xx/5xx are logged as
errors but are still returned normally; transport failures and cancellation
retain URLSession's throwing behavior. Redirect hops are separate exchanges,
with redirect handling passed back to the original session.

Requests and successful responses share the HTTP color, with distinct 📤 / 📥
badges; HTTP failures remain red. Expanded cards show separately labeled
request and response bodies. Captured bodies also appear in console boxes and
copied text, with the same preview limits.

**Privacy defaults:**

- Bodies are off by default. `logsBodies: true` enables text/JSON/XML/form
  previews, capped at `bodyLimit` (8 KB by default). Response data is forwarded
  incrementally; only the bounded preview is retained. The app still receives
  the entire response. Complete JSON is pretty-printed if it fits the cap.
- Authorization, proxy authorization, cookies, set-cookie and `X-API-Key`
  headers are redacted case-insensitively. Add names with `redactedHeaders`.
- URL user/password and fragments are removed. Common sensitive query names
  (including `token`, `access_token`, `api_key`, `password` and `code`) are
  redacted; extend this with `redactedQueryItems`.
- **Body contents, URL paths and arbitrary query names are not automatically
  sanitized.** An echoed credential in a response body is still a credential.
  Enable bodies only for appropriate test data.

**Deliberate URLProtocol limitations:**

- There is one active network adapter per process, shared by all opted-in
  sessions. A second instance cannot install until the first is removed.
  Settings are snapshotted per request. Removal stops new interceptions;
  in-flight requests finish using their original settings.
- Only HTTP(S) in configured foreground sessions is observed. `allowedHosts`
  matches exact hosts, case-insensitively; an empty set allows all hosts.
  Other hosts pass through untouched. `URLSession.shared`, existing sessions,
  WebSockets, background sessions and traffic from other stacks are not covered.
- Intercepted requests are forwarded by a standard internal URLSession. The
  original session's custom transport configuration, cookies/cache stores,
  proxy/TLS policy, custom authentication delegates, client certificates and
  task metrics are **not** transparently reproduced. Do not opt in sessions
  that depend on those features. This is a debugging transport, not a
  drop-in production network interceptor.
- URLSession can expose ordinary POST data as a stream. With body capture
  enabled, a finite stream with a known `Content-Length` within `bodyLimit` is
  buffered and replaced with the exact captured bytes before forwarding.
  Larger or unknown-size streams are forwarded untouched, with an explicit
  explanation instead of a misleading empty preview. Live streamed uploads
  and general stream replay/retry remain unsupported.
- No Alamofire-specific monitor or dependency is included. A library using a
  URLSession can opt in through that session's configuration, subject to the
  same limitations; this is not a guarantee of all Alamofire features.

### UIKit navigation

```swift
import TapeLoggerAdapters
import UIKit

@MainActor
func observeNavigation(
    _ navigationController: UINavigationController,
    adapters: TapeAdapters
) throws {
    try adapters.install(
        TapeNavigationAdapter(
            navigationController: navigationController,
            name: "main"
        )
    )
}
```

Install once per navigation controller. Stack changes are compared in
`didShow`: pushes, pops, pop-to-root and replacements produce `.navigation`
entries; a cancelled interactive pop does not. Destination names default to
the controller's type; pass `describe:` to customize them without logging
sensitive screen content.

The adapter forwards the existing delegate's optional methods, including
animation/interaction delegates, and restores it on removal. The app must keep
its original delegate alive as usual. If the app replaces the navigation
delegate later, observation stops; removal will not overwrite that replacement.
This does not globally capture modal presentations or every controller's
appearance/disappearance.

### SwiftUI navigation

No router or proprietary route protocol is required:

```swift
import SwiftUI
import TapeLoggerUI

struct RoutesExample: View {
    @State private var routes: [Int] = []

    var body: some View {
        NavigationStack(path: $routes) {
            Button("Open detail") { routes.append(1) }
                .navigationDestination(for: Int.self) { number in
                    Text("Detail \(number)")
                }
        }
        .tapeNavigation(path: $routes, name: "main") { "Detail \($0)" }
    }
}
```

Attach once per stack. Typed paths distinguish prefix pushes/pops from
replacements, including multi-route deep links and reset-to-root. `describe:`
controls the destination name; the default is `String(describing:)`.

The same modifier accepts `Binding<NavigationPath>`, but that type hides its
elements: only depth changes and same-depth replacements can be reported, not
destination names. A replacement with a different depth looks like a push/pop.

SwiftUI logging describes **path state changes**, not animation completion;
multiple mutations can be coalesced in one update. Unbound `NavigationLink`
destinations, sheets, covers and tab selections are not automatically tracked.

## Demo

`Demo/` holds a small SwiftUI app that is **not part of the package**: SwiftPM
only ships what is under `Sources/`, so nothing here reaches the consumers.

Open `Demo/TapeDemo.xcodeproj` and run it on a simulator or a device. The
app has five tabs:

- **Logs:** all levels, custom types, metadata, measurements and console trigger.
- **Network:** live GET/POST, redacted headers/query, 404, redirect, truncated
  JSON, binary response, DNS failure, an excluded host and cancellation. Toggle
  capture and body previews; the demo enables previews by default with a
  512-byte cap. The library default remains body capture off.
- **SwiftUI:** typed route arrays and opaque `NavigationPath`; push/pop,
  multi-push, reset and replacement.
- **UIKit:** a real navigation controller, stack operations and interactive
  back gestures. Its original delegate sets a prompt to demonstrate forwarding.
- **Lifecycle:** real app transitions, current scene state, recent events and
  an application-observer toggle. Background the app and return to test it.

The console is available across tabs. Network examples contact public HTTPS
test services and require connectivity; their availability is not guaranteed.
Launch with `--console-smoke` to seed 150 history entries and open the console
directly; the final "Newest console entry" should be visible without scrolling.

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

macOS runs the core, network and navigation-state tests. The UIKit adapter
suites require an iOS test destination; `build-for-testing` can compile them
without launching a simulator.

`Package.swift` declares `.macOS(.v14)` only so the tests can run locally: the
supported target is iOS 17+.

## Roadmap

Short version, in the order it will be tackled:

- [x] Adapters, lifecycle, opt-in URLSession logging (unreleased v0.10.0)
- [x] UIKit and SwiftUI navigation utilities (unreleased v0.10.0)
- [ ] Console: filter by key, pause, entry detail, export
- [ ] File persistence (`TapeFileSink`) and loading a saved session
- [ ] Signposts, CI, DocC

The full list, with the decisions already taken and the non-goals, lives in
[ROADMAP.md](ROADMAP.md).

## License

MIT — see [LICENSE](LICENSE).
