# Roadmap

Where TapeLogger stands and what comes next, in the order it was discussed.
A new session should be able to pick the first unchecked item and start.

Current release: **v0.9.1**.

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
| — | Demo app in `Demo/` (not distributed) |

## 1. Adapters module

The network, events and UI sources discussed at the beginning.

- [ ] New product `TapeLoggerAdapters`, depending on `TapeLogger` only.
- [ ] `public protocol TapeAdapter` with `install()`, `uninstall()` and a
      documented retention story: who holds the adapter, when it is removed.
      Flutter frameworks offer global observers; Apple's do not, so an adapter
      is a *source* that calls `Tape.record`, not a replacement for the API.
- [ ] Register installed adapters so `Tape` can uninstall them all
      (`Tape.removeAllAdapters()`), for tests and for "disable logging" mode.
- [ ] Lifecycle adapter: app foreground/background, memory warnings, thermal
      state. Cheap and useful as the first adapter.

## 2. Network logging

Decided order of attack, from least invasive to most:

- [ ] **v1 — explicit wrapper.** `Tape.session(configuration:)` returning a
      `URLSession` with a delegate-free logging transport, or
      `URLSession.data(for:)` helpers, that log request, response, status,
      duration and a truncated body as `http.request` / `http.response`.
      Explicit, opt-in per call site, no surprises.
- [ ] **v2 — `URLProtocol`.** `Tape.registerURLProtocol(in:)` for apps that
      cannot touch their call sites. Must be opt-in, must document that it
      does not see WebSocket traffic, and must not intercept more than the
      configured hosts.
- [x] **Never** swizzle `URLSession` or anything else at runtime.

Body handling rules to settle while implementing v1: size cap (start at 8 KB),
redaction of `Authorization`/`Cookie`, opt-in body logging, JSON pretty print.

## 3. In-app console

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

- [ ] GitHub Actions: `swift test` on macOS, `TapeLoggerUI` build for iOS,
      demo build. Keep it single-workflow and fast.
- [ ] DocC catalog for `TapeLogger` with articles mirroring the README
      sections: setup, custom log types, console capabilities.
- [ ] Screenshots in the README (console in light/dark, demo app).

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
