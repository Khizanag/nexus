import SwiftUI

struct NexusTabBar: View {
    @Binding var selectedTab: Tab
    let onAssistantTap: () -> Void

    private let tabs = Tab.allCases

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                if index == tabs.count / 2 {
                    assistantButton
                }

                tabButton(for: tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background {
            RoundedRectangle(cornerRadius: 32)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 32)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.2), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
        }
        .padding(.horizontal, 24)
    }

    private func tabButton(for tab: Tab) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .symbolEffect(.bounce, value: selectedTab == tab)

                Text(tab.title)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundStyle(selectedTab == tab ? Color.accentColor : .secondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var assistantButton: some View {
        Button(action: onAssistantTap) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.nexusPurple, .nexusBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: .nexusPurple.opacity(0.5), radius: 12, y: 4)

                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .offset(y: -16)
        .padding(.horizontal, 8)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()
            NexusTabBar(selectedTab: .constant(.home), onAssistantTap: {})
        }
    }
}
