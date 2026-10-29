# TapeLogger

### Your app's debug console. Always within reach.

See what your app is doing while you're using it. TapeLogger brings your logs,
HTTP requests, navigation and lifecycle events into a searchable SwiftUI
console—with structured details a tap away, even without Xcode attached.

**Swift 6 · iOS 17+ · No third-party dependencies · MIT**

<table>
  <tr>
    <th>Find the signal</th>
    <th>Make yourself at home</th>
    <th>Look inside a request</th>
  </tr>
  <tr>
    <td><img src="docs/images/console-light.png" width="260" alt="TapeLogger in light mode showing HTTP, navigation, storage, payment and error entries with search and level filters"></td>
    <td><img src="docs/images/console-dark.png" width="260" alt="The same TapeLogger console in dark mode with distinct colors for log categories"></td>
    <td><img src="docs/images/http-details.png" width="260" alt="An expanded HTTP entry with timing, sanitized request headers, response headers and a JSON response body"></td>
  </tr>
</table>

*Real SwiftUI views from the demo, populated with sample data.*

```swift
import TapeLogger

Tape.info("Loaded the catalog", metadata: ["items": 24, "cached": false])
Tape.warning("Image cache miss", key: .storage)
Tape.notice("Checkout completed", metadata: ["orderID": "demo-42"])
```

## Less digging. More debugging.

- **Reproduce a bug and inspect it on the spot.** Open the console from a
  floating button, a shake, or your own debug menu.
- **Get past “something failed.”** Expand an entry for metadata, source,
  error details and HTTP payloads. Copy the full entry into a bug report.
- **Find the entry you need.** Search messages, errors, headers, bodies and
  source filenames, then narrow the timeline by level.
- **See the journey, not just the error.** Bring navigation, app lifecycle
  and opted-in network activity into the same timeline as your own logs.
- **Spot slow work.** Measure a sync or async operation and see its duration
  alongside the event.
- **Make important events recognizable.** Give payments, sync, or any app
  feature its own log type, color and badge.

Log once, then read the same entries in the in-app console, Xcode, a terminal,
or Apple's unified log. Use just the core logger, or add the UI and adapters
when you need them.

