import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    var subtitle: String?
    var actionTitle: String?
    var action: (() -> Void)?

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.nexusTitle3)

            if let subtitle {
                Text(subtitle)
                    .font(.nexusSubheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.nexusSubheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.nexusPurple)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview {
    VStack(spacing: 32) {
        EmptyStateView(
            icon: "checkmark.circle",
            title: "No Completed Tasks",
            subtitle: "Complete some tasks to see them here"
        )

        EmptyStateView(
            icon: "doc.text",
            title: "No Notes Yet",
            subtitle: "Start by creating your first note",
            actionTitle: "Create Note"
        ) {
            print("Create note tapped")
        }
    }
    .padding()
    .background(Color.nexusBackground)
    .preferredColorScheme(.dark)
}
