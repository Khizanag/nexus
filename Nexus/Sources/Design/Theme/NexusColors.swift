import SwiftUI

extension Color {
    // MARK: - Brand Colors
    // Brand hues are identical in light and dark — they read as saturated accents in both.
    static let nexusPurple = Color(hex: "8B5CF6")
    static let nexusBlue = Color(hex: "3B82F6")
    static let nexusTeal = Color(hex: "14B8A6")
    static let nexusGreen = Color(hex: "22C55E")
    static let nexusOrange = Color(hex: "F97316")
    static let nexusRed = Color(hex: "EF4444")
    static let nexusPink = Color(hex: "EC4899")

    // MARK: - Semantic Colors (adaptive — light + dark)
    // nexusBackground, nexusSurface, nexusSurfaceSecondary, nexusBorder,
    // nexusTextPrimary, nexusTextSecondary and nexusTextTertiary are provided
    // automatically as generated asset symbols from Assets.xcassets, each with a
    // light and a dark appearance.

    /// Foreground for content drawn on top of a saturated accent fill (gradients, filled buttons).
    /// Stays near-white in both appearances because accent fills are dark enough in both.
    static let nexusOnAccent = Color.white

    // MARK: - Module Colors
    static let notesColor = nexusPurple
    static let tasksColor = nexusBlue
    static let financeColor = nexusGreen
    static let healthColor = nexusRed

    // MARK: - Gradients
    static var nexusGradient: LinearGradient {
        LinearGradient(
            colors: [nexusPurple, nexusBlue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Hex Initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
