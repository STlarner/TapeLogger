import Foundation

/// An opt-in event source. Installation and removal happen on the main actor;
/// the source may record entries from any thread.
///
/// Retain installed adapters, or let ``TapeAdapters`` retain them. Always
/// uninstall before releasing them so delegates and observers are restored.
@MainActor
public protocol TapeAdapter: AnyObject {
    func install() throws
    func uninstall()
}

/// Owns sources independently of the logger's synchronous ingestion path.
///
/// Keep this owner for the lifetime of the app, then call ``removeAll()`` to
/// disable its sources. Installing the same instance twice is a no-op.
///
/// ```swift
/// let adapters = TapeAdapters()
/// try adapters.install(TapeLifecycleAdapter())
/// ```
@MainActor
public final class TapeAdapters {
    private var installed: [any TapeAdapter] = []

    public init() {}

    public func install(_ adapter: any TapeAdapter) throws {
        guard !installed.contains(where: { $0 === adapter }) else { return }
        try adapter.install()
        installed.append(adapter)
    }

    public func removeAll() {
        let adapters = installed.reversed()
        installed.removeAll()
        for adapter in adapters {
            adapter.uninstall()
        }
    }
}
