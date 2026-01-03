import SwiftUI

extension Font {
    // MARK: - Display
    static let nexusLargeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let nexusTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let nexusTitle2 = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let nexusTitle3 = Font.system(size: 20, weight: .semibold, design: .rounded)

    // MARK: - Body
    static let nexusHeadline = Font.system(size: 17, weight: .semibold)
    static let nexusBody = Font.system(size: 17, weight: .regular)
    static let nexusCallout = Font.system(size: 16, weight: .regular)
    static let nexusSubheadline = Font.system(size: 15, weight: .regular)
    static let nexusFootnote = Font.system(size: 13, weight: .regular)
    static let nexusCaption = Font.system(size: 12, weight: .regular)
    static let nexusCaption2 = Font.system(size: 11, weight: .regular)

    // MARK: - Monospace
    static let nexusMono = Font.system(size: 15, weight: .regular, design: .monospaced)
    static let nexusMonoSmall = Font.system(size: 13, weight: .regular, design: .monospaced)
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
