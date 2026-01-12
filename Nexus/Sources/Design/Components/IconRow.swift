import SwiftUI

struct IconRow: View {
    let icon: String
    let title: String
    var subtitle: String?
    var color: Color
    var showChevron: Bool

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        color: Color = .nexusPurple,
        showChevron: Bool = true
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.color = color
        self.showChevron = showChevron
    }

    var body: some View {
        HStack(spacing: 12) {
            iconView
            textContent
            Spacer()
            if showChevron {
                chevronView
            }
        }
        .padding(12)
        .background { rowBackground }
    }
}

// MARK: - Components

private extension IconRow {
    var iconView: some View {
        Image(systemName: icon)
            .font(.system(size: 16))
            .foregroundStyle(color)
            .frame(width: 32, height: 32)
            .background {
                Circle()
                    .fill(color.opacity(0.15))
            }
    }

    var textContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.nexusSubheadline)
                .lineLimit(1)

            if let subtitle {
                Text(subtitle)
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var chevronView: some View {
        Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(.tertiary)
    }

    var rowBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.nexusSurface)
    }
}

#Preview {
    VStack(spacing: 8) {
        IconRow(
            icon: "checkmark.circle",
            title: "Complete project review",
            subtitle: "Due tomorrow",
            color: .nexusBlue
        )

        IconRow(
            icon: "doc.text",
            title: "Meeting Notes",
            subtitle: "Updated 2 hours ago",
            color: .nexusOrange
        )

        IconRow(
            icon: "heart.fill",
            title: "Health Summary",
            color: .nexusGreen,
            showChevron: false
        )
    }
    .padding()
    .background(Color.nexusBackground)
    .preferredColorScheme(.dark)
}
