import SwiftUI

struct CapabilitiesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    AIAvatarView()
                        .scaleEffect(0.8)
                        .padding(.top, 20)

                    Text("What I Can Do")
                        .font(.nexusTitle2)

                    VStack(spacing: 16) {
                        CapabilityCard(
                            icon: "checkmark.circle.fill",
                            title: "Task Management",
                            description: "Create tasks, track due dates, mark complete",
                            color: .tasksColor,
                            examples: [
                                "Create task Buy groceries tomorrow",
                                "Remind me to call mom",
                                "Complete task Buy groceries",
                                "What tasks are due today?"
                            ]
                        )

                        CapabilityCard(
                            icon: "doc.text.fill",
                            title: "Notes & Writing",
                            description: "Create notes, summarize content, organize thoughts",
                            color: .notesColor,
                            examples: [
                                "Create note Meeting: discussed project",
                                "Add note Ideas for the weekend",
                                "Summarize my notes"
                            ]
                        )

                        CapabilityCard(
                            icon: "creditcard.fill",
                            title: "Finance Tracking",
                            description: "Analyze spending, view income, track by category",
                            color: .financeColor,
                            examples: ["How much did I spend?", "Show my top expenses"]
                        )

                        CapabilityCard(
                            icon: "heart.fill",
                            title: "Health Tracking",
                            description: "Log and track sleep, steps, weight, water, and more",
                            color: .healthColor,
                            examples: [
                                "Log 8 hours of sleep",
                                "Drank 500ml water",
                                "Weight 75 kg",
                                "How's my health?"
                            ]
                        )
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 40)
            }
            .background(Color.nexusBackground)
            .navigationTitle("Nexus AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Capability Card

private struct CapabilityCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let examples: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.nexusHeadline)
                    Text(description)
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Try saying:")
                    .font(.nexusCaption)
                    .foregroundStyle(.tertiary)

                ForEach(examples, id: \.self) { example in
                    Text("• \"\(example)\"")
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
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

#Preview {
    CapabilitiesView()
        .preferredColorScheme(.dark)
}
