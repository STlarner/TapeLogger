import Foundation

/// An opt-in event source. Installation and removal happen on the main actor;
/// the source may record entries from any thread.
///
/// Retain installed adapters, or let ``TapeAdapters`` retain them. Always
/// uninstall before releasing them so delegates and observers are restored.
@MainActor
public protocol TapeAdapter: AnyObject {
    /// Starts observation. Implementations should tolerate repeated installation
    /// of the same instance and throw if they cannot acquire a required resource.
    func install() throws
    /// Stops new observation and restores hooks when still owned by this adapter.
    /// Call explicitly before releasing an installed adapter.
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

    /// Creates an empty main-actor owner without installing any event sources.
    public init() {}

    /// Installs and retains an adapter only after successful installation.
    /// Reinstalling an already-owned instance does nothing.
    /// - Parameter adapter: Event source to retain until removal.
    /// - Throws: The adapter's installation error; failed sources are not retained.
    public func install(_ adapter: any TapeAdapter) throws {
        guard !installed.contains(where: { $0 === adapter }) else { return }
        try adapter.install()
        installed.append(adapter)
    }

    /// Uninstalls retained adapters in reverse order and releases ownership.
    /// Safe to call repeatedly. This does not clear recorded history.
    public func removeAll() {
        let adapters = installed.reversed()
        installed.removeAll()
        for adapter in adapters {
            adapter.uninstall()
        }
    }
}
