import SwiftUI

struct StatusBadge: View {
    let text: String
    var icon: String?
    let color: Color

    init(
        _ text: String,
        icon: String? = nil,
        color: Color
    ) {
        self.text = text
        self.icon = icon
        self.color = color
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10))
            }
            Text(text)
                .font(.nexusCaption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            Capsule()
                .fill(color.opacity(0.15))
        }
        .overlay {
            Capsule()
                .strokeBorder(color, lineWidth: 1)
        }
        .foregroundStyle(color)
    }
}

#Preview {
    VStack(spacing: 12) {
        HStack(spacing: 8) {
            StatusBadge("Active", icon: "checkmark.circle.fill", color: .nexusGreen)
            StatusBadge("Pending", icon: "clock.fill", color: .nexusOrange)
            StatusBadge("Expired", icon: "xmark.circle.fill", color: .nexusRed)
        }

        HStack(spacing: 8) {
            StatusBadge("High", color: .nexusRed)
            StatusBadge("Medium", color: .nexusOrange)
            StatusBadge("Low", color: .nexusBlue)
        }
    }
    .padding()
    .background(Color.nexusBackground)
    .preferredColorScheme(.dark)
}
