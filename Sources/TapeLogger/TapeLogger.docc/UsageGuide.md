# Usage guide

Configure loggers, present the console, and connect optional event sources.

This guide is built from `main`. For a released package, check its version's
source comments and release notes before using newly added API.

## Presentation modes

One entry keeps its identity across destinations. TapeLogger chooses a
presentation for each environment automatically:

| Destination | How it looks |
| --- | --- |
| Compatible terminal detected | ANSI 256 color |
| Xcode console or non-terminal stdout | emoji badge |
| In-app UI | full color, light and dark |

Distinct badges help you recognize each level at a glance:

| Level | Badge | Level | Badge |
| --- | --- | --- | --- |
| trace | 🔍 | warning | ⚠️ |
| debug | 🐛 | error | ❌ |
| info | ℹ️ | critical | 🔥 |
| notice | 📣 | fault | 💀 |

## Console output

Boxes use a fixed display-column budget of 77 by default, with a minimum of 24.
Automatic detection caps the default to reported terminal widths of at least
40 columns. Borders use that width; body rows are not padded. Text wraps at
spaces, and words wider than a row are hard-broken.

```swift
import TapeLogger

let capabilities = TapeConsoleCapabilities(mode: .emoji, maxWidth: 72)
```

Wrapping accounts for wide characters, combining marks and emoji clusters.
Ambiguous-width characters use one column; individual terminals can choose
different glyph widths. The right edge stays open on purpose to tolerate those
differences. The in-app UI draws a full border instead.

Payload terminal controls are escaped in all color modes. LF, CRLF and CR
line endings retain the gutter, including in metadata and attachments. Only
renderer-generated color codes are emitted as ANSI.

The boxes in this document are cropped for readability.

## Installation

```swift
.package(url: "https://github.com/STlarner/TapeLogger.git", from: "0.10.0")
```

Products: `TapeLogger` (core, no dependencies), `TapeLoggerUI` (SwiftUI), and
`TapeLoggerAdapters` (opt-in event sources).

TapeLogger supports iOS 17 and later.

## Setup

```swift
import Foundation
import SwiftUI
import TapeLogger
import TapeLoggerUI

@main
struct ExampleApp: App {
    init() {
        Tape.installRecommendedSinks(
            subsystem: Bundle.main.bundleIdentifier ?? "com.example.app"
        )
    }

    var body: some Scene {
        WindowGroup {
            Text("Example app")
                #if DEBUG
                .tapeConsole()
                #endif
        }
    }
}
```

`installRecommendedSinks` picks the destinations for the current environment:

- **Debug build in Xcode** → console boxes with recognizable emoji badges.
- **Release build** → unified logging with private message content.
- **Debug build outside Xcode** → console and unified logging, with ANSI
  colors when connected to a compatible terminal.

Recommended sinks avoid duplicate output in Xcode. You can also choose
destinations explicitly:

```swift
import TapeLogger

Tape.shared.removeAllSinks()
Tape.shared.addSink(TapeConsoleSink())
Tape.shared.addSink(
    TapeOSLogSink(subsystem: "com.example.app", category: "app")
)
```

TapeLogger forwards entries to unified logging. It does not import existing
unified-log entries or intercept third-party `os_log` or `print` calls.

### Output delivery and privacy

`TapeConsoleSink` renders and writes stdout on a serial worker, so its `record`
method does not wait for terminal I/O. Each console sink queues at most
`maximumPendingEntries` (default 256), plus the entry currently being written.
When full, it drops
**new console entries**, not history in `TapeStore`. Copies of a sink share
the worker and `droppedEntryCount`. Entries accepted by that worker retain
enqueue order. Custom renderers must not log back into console output; those
recursive console deliveries are suppressed.

Retain the sink and await `flush()` when output must finish before continuing:

```swift
import TapeLogger

func writeFinalMessage() async {
    let console = TapeConsoleSink(maximumPendingEntries: 512)
    let tape = Tape(sinks: [console])
    tape.info("Finished")
    await console.flush()
}
```

`flush()` suspends until the worker is idle; a stalled stdout reader can keep
it suspended. Do not call it from a renderer. Process termination does not
automatically flush queued output.

**Unified-log messages are private by default**, including the recommended
Release setup. This policy covers the entire formatted entry: message,
metadata, duration and attachments. For non-sensitive diagnostics that must
remain readable in Console.app, explicitly opt in:

```swift
import TapeLogger

let publicLog = TapeOSLogSink(
    subsystem: "com.example.app", privacy: .public
)
```

Public output can expose personal data and credentials. Network redaction is
not a substitute for reviewing arbitrary messages and bodies. The in-memory
store, copied text and stdout are not protected by OSLog privacy annotations;
avoid recording sensitive content in the first place. Unified logging also
has platform-controlled message-size limits; the store keeps the full entry.

## Usage

```swift
import TapeLogger

// Levels match os.Logger: trace, debug, info, notice, warning, error,
// critical, fault.
Tape.debug("cache hit", metadata: ["key": "feed"])
Tape.notice("session refreshed")

// Measure synchronous work without changing its return value.
let sorted = Tape.measure("Sort") { [3, 1, 2].sorted() }
```

Use `Tape.log(...)` for a custom log type or when the level comes from a
variable, and the level-specific helpers otherwise.
`Tape.error(_:error:)` keeps the error description as an expandable
attachment instead of appending it to the message. Built-in text destinations
include that attachment, along with stack traces and custom payloads.
Async `measure` preserves the calling actor's isolation, including main-actor
work and non-Sendable results.

