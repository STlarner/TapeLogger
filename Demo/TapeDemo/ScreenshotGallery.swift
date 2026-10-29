import Foundation
import SwiftUI
import TapeLogger
import TapeLoggerUI

#if DEBUG
/// Deterministic sample data for documentation, separate from live demo logs.
/// Launch with `--screenshots`, optionally `--dark` or `--http-details`.
struct ScreenshotGallery: View {
    private let arguments = ProcessInfo.processInfo.arguments
    @State private var store = ScreenshotFixtures.makeStore()

    private var appearance: ColorScheme {
        arguments.contains("--dark") ? .dark : .light
    }

    var body: some View {
        Group {
            if arguments.contains("--http-details") {
                NavigationStack {
                    ScrollView {
                        TapeEntryCard(
                            entry: ScreenshotFixtures.httpResponse,
                            initiallyExpanded: true
                        )
                        .padding(12)
                    }
                    .background(TapeTheme.default.background.color(
                        for: appearance
                    ))
                    .navigationTitle("HTTP details")
                    .navigationBarTitleDisplayMode(.inline)
                }
            } else {
                TapeConsoleView(store: store)
            }
        }
        .preferredColorScheme(appearance)
    }
}

private enum ScreenshotFixtures {
    private static let date = Date(timeIntervalSince1970: 1_798_727_400)

    static var httpResponse: TapeEntry {
        TapeEntry(
            date: date.addingTimeInterval(3),
            level: .info,
            key: .httpResponse,
            message: "GET /products → 200",
            metadata: ["requestID": "catalog-42"],
            source: TapeSource(
                file: "Shop/CatalogService.swift",
                function: "loadProducts()", line: 28
            ),
            duration: .milliseconds(184),
            attachment: .http(TapeHTTPExchange(
                method: "GET", url: "https://api.example.com/products",
                statusCode: 200,
                request: .init(headers: [
                    "Accept": "application/json",
                    "Authorization": "<redacted>",
                ], bodySize: 0),
                response: .init(
                    headers: ["Content-Type": "application/json",
                              "X-Request-ID": "catalog-42"],
                    body: """
                    {
                      "products": [
                        { "id": 42, "name": "Everyday backpack" }
                      ],
                      "total": 24
                    }
                    """,
                    bodySize: 124
                )
            ))
        )
    }

    static func makeStore() -> TapeStore {
        let store = TapeStore()
        let entries = [
            TapeEntry(
                date: date, level: .notice, key: .lifecycle,
                message: "Shop is ready for a new session"
            ),
            TapeEntry(
                date: date.addingTimeInterval(1),
                level: .debug, key: .navigation,
                message: "Push ProductList → ProductDetail(42)"
            ),
            TapeEntry(
                date: date.addingTimeInterval(2),
                level: .info, key: .httpRequest,
                message: "GET https://api.example.com/products"
            ),
            httpResponse,
            TapeEntry(
                date: date.addingTimeInterval(4), level: .info,
                message: "Loaded 24 products from the catalog",
                metadata: ["cached": false, "items": 24]
            ),
            TapeEntry(
                date: date.addingTimeInterval(5),
                level: .debug, key: .storage,
                message: "Indexed the local catalog",
                duration: .milliseconds(23)
            ),
            TapeEntry(
                date: date.addingTimeInterval(6),
                level: .warning, key: .storage,
                message: "Image cache miss · fetching the original"
            ),
            TapeEntry(
                date: date.addingTimeInterval(7), level: .info,
                key: TapeKey("payments", color: TapeColor(
                    light: 0x7B1FA2, dark: 0xBF7FFF,
                    ansi: 135, emoji: "💳"
                )),
                message: "Annual plan purchased",
                metadata: ["amount": 49, "currency": "USD"]
            ),
            TapeEntry(
                date: date.addingTimeInterval(8), level: .error,
                message: "Could not refresh recommendations",
                attachment: .error("The request timed out. Try again later.")
            ),
        ]
        for entry in entries { store.append(entry) }
        return store
    }
}
#endif
