import SwiftUI

/// User-selectable color scheme, persisted in `@AppStorage("appearance")` and applied at the app root.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    /// `nil` follows the system; otherwise forces the chosen scheme.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// User-selectable accent, persisted in `@AppStorage("accentColor")` and applied as the global `.tint`.
enum AccentPalette: String, CaseIterable, Identifiable {
    case purple
    case blue
    case green
    case orange
    case pink
    case teal

    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .purple: .nexusPurple
        case .blue: .nexusBlue
        case .green: .nexusGreen
        case .orange: .nexusOrange
        case .pink: .nexusPink
        case .teal: .nexusTeal
        }
    }

    /// Resolves the stored accent string, defaulting to purple for any unknown value.
    static func color(for stored: String) -> Color {
        AccentPalette(rawValue: stored)?.color ?? .nexusPurple
    }
}