## Custom log types

A log type defines a header, level, color and badge once, so call sites can
focus on the event being recorded.

```swift
import TapeLogger

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

Tape.log(NavigationLog("Open settings"))
```

```
┌────────────────────────────────────────────────────────────────────────────
│ 🧭 debug · route | 21:30:34.584
│ Open settings
└────────────────────────────────────────────────────────────────────────────
```

Only `message` and `title` are required; `level` is `.info` by default and
`color` falls back to the level color. `key` defaults to `title` and is the
category identity used for theme overrides.

A type can also carry its own severity, which is how a warning or an error
keeps its level without giving up the header:

```swift
import TapeLogger

struct SyncLog: TapeLog {
    let message: String
    let level: TapeLevel
    var title: String { "sync" }
}

Tape.log(SyncLog(message: "push failed", level: .error))
```

Override a category's color without changing its log type or call sites:

```swift
import TapeLogger
import TapeLoggerUI

var theme = TapeTheme.default
theme.keys["route"] = TapeColor(light: 0x0B6E99, dark: 0x64D2FF, ansi: 80, emoji: "🗺️")
let console = TapeConsoleView(theme: theme)
```

This example applies the theme to one console view. Pass the same theme to
each console view and `TapeConsoleSink` that should use it; configuring a view
does not update text sinks.

For one-off calls, the level helpers also accept a key, either one of the
built-ins (`.httpRequest`, `.httpResponse`,
`.httpError`, `.navigation`, `.storage`, `.lifecycle`) or your own:

```swift
import TapeLogger

let payments = TapeKey("payments", level: .notice)
Tape.notice("charged 12.00", key: payments)
```

## UI

```swift
import SwiftUI
import TapeLoggerUI

struct DebugRoot: View {
    var body: some View {
        Text("Example")
            #if DEBUG
            .tapeConsole(trigger: .shake)
            #endif
    }
}
```

`trigger` chooses how the console opens:

- `.button` (default): draggable floating button, initially half-hidden at the
  right edge, raised above bottom bars. The docked handle shows an inward arrow:
  tap it to reveal the full ladybug button, then tap again to open the console.
  Drop it near the left or right edge to tuck half of it off-screen. Drag the
  visible half inward to reveal it again; dropping it in the interior leaves
  it fully visible there. Position is kept while the button is mounted and
  adapts to rotation/resizing, but is not persisted across app launches.
  VoiceOver actions can dock or reveal the button without a drag.
- `.shake`: shake the device, nothing visible on screen. In Simulator, choose
  **Device > Shake**.
- `.none`: no trigger, present `TapeConsoleView()` yourself.

The screen offers search, a filter per level and cards that expand to show
metadata, source and attachments. It stays in sync with new entries and
scrolls to the newest one when it opens.
Search includes attachment details, HTTP headers/bodies and source filenames.
Level filters announce whether they are included or excluded to accessibility.
Clear resets consoles consuming the same store and rejects buffered pre-clear
entries.

## Automatic event sources

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
record launch or termination, or monitor battery, thermal or other device state.

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

The built-in keys give requests and successful responses the same HTTP color,
with distinct 📤 / 📥 badges; HTTP failures use the error color. Expanded cards
show separately labeled request and response headers and bodies. Redacted
headers and captured bodies also appear in console boxes and copied text, with
the same preview limits. Theme overrides can change category colors and badges.

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

**Adapter scope and transport limitations:**

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
- Libraries using URLSession can opt in through the session's configuration,
  subject to the same transport limitations.

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

Observe a SwiftUI navigation path directly:

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

The same modifier accepts `Binding<NavigationPath>`. For opaque paths, this
adapter reports depth changes and same-depth replacements, not destination
names. A replacement with a different depth is reported as a push/pop.

SwiftUI logging describes **path state changes**, not animation completion;
multiple mutations can be coalesced in one update. Unbound `NavigationLink`
destinations, sheets, covers and tab selections are not automatically tracked.

## Demo

`Demo/` holds a small SwiftUI app that is not included in the package products.

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
  back gestures.
- **Lifecycle:** real app transitions, current scene state, recent events and
  an application-observer toggle. Background the app and return to test it.

The console is available across tabs. Network examples contact public HTTPS
test services and require connectivity; their availability is not guaranteed.

## Architecture

```
Tape.log ──► TapeEntry ──┬─► TapeStore ──► AsyncStream ──► TapeConsoleView
                         └─► TapeSink[] ──► TapeConsoleSink ──► TapeTextRenderer
                                          └─► TapeOSLogSink
```

- **`TapeEntry`**: content only (level, key, message, metadata, duration,
  attachment, source). It does not know how it will be displayed.
- **`TapeSink`**: destination. `record` is synchronous and must not block; it
  is called outside the logger's locks. Concurrent calls may reach sinks in a
  different order from store history. A thread-local guard suppresses recursive
  recording into the same logger.
- **`TapeTextRenderer`**: turns an entry into text.
- **`TapeTheme`**: severity colors plus per-category overrides used by the
  built-in renderers.

Hot path: short unfair-lock sections, no actor hop and no task per log. A
console drain is scheduled once per burst. History is bounded (1000 entries
by default) and the stream uses
`.bufferingNewest(2000)`.

## License

MIT — see [LICENSE](https://github.com/STlarner/TapeLogger/blob/main/LICENSE).
