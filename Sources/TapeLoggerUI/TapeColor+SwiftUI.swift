import SwiftUI
import TapeLogger

extension TapeColor {
    /// Resolves the palette entry for the current appearance.
    ///
    /// Resolving explicitly (instead of using a dynamic `UIColor`) keeps the
    /// core module free of UIKit/AppKit and makes previews deterministic.
    public func color(for colorScheme: ColorScheme) -> Color {
        Color(tapeRGB: colorScheme == .dark ? dark : light)
    }
}

extension Color {
    init(tapeRGB rgb: UInt32) {
        self.init(
            .sRGB,
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255,
            opacity: 1
        )
    }
}
