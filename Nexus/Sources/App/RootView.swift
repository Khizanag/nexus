import SwiftUI

struct RootView: View {
    @State private var selectedTab: Tab = .home
    @State private var showAssistant = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    tab.view
                        .tabItem {
                            Label(tab.title, systemImage: tab.icon)
                        }
                        .tag(tab)
                }
            }

            floatingAssistantButton
        }
        .fullScreenCover(isPresented: $showAssistant) {
            AssistantView()
        }
    }

    private var floatingAssistantButton: some View {
        Button {
            showAssistant = true
        } label: {
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
        .offset(y: -30)
    }
}

#Preview {
    RootView()
        .preferredColorScheme(.dark)
}
