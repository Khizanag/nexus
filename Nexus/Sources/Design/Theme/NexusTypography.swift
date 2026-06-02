import SwiftUI

// Tokens are built on semantic text styles so every label honors Dynamic Type.
// The signature rounded display look is preserved via `design: .rounded`.

extension Font {
    // MARK: - Display
    static let nexusLargeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let nexusTitle = Font.system(.title, design: .rounded, weight: .bold)
    static let nexusTitle2 = Font.system(.title2, design: .rounded, weight: .semibold)
    static let nexusTitle3 = Font.system(.title3, design: .rounded, weight: .semibold)

    // MARK: - Body
    static let nexusHeadline = Font.system(.headline)
    static let nexusBody = Font.system(.body)
    static let nexusCallout = Font.system(.callout)
    static let nexusSubheadline = Font.system(.subheadline)
    static let nexusFootnote = Font.system(.footnote)
    static let nexusCaption = Font.system(.caption)
    static let nexusCaption2 = Font.system(.caption2)

    // MARK: - Monospace
    static let nexusMono = Font.system(.subheadline, design: .monospaced)
    static let nexusMonoSmall = Font.system(.footnote, design: .monospaced)

    /// A scaling rounded numeral font for hero amounts (calories, balances, water).
    /// Use instead of a fixed `.system(size:)` so large readouts still respond to Dynamic Type.
    static func nexusDisplayNumber(_ style: Font.TextStyle = .largeTitle) -> Font {
        .system(style, design: .rounded, weight: .bold)
    }
}

// MARK: - Text Style Modifiers

struct NexusTextStyle: ViewModifier {
    enum Style {
        case largeTitle, title, title2, title3
        case headline, body, callout, subheadline
        case footnote, caption, caption2
    }

    let style: Style
    let color: Color

    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundStyle(color)
    }

    private var font: Font {
        switch style {
        case .largeTitle: .nexusLargeTitle
        case .title: .nexusTitle
        case .title2: .nexusTitle2
        case .title3: .nexusTitle3
        case .headline: .nexusHeadline
        case .body: .nexusBody
        case .callout: .nexusCallout
        case .subheadline: .nexusSubheadline
        case .footnote: .nexusFootnote
        case .caption: .nexusCaption
        case .caption2: .nexusCaption2
        }
    }
}

extension View {
    func nexusTextStyle(_ style: NexusTextStyle.Style, color: Color = .nexusTextPrimary) -> some View {
        modifier(NexusTextStyle(style: style, color: color))
    }
}
