import SwiftUI

struct ConcentricRectangleStyle: ViewModifier {
    var cornerRadius: CGFloat = 24
    var layers: Int = 4
    var baseColor: Color = .nexusPurple
    var spacing: CGFloat = 6

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    ForEach(0..<layers, id: \.self) { index in
                        let reverseIndex = layers - 1 - index
                        let inset = CGFloat(reverseIndex) * spacing
                        let opacity = 0.15 + (Double(index) / Double(layers)) * 0.25

                        RoundedRectangle(cornerRadius: cornerRadius - inset * 0.3)
                            .fill(baseColor.opacity(opacity))
                            .padding(inset)
                    }
                }
            }
    }
}

struct ConcentricRectangleBackground: View {
    var cornerRadius: CGFloat = 24
    var layers: Int = 4
    var baseColor: Color = .nexusPurple
    var spacing: CGFloat = 6

    var body: some View {
        ZStack {
            ForEach(0..<layers, id: \.self) { index in
                let reverseIndex = layers - 1 - index
                let inset = CGFloat(reverseIndex) * spacing
                let opacity = 0.1 + (Double(index) / Double(layers)) * 0.3

                RoundedRectangle(cornerRadius: cornerRadius - inset * 0.3)
                    .fill(baseColor.opacity(opacity))
                    .padding(inset)
            }

            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    LinearGradient(
                        colors: [baseColor.opacity(0.5), baseColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
}

struct ConcentricButton: View {
    let title: String
    let icon: String?
    let color: Color
    let action: () -> Void

    init(_ title: String, icon: String? = nil, color: Color = .nexusPurple, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                }
                Text(title)
                    .font(.nexusHeadline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background {
                ConcentricRectangleBackground(
                    cornerRadius: 16,
                    layers: 5,
                    baseColor: color,
                    spacing: 4
                )
            }
        }
        .buttonStyle(.plain)
    }
}

struct ConcentricCard<Content: View>: View {
    let color: Color
    let content: Content

    init(color: Color = .nexusPurple, @ViewBuilder content: () -> Content) {
        self.color = color
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background {
                ConcentricRectangleBackground(
                    cornerRadius: 20,
                    layers: 5,
                    baseColor: color,
                    spacing: 5
                )
            }
    }
}

struct ConcentricIconButton: View {
    let icon: String
    let color: Color
    let size: CGFloat
    let action: () -> Void

    init(icon: String, color: Color = .nexusPurple, size: CGFloat = 56, action: @escaping () -> Void) {
        self.icon = icon
        self.color = color
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background {
                    ZStack {
                        ForEach(0..<4, id: \.self) { index in
                            let reverseIndex = 3 - index
                            let inset = CGFloat(reverseIndex) * 4
                            let opacity = 0.15 + (Double(index) / 4) * 0.35

                            Circle()
                                .fill(color.opacity(opacity))
                                .padding(inset)
                        }

                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [color.opacity(0.6), color.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

extension View {
    func concentricBackground(
        cornerRadius: CGFloat = 24,
        layers: Int = 4,
        color: Color = .nexusPurple,
        spacing: CGFloat = 6
    ) -> some View {
        modifier(ConcentricRectangleStyle(
            cornerRadius: cornerRadius,
            layers: layers,
            baseColor: color,
            spacing: spacing
        ))
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 24) {
            ConcentricCard(color: .nexusPurple) {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 32))
                    Text("AI Assistant")
                        .font(.nexusHeadline)
                    Text("Ask me anything")
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            ConcentricCard(color: .nexusTeal) {
                HStack {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 24))
                    VStack(alignment: .leading) {
                        Text("Water Intake")
                            .font(.nexusHeadline)
                        Text("2,500 ml today")
                            .font(.nexusCaption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }

            ConcentricButton("Open Assistant", icon: "sparkles", color: .nexusPurple) {}

            ConcentricButton("Log Water", icon: "drop.fill", color: .nexusTeal) {}

            HStack(spacing: 16) {
                ConcentricIconButton(icon: "plus", color: .nexusGreen) {}
                ConcentricIconButton(icon: "heart.fill", color: .nexusRed) {}
                ConcentricIconButton(icon: "star.fill", color: .nexusOrange) {}
            }
        }
        .padding(20)
    }
    .background(Color.nexusBackground)
    .preferredColorScheme(.dark)
}