[Get started](#get-started) · [Examples](#put-it-to-work) ·
[Network logging](#inspect-your-http-traffic) · [Full guide](docs/Guide.md)

## Get started

Add TapeLogger with Swift Package Manager:

```swift
.package(url: "https://github.com/STlarner/TapeLogger.git", from: "0.10.0")
```

Choose the products your app needs:

| Product | What you get |
| --- | --- |
| `TapeLogger` | Structured logs, in-memory history, console output and unified logging |
| `TapeLoggerUI` | The searchable SwiftUI console and presentation triggers |
| `TapeLoggerAdapters` | Opt-in URLSession, UIKit navigation and app lifecycle events |

### A working console in one small app

Add `TapeLogger` and `TapeLoggerUI` to your app target, then try this:

```swift
import Foundation
import SwiftUI
import TapeLogger
import TapeLoggerUI

@main
struct ExampleApp: App {
    init() {
        Tape.installRecommendedSinks(
            subsystem: Bundle.main.bundleIdentifier ?? "com.example.shop"
        )
    }

    var body: some Scene {
        WindowGroup {
            Button("Load the catalog") {
                Tape.info("Loaded the catalog", metadata: ["items": 24])
                Tape.warning("Image cache miss", key: .storage)
            }
            #if DEBUG
            .tapeConsole()
            #endif
        }
    }
}
```

Run the app, tap **Load the catalog**, then tap the edge handle to reveal the
floating debug button. Tap it again to open your logs. Drag the button wherever
it suits you, or tuck it against either edge.

Recommended sinks choose console output for debugging and private unified
logging for Release. Your in-memory history is available independently.

## Put it to work

### Turn a failed checkout into an actionable report

Keep the message readable and attach the information you'll need to diagnose
the failure:

```swift
import TapeLogger

enum CheckoutError: Error {
    case paymentDeclined
}

Tape.error(
    "Could not complete checkout",
    error: CheckoutError.paymentDeclined,
    metadata: ["orderID": "demo-42", "attempt": 2]
)
```

Expand the card to inspect the error and metadata. Search for `demo-42` to find
the order, or `paymentDeclined` to find the failure. Copy the entry when you're
ready to share it.

### Find out where the wait is

Wrap an operation with `measure`. You get its result as usual, plus a log entry
with the elapsed time—even if the operation throws.

```swift
import Foundation
import TapeLogger

func loadCatalog(from url: URL) async throws -> Data {
    let (data, _) = try await Tape.measure("Load catalog") {
        try await URLSession.shared.data(from: url)
    }
    return data
}
```

It works with synchronous code too, and async measurements preserve your
calling actor's isolation.

### Inspect your HTTP traffic

See the URL, status, duration, sanitized headers and optional body previews
without adding log calls around every request. Connect one adapter to a
session, then use that session normally:

```swift
import Foundation
import TapeLoggerAdapters

@MainActor
final class DebugNetwork {
    let adapters = TapeAdapters()
    let session: URLSession

    init() throws {
        let network = TapeURLSessionAdapter(options: TapeNetworkOptions(
            allowedHosts: ["api.example.com"],
            logsBodies: true
        ))
        try adapters.install(network)

        let configuration = URLSessionConfiguration.default
        network.configure(configuration)
        session = URLSession(configuration: configuration)
    }

    func stop() {
        adapters.removeAll()
    }
}
```

Keep `DebugNetwork` alive while using its session; call `stop()` when finished.
Request and response entries share a request ID, so you can search for the
whole exchange. Body previews are opt-in and size-limited; sensitive headers
and common credential query parameters are redacted.

Use body previews with test data: body contents are not automatically
redacted. See the [network setup, privacy and request scope](docs/Guide.md#urlsession)
before connecting a session with custom transport or authentication needs.

### Follow a user's route through your app

Log SwiftUI path changes and scene activity alongside your app's own events:

```swift
import SwiftUI
import TapeLoggerUI

struct CatalogNavigation: View {
    @State private var path: [Int] = []

    var body: some View {
        NavigationStack(path: $path) {
            Button("Open product 42") { path.append(42) }
                .navigationDestination(for: Int.self) { id in
                    Text("Product \(id)")
                }
        }
        .tapeNavigation(path: $path, name: "shop") { "Product \($0)" }
        .tapeSceneLifecycle(name: "shop")
    }
}
```

Now the timeline can tell you which screen opened before a failed request,
or whether the scene went inactive during an operation. Working with UIKit?
There are [navigation](docs/Guide.md#uikit-navigation) and
[app lifecycle](docs/Guide.md#ownership-and-app-lifecycle) adapters too.

### Give your app's events their own identity

Define the style and metadata once. Every payment event gets the same badge,
color and structured details:

```swift
import TapeLogger

struct PaymentLog: TapeLog {
    let message: String
    let amount: Double

    var title: String { "payments" }
    var color: TapeColor? {
        TapeColor(light: 0x7B1FA2, dark: 0xBF7FFF, ansi: 135, emoji: "💳")
    }
    var metadata: [String: TapeValue] {
        ["amount": .double(amount), "currency": "USD"]
    }
}

Tape.log(PaymentLog(message: "Annual plan purchased", amount: 49))
```

In Xcode, that becomes a recognizable entry like this (cropped for display):

```text
┌──────────────────────────────────────────────────
│ 💳 info · payments | 21:30:34.584
│ Annual plan purchased
│ amount=49.0, currency=USD
└──────────────────────────────────────────────────
```

The same event becomes a colored card in the app and colored output in a
compatible terminal. Customize the shared `TapeTheme` to match your app's
look across light and dark appearances—without changing logging call sites.

## Open it your way

| Trigger | Best for |
| --- | --- |
| `.button` | A draggable, dockable shortcut while developing |
| `.shake` | A clean interface with a physical-device shake gesture |
| `.none` | Your own debug menu or presentation of `TapeConsoleView()` |

Pass the trigger to `.tapeConsole(trigger:)`. Keep the modifier inside
`#if DEBUG`, as in the quick start, when the console is for development only.

## Try the demo

Open **[Demo/TapeDemo.xcodeproj](Demo/TapeDemo.xcodeproj)** and run it. Explore
five tabs: **Logs**, **Network**, **SwiftUI**, **UIKit**, and **Lifecycle**.
Try a request, push a screen, background the app, then open the console to
see those events together.

The demo includes custom logs, measurements, live GET/POST requests, failures,
redaction, navigation changes and the movable console button. It's a local
example app, not an extra dependency in your project.

## Go deeper

- [Configuration, themes and output destinations](docs/Guide.md)
- [Console delivery, flushing and unified-log privacy](docs/Guide.md#output-delivery-and-privacy-v0100)
- [Adapter setup and supported capture scope](docs/Guide.md#automatic-event-sources)
- [Build, test and refresh the screenshots](docs/Screenshots.md)
- [Roadmap](ROADMAP.md)

TapeLogger's core is UI-free, with bounded in-memory history and no third-party
dependencies. Add the pieces you need and keep your existing app architecture.

## License

[MIT](LICENSE)
