import Foundation

/// Talker-style box: one entry, one rectangle.
///
/// ```
/// ┌────────────────────────────────────────────────────────────
/// │ 🐛 debug | 22:45:55.351
/// │ Onboarding completed, routing to home
/// └────────────────────────────────────────────────────────────
/// ```
///
/// Every box is exactly as wide as `TapeConsoleCapabilities.maxWidth`, so a
/// column of entries reads as a list instead of a ragged stack. Text that
/// does not fit wraps onto the next row on a space boundary, keeping the
/// gutter; a single word longer than the box is hard-broken.
///
/// The box is deliberately open on the right: closing it would require
/// counting terminal columns, which breaks with wide characters and emoji.
/// The UI draws a real border instead.
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
        let width = max(Self.minimumWidth, context.capabilities.maxWidth)
        let textWidth = max(1, width - 2)

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

        var logicalLines = [header]
        logicalLines.append(
            contentsOf: entry.message.split(
                separator: "\n",
                omittingEmptySubsequences: false
            ).map(String.init)
        )

        if case .http(let exchange) = entry.attachment,
           !exchange.bodyText.isEmpty {
            logicalLines.append(contentsOf: exchange.bodyText.components(
                separatedBy: "\n"
            ))
        }

        let metadataLine = metadataSummary(entry)
        if !metadataLine.isEmpty {
            logicalLines.append(metadataLine)
        }

        let lines = logicalLines
            .flatMap { Self.wrap($0, width: textWidth) }
            .map { "│ " + $0 }

        var block = (
            ["┌" + String(repeating: "─", count: width - 1)]
                + lines
                + ["└" + String(repeating: "─", count: width - 1)]
        ).joined(separator: "\n")

        if context.capabilities.mode == .ansi {
            block = "\u{001B}[38;5;\(color.ansi)m" + block + "\u{001B}[0m"
        }

        return block
    }

    /// Narrowest box worth drawing. Below this the text is just noise.
    static let minimumWidth = 24

    /// Breaks `text` on spaces so that no row is wider than `width`.
    ///
    /// Words are never split unless they are wider than the whole row, in
    /// which case they are hard-broken: a long URL must not blow the box
    /// open.
    static func wrap(_ text: some StringProtocol, width: Int) -> [String] {
        guard width > 0 else { return [String(text)] }
        guard text.count > width else { return [String(text)] }

        var lines: [String] = []
        var remaining = Substring(text)

        while remaining.count > width {
            let window = remaining.prefix(width)
            if let space = window.lastIndex(of: " "), space != remaining.startIndex {
                lines.append(String(remaining[remaining.startIndex..<space]))
                remaining = remaining[remaining.index(after: space)...]
            } else {
                lines.append(String(window))
                remaining = remaining.dropFirst(width)
            }
        }
        lines.append(String(remaining))
        return lines
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
