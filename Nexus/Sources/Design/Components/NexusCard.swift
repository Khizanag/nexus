import SwiftUI

struct NexusCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.nexusSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.nexusBorder, lineWidth: 1)
                    }
            }
    }
}

struct NexusGlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.15), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    }
            }
    }
}

// MARK: - Card Modifier

struct NexusCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.nexusSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.nexusBorder, lineWidth: 1)
                    }
            }
    }
}

extension View {
    func nexusCard() -> some View {
        modifier(NexusCardModifier())
    }
}

#Preview {
    VStack(spacing: 16) {
        NexusCard {
            HStack {
                VStack(alignment: .leading) {
                    Text("Card Title")
                        .nexusTextStyle(.headline)
                    Text("Subtitle here")
                        .nexusTextStyle(.subheadline, color: .nexusTextSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
        }

        NexusGlassCard {
            Text("Glass Card")
                .nexusTextStyle(.headline)
        }
    }
    .padding()
    .background(Color.nexusBackground)
    .preferredColorScheme(.dark)
}
