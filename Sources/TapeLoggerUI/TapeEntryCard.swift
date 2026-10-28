import SwiftUI
import TapeLogger

/// One log = one rectangle, colored by key (falling back to level).
///
/// The border and the header carry the color; the message stays in the text
/// color so long payloads remain readable, unlike talker's all-colored card.
@MainActor
public struct TapeEntryCard: View {
    public let entry: TapeEntry
    public var theme: TapeTheme

    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded: Bool

    public init(entry: TapeEntry, theme: TapeTheme = .default, initiallyExpanded: Bool = false) {
        self.entry = entry
        self.theme = theme
        _isExpanded = State(initialValue: initiallyExpanded)
    }

    private var tint: Color {
        theme.color(for: entry).color(for: colorScheme)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header

            Text(entry.message)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(theme.text.color(for: colorScheme))
                .lineLimit(isExpanded ? nil : 2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isExpanded {
                details
            }
        }
        .padding(10)
        .background(theme.card.color(for: colorScheme), in: .rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(tint, lineWidth: 1)
        }
        .contentShape(.rect)
        .onTapGesture {
            withAnimation(.snappy(duration: 0.15)) {
                isExpanded.toggle()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(entry.heading)

            Text(TapeTimeFormatter.shortString(from: entry.date))
                .opacity(0.8)

            if let duration = entry.duration {
                Text("\(duration.tapeMilliseconds)ms")
                    .opacity(0.8)
            }

            Spacer(minLength: 0)

            Button(action: copyToPasteboard) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copy log")
        }
        .font(.system(.caption, design: .monospaced, weight: .semibold))
        .foregroundStyle(tint)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let source = entry.source {
                Text(source.short)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(theme.secondary.color(for: colorScheme))
            }

            if !entry.metadata.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(entry.metadata.keys.sorted(), id: \.self) { key in
                        HStack(alignment: .top, spacing: 6) {
                            Text(key)
                                .foregroundStyle(theme.secondary.color(for: colorScheme))
                            Text(entry.metadata[key]?.description ?? "")
                                .foregroundStyle(theme.text.color(for: colorScheme))
                            Spacer(minLength: 0)
                        }
                    }
                }
                .font(.system(.caption2, design: .monospaced))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.background.color(for: colorScheme), in: .rect(cornerRadius: 8))
            }

            if let payload = attachmentText {
                Text(payload)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(theme.secondary.color(for: colorScheme))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.background.color(for: colorScheme), in: .rect(cornerRadius: 8))
            }
        }
    }

    private var attachmentText: String? {
        switch entry.attachment {
        case .error(let description):
            return description
        case .stackTrace(let trace):
            return trace
        case .custom(_, let payload):
            return payload
        case .http(let exchange):
            var text = "\(exchange.method) \(exchange.url)"
            if let statusCode = exchange.statusCode {
                text += " → \(statusCode)"
            }
            if let body = exchange.response?.body {
                text += "\n\n\(body)"
            }
            return text
        case .none:
            return nil
        }
    }

    private func copyToPasteboard() {
        #if canImport(UIKit)
        UIPasteboard.general.string = entry.copyText
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.copyText, forType: .string)
        #endif
    }
}
