import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: Tab = .home
    @State private var previousTab: Tab = .home
    @State private var showAssistant = false
    @State private var pendingWaterLog = false

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
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                handlePendingWidgetAction()
            }
        }
        .sheet(isPresented: $showAssistant) {
            AssistantView()
        }
        .sheet(isPresented: $pendingWaterLog) {
            QuickWaterLogView()
        }
    }

    private func handlePendingWidgetAction() {
        guard let action = WidgetDataStore.consumePendingAction() else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            switch action {
            case .openAssistant:
                showAssistant = true
            case .logWater:
                pendingWaterLog = true
            }
        }
    }
}

private struct QuickWaterLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var amount: Double = 250

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.nexusTeal)

                Text("\(Int(amount)) ml")
                    .font(.system(size: 48, weight: .bold, design: .rounded))

                HStack(spacing: 16) {
                    ForEach([150, 250, 500], id: \.self) { ml in
                        Button {
                            amount = Double(ml)
                        } label: {
                            Text("\(ml)")
                                .font(.nexusHeadline)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(amount == Double(ml) ? Color.nexusTeal : Color.nexusSurface)
                                .foregroundStyle(amount == Double(ml) ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }

                Slider(value: $amount, in: 50...1000, step: 50)
                    .tint(.nexusTeal)
                    .padding(.horizontal, 32)
            }
            .padding()
            .background(Color.nexusBackground)
            .navigationTitle("Log Water")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") {
                        logWater()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func logWater() {
        let entry = HealthEntryModel(
            type: .waterIntake,
            value: amount,
            unit: "ml",
            date: .now,
            notes: "Logged from Control Center"
        )
        modelContext.insert(entry)
    }
}

#Preview {
    RootView()
        .preferredColorScheme(.dark)
}
