# ``TapeLoggerUI``

A searchable SwiftUI console for a TapeLogger store.

## Overview

This reference tracks **main**, not a specific release. UI types and view
modifiers run on the main actor. Attach `tapeConsole` to a root view to present
the console, or present `TapeConsoleView` from your own debug UI.

```swift
import SwiftUI
import TapeLoggerUI

struct DebugExample: View {
    var body: some View {
        Text("Example")
            .tapeConsole(trigger: .button)
    }
}
```

Pass the same store as your logger when using a custom logger instance. The
console refreshes history when opened, coalesces incoming entries, and cancels
observation when its view task ends. Search includes metadata, attachment
contents, source filenames and functions. Copying an entry includes its details.

The module also adds `tapeNavigation` and `tapeSceneLifecycle` to SwiftUI views.
Navigation modifiers describe path state changes, not animation completion.

## Topics

### Console

- ``TapeConsoleView``
- ``TapeConsoleModel``
- ``TapeEntryCard``

### Presentation

- ``TapeConsoleModifier``
- ``TapeConsoleTrigger``
