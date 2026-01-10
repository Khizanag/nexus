import SwiftUI

extension Color {
    /// Creates a Color from a color name string (like "red", "blue", "orange")
    /// This uses SwiftUI's built-in colors, NOT asset catalog lookup
    static func named(_ name: String) -> Color {
        switch name.lowercased() {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "gray", "grey": return .gray
        case "cyan": return .cyan
        case "mint": return .mint
        case "teal": return .teal
        case "indigo": return .indigo
        case "brown": return .brown
        case "black": return .black
        case "white": return .white
        default: return .gray
        }
    }
}
