import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: Tab = .home
    @State private var previousTab: Tab = .home
    @State private var showAssistant = false

    private var assistantLauncher = AssistantLauncher.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(Tab.allCases) { tab in
                Group {
                    if tab.isContent {
                        tab.view
                    } else {
                        Color.clear
                    }
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.icon)
                }
                .tag(tab)
            }
        }
        .tint(.nexusPurple)
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == .assistant {
                showAssistant = true
                selectedTab = previousTab
            } else {
                previousTab = newValue
            }
        }
        .onChange(of: assistantLauncher.shouldOpenAssistant) { _, shouldOpen in
            if shouldOpen {
                showAssistant = true
                assistantLauncher.shouldOpenAssistant = false
            }
        }
        .sheet(isPresented: $showAssistant) {
            AssistantView()
        }
    }
}

#Preview {
    RootView()
        .preferredColorScheme(.dark)
}
