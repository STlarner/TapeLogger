# ``TapeLoggerAdapters``

Opt-in network, UIKit navigation, and application lifecycle event sources.

## Overview

This reference tracks **main**, including changes not yet released. Installation
and removal are main-actor operations. Retain the adapter owner and explicitly
remove its sources when finished; deinitialization is not a substitute for
restoring delegates or stopping capture.

```swift
import Foundation
import TapeLoggerAdapters

@MainActor
final class NetworkLogging {
    let adapters = TapeAdapters()
    let session: URLSession

    init() throws {
        let network = TapeURLSessionAdapter(options: TapeNetworkOptions(
            allowedHosts: ["api.example.com"]
        ))
        try adapters.install(network)
        let configuration = URLSessionConfiguration.default
        network.configure(configuration)
        session = URLSession(configuration: configuration)
    }

    func stop() { adapters.removeAll() }
}
```

Network capture applies only to configured foreground sessions and allowed
HTTP(S) hosts. One network adapter can be active per process. Bodies are off by
default and bounded when enabled; body contents are not automatically redacted.
The forwarding transport does not reproduce custom authentication delegates,
TLS policy, cookie/cache stores, or other custom transport settings.

UIKit navigation observes completed stack transitions and forwards the prior
delegate's optional callbacks. Lifecycle observation records app notifications;
SwiftUI scene and path modifiers are provided by `TapeLoggerUI` instead.

## Topics

### Ownership

- ``TapeAdapter``
- ``TapeAdapters``

### Network

- ``TapeURLSessionAdapter``
- ``TapeNetworkOptions``

### UIKit

- ``TapeNavigationAdapter``
- ``TapeLifecycleAdapter``
