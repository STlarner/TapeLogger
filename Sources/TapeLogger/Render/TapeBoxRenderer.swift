import Foundation

/// Formats each entry as a colored text box with an open right edge.
///
/// ```
/// ┌────────────────────────────────────────────────────────────
/// │ 🐛 debug | 22:45:55.351
/// │ Onboarding completed, routing to home
/// └────────────────────────────────────────────────────────────
/// ```
///
/// Top and bottom borders use `TapeConsoleCapabilities.maxWidth` display
/// columns, with a minimum of 24. Content wraps within that budget without
/// padding body rows. Text wraps at spaces; words wider than a row are
/// hard-broken.
///
/// The box stays open on the right because terminals disagree on some glyph
/// widths. Wrapping budgets display columns, including wide text and emoji;
/// the UI draws a real border instead.
///
/// The level badge is inside the header row so it does not shift the box's
/// left border when displayed as a wide glyph.
public struct TapeBoxRenderer: TapeTextRenderer {
    /// Whether the header includes the entry's short source location.
    public var showsSource: Bool

    /// Creates a renderer; source locations are hidden by default.
    /// - Parameter showsSource: Include file name and line in the header.
    public init(showsSource: Bool = false) {
        self.showsSource = showsSource
    }

    /// Formats all attachments and sorted metadata into an open-right box.
    /// Payload controls are escaped and physical lines normalized before
    /// display-column wrapping. Original entry content is not modified.
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
        logicalLines.append(entry.message)

        if let attachmentText = entry.attachment?.text,
           !attachmentText.isEmpty {
            logicalLines.append(attachmentText)
        }

        let metadataLine = metadataSummary(entry)
        if !metadataLine.isEmpty {
            logicalLines.append(metadataLine)
        }

        let lines = logicalLines
            .flatMap { TapeTerminalText.lines($0) }
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

    /// Minimum display-column budget for borders and content.
    static let minimumWidth = 24

    /// Breaks `text` on spaces so that no row is wider than `width`.
    ///
    /// Words are never split unless they are wider than the whole row, in
    /// which case they are hard-broken: a long URL must not blow the box
    /// open.
    static func wrap(_ text: some StringProtocol, width: Int) -> [String] {
        guard width > 0 else { return [String(text)] }
        var lines: [String] = []
        var remaining = Substring(text)

        while !remaining.isEmpty {
            var end = remaining.startIndex
            var columns = 0
            var lastSpace: String.Index?
            while end < remaining.endIndex {
                let character = remaining[end]
                let nextColumns = TapeTerminalText.columns(character)
                guard columns + nextColumns <= width else { break }
                columns += nextColumns
                if character == " " { lastSpace = end }
                end = remaining.index(after: end)
            }
            if end == remaining.endIndex {
                lines.append(String(remaining))
                break
            }
            if let space = lastSpace, space != remaining.startIndex {
                lines.append(String(remaining[remaining.startIndex..<space]))
                remaining = remaining[remaining.index(after: space)...]
            } else {
                // Always advance, even if a glyph exceeds a caller's width.
                if end == remaining.startIndex {
                    end = remaining.index(after: end)
                }
                lines.append(String(remaining[..<end]))
                remaining = remaining[end...]
            }
        }
        return lines.isEmpty ? [""] : lines
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
