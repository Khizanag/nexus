import SwiftUI

struct NexusPrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.nexusGradient)
            }
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

struct NexusSecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.nexusSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.nexusBorder, lineWidth: 1)
                    }
            }
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }
}

struct NexusIconButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .frame(width: 44, height: 44)
                .background {
                    Circle()
                        .fill(Color.nexusSurface)
                        .overlay {
                            Circle()
                                .strokeBorder(Color.nexusBorder, lineWidth: 1)
                        }
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 16) {
        NexusPrimaryButton("Get Started", icon: "arrow.right") {}
        NexusSecondaryButton("Learn More", icon: "book") {}
        HStack {
            NexusIconButton(icon: "plus") {}
            NexusIconButton(icon: "gearshape") {}
            NexusIconButton(icon: "bell") {}
        }
    }
    .padding()
    .background(Color.nexusBackground)
    .preferredColorScheme(.dark)
}
