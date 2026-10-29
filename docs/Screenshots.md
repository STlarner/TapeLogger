# Demo and screenshot workflow

The README screenshots are captures of the real `TapeConsoleView` and an
expanded `TapeEntryCard`, running in the iOS Simulator. Their content is
deterministic sample data, not a live network session. No production logger
or UI behavior is replaced for the captures.
Screenshot mode and its fixtures are compiled only in Debug builds and must
be explicitly enabled with `--screenshots`. Normal demo launches are unchanged.

## Run the demo

Open [TapeDemo.xcodeproj](../Demo/TapeDemo.xcodeproj) in Xcode and run the
`TapeDemo` scheme. The five tabs cover logging, network requests, SwiftUI
navigation, UIKit navigation and app lifecycle. The floating button opens the
console across tabs.

For a command-line build, run this from the repository root:

```sh
xcodebuild -project Demo/TapeDemo.xcodeproj -scheme TapeDemo \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$TMPDIR/opencode/readme-demo" build
```

Use the simulator already running. Don't boot another device just to capture
the screenshots. Check the current device with:

```sh
xcrun simctl list devices booted
```

The commands below use `booted`, which assumes exactly one simulator is
running. If several are running, replace `booted` with the chosen device UUID.

```sh
xcrun simctl install booted \
  "$TMPDIR/opencode/readme-demo/Build/Products/Debug-iphonesimulator/TapeDemo.app"
```

## Refresh the images

Run the launch command, wait for the UI to appear, then capture its screen.
Run these commands from the repository root so images land in `docs/images`.

### Console, light appearance

```sh
xcrun simctl launch --terminate-running-process booted \
  com.example.TapeDemo --screenshots
xcrun simctl io booted screenshot docs/images/console-light.png
```

### Console, dark appearance

```sh
xcrun simctl launch --terminate-running-process booted \
  com.example.TapeDemo --screenshots --dark
xcrun simctl io booted screenshot docs/images/console-dark.png
```

### Expanded HTTP entry

```sh
xcrun simctl launch --terminate-running-process booted \
  com.example.TapeDemo --screenshots --http-details
xcrun simctl io booted screenshot docs/images/http-details.png
```

Screenshot mode chooses its appearance inside the app; it does not change the
simulator's system appearance. The sample HTTP data includes a visibly
redacted authorization header and makes no network requests.

The fixtures live in
[`ScreenshotGallery.swift`](../Demo/TapeDemo/ScreenshotGallery.swift).
To return to the interactive demo, relaunch without the screenshot arguments:

```sh
xcrun simctl launch --terminate-running-process booted com.example.TapeDemo
```

## Build and test the package

```sh
swift test
xcodebuild -scheme TapeLoggerUI \
  -destination 'generic/platform=iOS Simulator' build
```

See the [guide](Guide.md#tests) for platform-specific test coverage and the
[roadmap](../ROADMAP.md) for upcoming work.
