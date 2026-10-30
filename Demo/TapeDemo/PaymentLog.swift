import TapeLogger

/// A custom category with a shared severity, color and amount metadata.
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
        TapeColor(light: 0x1B8A3A, dark: 0x30D158, ansi: 40)
    }

    var metadata: [String: TapeValue] {
        amount.map { ["amount": .double($0)] } ?? [:]
    }
}
