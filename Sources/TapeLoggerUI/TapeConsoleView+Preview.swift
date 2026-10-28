import SwiftUI
import TapeLogger

#if DEBUG
extension TapeStore {
    static var preview: TapeStore {
        let store = TapeStore()
        store.append(
            TapeEntry(
                level: .info,
                key: .httpRequest,
                message: "[GET] https://jsonplaceholder.typicode.com/users/1",
                duration: .milliseconds(584)
            )
        )
        store.append(
            TapeEntry(level: .debug, key: .navigation, message: "push(productsList)")
        )
        store.append(
            TapeEntry(
                level: .warning,
                message: "Trying to re-register an object in Resolver",
                metadata: ["key": "repositories", "scope": "singleton"]
            )
        )
        store.append(
            TapeEntry(
                level: .error,
                message: "Decoding failed: keyNotFound(userId)",
                metadata: ["endpoint": "/users/1", "status": 500]
            )
        )
        return store
    }
}

#Preview("Tape Console") {
    TapeConsoleView(store: .preview)
}
#endif
