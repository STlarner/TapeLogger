# Roadmap

Where TapeLogger stands and what comes next, in the order it was discussed.
A new session should be able to pick the first unchecked item and start.

Current release: **v0.10.0**.

Latest release: lifecycle, opt-in
URLSession logging, UIKit/SwiftUI navigation, the five-tab demo, and review
hardening. This minor version includes new console delivery/flush controls,
private-by-default configurable OSLog output and actor-aware async measurement.

Next focus: console filtering by key, pause, entry detail and export.

## Review hardening (v0.10.0)

- [x] Release removed sinks outside the logger lock and reclaim recursion TLS.
- [x] Bound asynchronous console output, expose drops and asynchronous flush.
- [x] Linear-time, display-column wrapping; escape payload terminal controls
      and normalize physical lines throughout rendered entries.
- [x] Include all attachments and sanitized HTTP headers in text destinations.
- [x] Private unified-log entries by default, with explicit public opt-in.
- [x] Generation-aware console resets, including buffered and dropped events.
- [x] Preserve async measurement actor isolation and saturate duration overflow.
- [x] Search attachment/source details, expose filter accessibility state,
      and correct integration documentation.

## Shipped

| Version | What landed |
| --- | --- |
| 0.1.0 | Core model (`TapeEntry`, `TapeLevel`, `TapeKey`, `TapeStore`), console box, `os.Logger` sink, SwiftUI console |
| 0.2.0 | Console triggers: floating button, device shake, none |
| 0.3.0 | `error(_:error:)` keeps details in an attachment instead of the message |
| 0.4.0 | Static forwarders, so `Tape.info(...)` works without `Tape.shared` |
| 0.5.0 | Close button and auto-scroll to the newest entry |
| 0.6.0 | Xcode console detection, no duplicate entries, `installRecommendedSinks` |
| 0.6.1 | Badge moved into the header, box borders aligned |
| 0.7.0 | Keys carry their own color and badge; level shown in the header |
| 0.8.0 | Fixed box width, wrapping, one badge per level |
| 0.8.1 | Default width narrowed to 77 columns, capped to the terminal width |
| 0.9.0 | `TapeLog`: app-defined log types carrying header, level and color |
| 0.9.1 | 🧭 badge for the navigation key |
| 0.9.2 | Distinct badges for the built-in keys (📤 📥 💥 💾) |
| 0.10.0 | Lifecycle/network/navigation adapters, movable console button, bounded asynchronous output, configurable private OSLog, reset-safe consoles and rendering hardening |
| — | Demo app in `Demo/` (not distributed) |

## 1. Adapters module

The network, events and UI sources discussed at the beginning.

- [x] New product `TapeLoggerAdapters`, depending on `TapeLogger` only.
- [x] `public protocol TapeAdapter` with `install()`, `uninstall()` and a
      documented retention story: who holds the adapter, when it is removed.
      Flutter frameworks offer global observers; Apple's do not, so an adapter
      is a *source* that calls `Tape.record`, not a replacement for the API.
- [x] `TapeAdapters` retains installed sources and uninstalls them with
      `removeAll()`, without adding source ownership to the core hot path.
- [x] Lifecycle adapter: app foreground/background and active/inactive.
      SwiftUI scene lifecycle is separate. No thermal, battery or memory
      monitoring: keep the initial scope focused on useful app events.

## 2. Network logging

Scope agreed for v0.10.0: URLSession only, configured once per session rather
than a wrapper at every call site. No separate Alamofire product or monitor.

- [x] `TapeURLSessionAdapter` installs an opt-in `URLProtocol` on a session
      configuration. Request/response/error, status, duration, correlation ID,
      HTTP attachment and bounded, opt-in body previews.
- [x] Exact host allowlist, header/query redaction, binary-body omission and
      JSON pretty print. Default body cap is 8 KB.
- [x] Forward cancellation and redirects; document unsupported background,
      WebSocket, custom transport/authentication and stream-replay scenarios.
- [x] Document one active network adapter per process, in-flight settings
      snapshots and bounded buffering/replay of finite, small request streams.
      Large/unknown-size streams are not consumed for logging.
