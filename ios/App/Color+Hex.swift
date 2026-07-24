import SwiftUI

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        let scanned = Scanner(string: cleaned).scanHexInt64(&int)
        let r, g, b: UInt64
        if scanned, cleaned.count == 6 {
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        } else {
            (r, g, b) = (0x88, 0x88, 0x88)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
