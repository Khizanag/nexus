import SwiftUI

struct SectionHeader: View {
    let title: String
    var badge: Int?
    var actionTitle: String?
    var action: (() -> Void)?

    init(
        _ title: String,
        badge: Int? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.badge = badge
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Text(title)
                    .font(.nexusHeadline)
                    .foregroundStyle(.secondary)

                if let badge, badge > 0 {
                    Text("\(badge)")
                        .font(.nexusCaption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.nexusBorder))
                }
            }

            Spacer()

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.nexusSubheadline)
                    .foregroundStyle(Color.nexusPurple)
            }
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        SectionHeader("Recent Activity")

        SectionHeader("Tasks", badge: 12)

        SectionHeader("Insights", actionTitle: "View All") {
            print("View all tapped")
        }

        SectionHeader("Projects", badge: 5, actionTitle: "Edit") {
            print("Edit tapped")
        }
    }
    .padding()
    .background(Color.nexusBackground)
    .preferredColorScheme(.dark)
}
