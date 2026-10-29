import Foundation

/// Structured metadata value.
///
/// Entries keep metadata structured instead of pre-formatting it to a
/// string: the console can print it compactly while the UI can pretty
/// print and filter on it.
///
/// Literal conformances make the call site pleasant:
/// ```swift
/// Tape.info("charged", metadata: ["amount": 19.99, "currency": "EUR", "retried": false])
/// ```
public indirect enum TapeValue: Sendable, Hashable, CustomStringConvertible {
    /// Text content, stored without automatic redaction.
    case string(String)
    /// A signed integer.
    case int(Int)
    /// A floating-point number.
    case double(Double)
    /// A Boolean value.
    case bool(Bool)
    /// An ordered collection of metadata values.
    case array([TapeValue])
    /// A nested object keyed by strings.
    case object([String: TapeValue])
    /// An explicit null, represented by `NSNull` for Foundation consumers.
    case null
    /// Preformatted diagnostic text, not an instruction to parse JSON.
    case raw(String)

    /// Captures a value's description as raw text, not its original type.
    public init(_ value: some CustomStringConvertible) {
        self = .raw(String(describing: value))
    }

    /// Compact text representation with object keys sorted for stable output.
    public var description: String {
        switch self {
        case .string(let value): value
        case .int(let value): String(value)
        case .double(let value): String(value)
        case .bool(let value): value ? "true" : "false"
        case .array(let values): "[" + values.map(\.description).joined(separator: ", ") + "]"
        case .object(let values):
            "{"
                + values
                .sorted { $0.key < $1.key }
                .map { "\($0.key): \($0.value.description)" }
                .joined(separator: ", ")
                + "}"
        case .null: "null"
        case .raw(let value): value
        }
    }

    /// Foundation-compatible representation, used for JSON rendering in the UI.
    public var jsonObject: Any {
        switch self {
        case .string(let value): value
        case .int(let value): value
        case .double(let value): value
        case .bool(let value): value
        case .array(let values): values.map(\.jsonObject)
        case .object(let values): values.mapValues(\.jsonObject)
        case .null: NSNull()
        case .raw(let value): value
        }
    }
}

// MARK: - Literals

extension TapeValue: ExpressibleByStringLiteral {
    /// Creates string metadata from a literal.
    public init(stringLiteral value: String) { self = .string(value) }
}

extension TapeValue: ExpressibleByIntegerLiteral {
    /// Creates integer metadata from a literal.
    public init(integerLiteral value: Int) { self = .int(value) }
}

extension TapeValue: ExpressibleByFloatLiteral {
    /// Creates double metadata from a floating-point literal.
    public init(floatLiteral value: Double) { self = .double(value) }
}

extension TapeValue: ExpressibleByBooleanLiteral {
    /// Creates Boolean metadata from a literal.
    public init(booleanLiteral value: Bool) { self = .bool(value) }
}

extension TapeValue: ExpressibleByArrayLiteral {
    /// Creates ordered array metadata from literal elements.
    public init(arrayLiteral elements: TapeValue...) { self = .array(elements) }
}

extension TapeValue: ExpressibleByDictionaryLiteral {
    /// Creates object metadata from unique literal keys. Duplicate keys trap.
    public init(dictionaryLiteral elements: (String, TapeValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}
