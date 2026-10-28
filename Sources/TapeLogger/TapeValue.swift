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
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([TapeValue])
    case object([String: TapeValue])
    case null
    case raw(String)

    public init(_ value: some CustomStringConvertible) {
        self = .raw(String(describing: value))
    }

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
    public init(stringLiteral value: String) { self = .string(value) }
}

extension TapeValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) { self = .int(value) }
}

extension TapeValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) { self = .double(value) }
}

extension TapeValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) { self = .bool(value) }
}

extension TapeValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: TapeValue...) { self = .array(elements) }
}

extension TapeValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, TapeValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}
