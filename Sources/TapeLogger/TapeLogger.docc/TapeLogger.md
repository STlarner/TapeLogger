# ``TapeLogger``

Thread-safe structured logging, bounded history, and configurable destinations.

## Overview

This reference tracks **main**, including changes not yet released. Declarations
and API descriptions are generated from the Swift source in this build.

```swift
import TapeLogger

let logger = Tape(sinks: [])
logger.debug("Cache hit", metadata: ["key": "feed"])
let entries = logger.store.snapshot()
```

Use the static `Tape` methods for the shared logger, or create independent
instances for tests and components. The core imports no UI framework and has
no package dependencies. The `TapeLoggerUI` and `TapeLoggerAdapters` modules
add the optional console and event sources.

## Topics

### Getting started

- <doc:UsageGuide>

### Recording and retaining entries

- ``Tape``
- ``TapeEntry``
- ``TapeSource``
- ``TapeStore``
- ``TapeLevel``
- ``TapeKey``
- ``TapeLog``
- ``TapeValue``

### Structured details

- ``TapeAttachment``
- ``TapeHTTPExchange``

### Destinations and rendering

- ``TapeSink``
- ``TapeConsoleSink``
- ``TapeOSLogSink``
- ``TapeTextRenderer``
- ``TapeBoxRenderer``
- ``TapeRenderContext``
- ``TapeConsoleCapabilities``

### Presentation

- ``TapeTheme``
- ``TapeColor``
- ``TapeTimeFormatter``
