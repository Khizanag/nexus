import SwiftUI

// MARK: - Glass Background

/// Applies iOS 26 Liquid Glass behind a view, with an opaque fallback when the user
/// has Reduce Transparency enabled (glassEffect on custom views does not auto-adapt).
/// Apply AFTER layout/appearance modifiers so the glass uses the correct bounds.
struct GlassBackground<S: Shape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let shape: S
    var tint: Color?
    var interactive: Bool

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background((tint ?? Color.nexusSurface).opacity(tint == nil ? 1 : 0.18), in: shape)
                .background(Color.nexusSurface, in: shape)
                .overlay { shape.stroke(Color.nexusBorder, lineWidth: 1) }
        } else {
            content.glassEffect(glass, in: shape)
        }
    }

    private var glass: Glass {
        var glass: Glass = .regular
        if let tint { glass = glass.tint(tint) }
        return interactive ? glass.interactive() : glass
    }
}

extension View {
    /// Liquid Glass background in the given shape (default: a 16pt continuous rounded rect).
    func glassBackground<S: Shape>(
        in shape: S = RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous),
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        modifier(GlassBackground(shape: shape, tint: tint, interactive: interactive))
    }
}

// MARK: - Glass Card

/// Canonical translucent card surface. Pads its content, then applies Liquid Glass.
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat
    var tint: Color?
    @ViewBuilder var content: Content

    init(
        cornerRadius: CGFloat = DesignSystem.CornerRadius.card,
        tint: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(DesignSystem.Spacing.md)
            .glassBackground(
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                tint: tint
            )
    }
}

// MARK: - Glass Icon Button

/// A circular glass icon button — the native replacement for the hand-rolled icon buttons.
struct GlassIconButton: View {
    let systemImage: String
    var accessibilityLabel: String
    var prominent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline)
                .frame(width: DesignSystem.Size.Button.tap, height: DesignSystem.Size.Button.tap)
        }
        .buttonStyle(.glass)
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview {
    ZStack {
        Color.nexusBackground.ignoresSafeArea()
        VStack(spacing: DesignSystem.Spacing.lg) {
            GlassCard {
                HStack {
                    Text("Glass Card").font(.nexusHeadline)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                }
            }
            GlassCard(tint: .nexusPurple) {
                Text("Tinted glass").font(.nexusHeadline)
                    .frame(maxWidth: .infinity)
            }
            HStack(spacing: DesignSystem.Spacing.md) {
                GlassIconButton(systemImage: "plus", accessibilityLabel: "Add") {}
                GlassIconButton(systemImage: "sparkles", accessibilityLabel: "Assistant") {}
            }
        }
        .padding()
    }
}
