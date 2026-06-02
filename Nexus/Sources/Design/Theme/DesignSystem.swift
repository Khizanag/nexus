import SwiftUI

/// Central design-token namespace. Prefer these over hardcoded literals so spacing,
/// radii, and sizes stay consistent and adjustable in one place.
enum DesignSystem {
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let card: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
    }

    enum Size {
        enum Icon {
            static let sm: CGFloat = 16
            static let md: CGFloat = 24
            static let lg: CGFloat = 32
            static let badge: CGFloat = 36
        }

        enum Button {
            static let tap: CGFloat = 44
            static let compact: CGFloat = 36
        }

        enum Avatar {
            static let sm: CGFloat = 28
            static let md: CGFloat = 40
            static let lg: CGFloat = 56
        }
    }

    enum Shadow {
        static let soft = Color.black.opacity(0.12)
    }
}