- [x] Shared request/response color, labeled bodies in cards, text boxes and
      copied output, and request-body capture for ordinary small POSTs.
- [x] **Never** swizzle `URLSession` or anything else at runtime.

## 2a. Navigation

- [x] UIKit navigation-controller adapter: completed push/pop/replace events,
      delegate forwarding and safe restoration. No false pop for cancelled
      interactive transitions.
- [x] SwiftUI typed-route modifier: push/pop/reset/replace without a router
      dependency. Opaque `NavigationPath` support reports depth, not route names.
- [x] Demo tabs for both frameworks, plus network and real lifecycle cases.
- [ ] Manual iOS runtime validation of delegates, interactive gestures, scene
      transitions and the demo layout. Console startup at the newest entry was
      visually verified with 150 history entries on the running simulator.

## 3. In-app console

- [x] Draggable floating button, half-hidden snapping at either horizontal edge,
      drag-to-reveal, resize-aware placement and accessible dock/reveal actions.
- [x] Start docked above bottom bars, show an inward arrow in the visible half,
      and reveal on the first tap before opening the console on a second tap.
- [x] Open at the newest entry using a bottom default scroll anchor; refresh
      the snapshot atomically with subscription when the console opens again.
- [ ] Filter by key, not only by level chip and free text.
- [ ] Pause/resume while reading, with a "new entries" counter instead of
      snapping back to the bottom (auto-scroll exists, the pause is missing).
- [ ] Detail screen for one entry: full message, metadata, attachment
      (HTTP exchange, error, stack trace) in a scrollable sheet.
- [ ] Copy all / export the visible entries as text, then share sheet.
- [ ] Theme editing inside the app, so a designer can tune colors without a
      rebuild. Persisted in `UserDefaults`, applied over `TapeTheme.default`.

## 4. Persistence

- [ ] `TapeFileSink`: JSON Lines, size-based rotation, max number of files.
- [ ] Loading a saved file back into the console (read-only session), so a QA
      build can be inspected after the fact. Needs a decoder for `TapeEntry`,
      which is why `Codable` was not added blindly: attachments and metadata
      need a stable encoding first.
- [ ] Export via `Tape.session.snapshot()` to `.json` and `.txt`.

## 5. Performance and observability

- [ ] `os_signpost` integration: `Tape.measure` also emits a signpost
      interval, visible in Instruments without extra call sites.
- [ ] Batching for high-volume streams: a sink that coalesces N entries or T
      milliseconds before writing. Only if a real use case shows the need; the
      hot path is already lock-only.
- [ ] Sampling helper (`Tape.every(n)` or a sampling sink) for chatty loops.

## 6. Project plumbing

- [x] GitHub Actions: macOS tests, iOS documentation builds, comment coverage,
      compiled documentation examples and GitHub Pages deployment on `main`.
- [ ] Add automated demo builds and iOS test execution to CI.
- [x] DocC catalogs for all three modules, with source-generated API reference
      and a single maintained usage guide under `/TapeLogger/api/`.
- [x] Screenshots in the README (light/dark console and expanded HTTP card).

## Non-goals

Documented so nobody reopens them:

- Reading back `os_log` or `print` output produced by third parties: not
  possible on iOS, no public API exposes it.
- A global hook for uncaught Swift errors: `NSSetUncaughtExceptionHandler`
  covers Objective-C exceptions only. Errors are logged explicitly.
- ANSI colors in the Xcode console or in Console.app: neither interprets
  escape codes. The emoji badge mode is the answer.
- Swizzling any framework API.

## Open decisions

- Default console width is 77 columns (70% of the original 110). Long
  messages wrap; the value is a judgement call, easy to revisit.
- Default trigger is `.button`. `.shake` is debug-only in the sample apps and
  needs a physical device to be tested.
- `TapeLog` is the recommended way to define a stream; `key:` on the level
  helpers stays as a shortcut for one-off calls. If the two paths confuse
  users, `key:` becomes deprecated in favour of types.
- TidyMa is the first real consumer: it logs navigation through
  `NavigationLog` and deep links through `DeepLinkLog`, both defined in the
  app, not in the package. Keep it compiling against new releases.
