import Foundation

/// Payload controls are escaped before the renderer adds its own ANSI codes.
/// Original entries remain untouched for structured consumers and copying.
enum TapeTerminalText {
    static func lines(_ text: String) -> [String] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        return normalized.components(separatedBy: "\n").map(escape)
    }

    private static func escape(_ text: String) -> String {
        var result = ""
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0...31, 127...159, 0x2028, 0x2029,
                 0x202A...0x202E, 0x2066...0x2069:
                result += "\\u{\(String(scalar.value, radix: 16))}"
            default:
                result.unicodeScalars.append(scalar)
            }
        }
        return result
    }

    /// Conservative terminal-column estimate, independent of global locale.
    /// Emoji clusters (including flags and ZWJ sequences) occupy two columns;
    /// combining marks add none. Ambiguous-width characters use one column.
    static func columns(_ character: Character) -> Int {
        let scalars = character.unicodeScalars
        if scalars.contains(where: {
            $0.properties.isEmojiPresentation || $0.value == 0xFE0F
                || $0.value == 0x20E3
        }) {
            return 2
        }
        return scalars.reduce(0) { width, scalar in
            switch scalar.properties.generalCategory {
            case .nonspacingMark, .enclosingMark, .format:
                return width
            default:
                return max(width, isWide(scalar.value) ? 2 : 1)
            }
        }
    }

    private static func isWide(_ value: UInt32) -> Bool {
        switch value {
        case 0x1100...0x115F, 0x2329...0x232A,
             0x2E80...0x303E, 0x3040...0xA4CF,
             0xAC00...0xD7A3, 0xF900...0xFAFF,
             0xFE10...0xFE19, 0xFE30...0xFE6F,
             0xFF01...0xFF60, 0xFFE0...0xFFE6,
             0x16FE0...0x16FE4, 0x16FF0...0x16FF1,
             0x17000...0x18DFF, 0x1AFF0...0x1AFFF,
             0x1B000...0x1B2FF, 0x1F200...0x1F251,
             0x20000...0x3FFFD:
            return true
        default:
            return false
        }
    }
}
