import Foundation

/// Talker-style box: one entry, one rectangle.
///
/// ```
/// ┌──────────────────────────────────────────────────
/// │ 🟠 http-request | 21:30:34.584 | 584ms
/// │ GET https://jsonplaceholder.typicode.com/users/1
/// └──────────────────────────────────────────────────
/// ```
///
/// The box is deliberately open on the right: closing it requires padding
/// to a fixed column, which breaks with wide characters and emoji. The UI
/// draws a real border instead.
///
/// The level badge lives inside the header row, not before the border. An
/// emoji glyph takes two terminal columns but counts as one `Character`, so
/// prefixing the whole block shifts `┌` one column away from the `│` below
/// it: the box stops lining up.
public struct TapeBoxRenderer: TapeTextRenderer {
    public var showsSource: Bool

    public init(showsSource: Bool = false) {
        self.showsSource = showsSource
    }

    public func render(_ entry: TapeEntry, context: TapeRenderContext) -> String {
        let color = context.theme.color(for: entry)

        var header = "\(entry.heading) | \(TapeTimeFormatter.string(from: entry.date))"
        if let duration = entry.duration {
            header += " | \(duration.tapeMilliseconds)ms"
        }
        if showsSource, let source = entry.source {
            header += " · \(source.short)"
        }
        if context.capabilities.mode == .emoji {
            header = "\(context.theme.emoji(for: entry) ?? "•") \(header)"
        }

        let messageLines = entry.message.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )

        var lines = ["│ " + header]
        lines.append(contentsOf: messageLines.map { "│ " + $0 })

        let metadataLine = metadataSummary(entry)
        if !metadataLine.isEmpty {
            lines.append("│ " + metadataLine)
        }

        let width = min(context.capabilities.maxWidth, lines.map(\.count).max() ?? 0)
        lines = lines.map { String($0.prefix(width)) }

        var block = (
            ["┌" + String(repeating: "─", count: width)]
                + lines
                + ["└" + String(repeating: "─", count: width)]
        ).joined(separator: "\n")

        if context.capabilities.mode == .ansi {
            block = "\u{001B}[38;5;\(color.ansi)m" + block + "\u{001B}[0m"
        }

        return block
    }

    /// `key=feed, retry=3` — greppable, one line, keys sorted.
    private func metadataSummary(_ entry: TapeEntry) -> String {
        guard !entry.metadata.isEmpty else { return "" }
        return entry.metadata
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.description)" }
            .joined(separator: ", ")
    }
}
