import SwiftUI

struct FilterChip: View {
    let title: String
    var icon: String?
    let isSelected: Bool
    var count: Int?
    let action: () -> Void

    init(
        title: String,
        icon: String? = nil,
        isSelected: Bool,
        count: Int? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.count = count
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                }

                Text(title)
                    .font(.nexusSubheadline)

                if let count, count > 0 {
                    Text("\(count)")
                        .font(.nexusCaption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background {
                            Capsule()
                                .fill(isSelected ? .white.opacity(0.2) : Color.nexusBorder)
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(isSelected ? Color.nexusPurple : Color.nexusSurface)
                    .overlay {
                        if !isSelected {
                            Capsule()
                                .strokeBorder(Color.nexusBorder, lineWidth: 1)
                        }
                    }
            }
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 8) {
            FilterChip(title: "All", isSelected: true, count: 24) {}
            FilterChip(title: "Today", isSelected: false, count: 5) {}
            FilterChip(title: "Done", isSelected: false) {}
        }

        HStack(spacing: 8) {
            FilterChip(title: "Active", icon: "checkmark.circle", isSelected: true) {}
            FilterChip(title: "Paused", icon: "pause.circle", isSelected: false) {}
        }
    }
    .padding()
    .background(Color.nexusBackground)
    .preferredColorScheme(.dark)
}
