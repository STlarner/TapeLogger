import TapeLogger

/// A custom log type, the talker-style way: header, level and badge are
/// declared once, next to each other, and every call site stays short.
struct PaymentLog: TapeLog {
    let message: String
    let amount: Double?

    init(_ message: String, amount: Double? = nil) {
        self.message = message
        self.amount = amount
    }

    var title: String { "payments" }
    var level: TapeLevel { .notice }
    var color: TapeColor? {
        TapeColor(
            light: 0x1B8A3A,
            dark: 0x30D158,
            ansi: 40,
            emoji: "💳"
        )
    }

    var metadata: [String: TapeValue] {
        amount.map { ["amount": .double($0)] } ?? [:]
    }
}
