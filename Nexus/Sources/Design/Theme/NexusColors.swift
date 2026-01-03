import SwiftUI

extension Color {
    // MARK: - Brand Colors
    static let nexusPurple = Color(hex: "8B5CF6")
    static let nexusBlue = Color(hex: "3B82F6")
    static let nexusTeal = Color(hex: "14B8A6")
    static let nexusGreen = Color(hex: "22C55E")
    static let nexusOrange = Color(hex: "F97316")
    static let nexusRed = Color(hex: "EF4444")
    static let nexusPink = Color(hex: "EC4899")

    // MARK: - Semantic Colors
    static let nexusBackground = Color(hex: "0A0A0F")
    static let nexusSurface = Color(hex: "141419")
    static let nexusSurfaceSecondary = Color(hex: "1C1C24")
    static let nexusBorder = Color(hex: "2A2A35")

    static let nexusTextPrimary = Color.white
    static let nexusTextSecondary = Color(hex: "9CA3AF")
    static let nexusTextTertiary = Color(hex: "6B7280")

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
