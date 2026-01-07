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
            VStack(spacing: 32) {
                Spacer()

                ConcentricCard(color: .nexusTeal) {
                    VStack(spacing: 16) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.white)

                        Text("\(Int(amount)) ml")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
                .padding(.horizontal, 40)

                HStack(spacing: 12) {
                    ForEach([150, 250, 500], id: \.self) { ml in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                amount = Double(ml)
                            }
                        } label: {
                            Text("\(ml)")
                                .font(.nexusHeadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background {
                                    if amount == Double(ml) {
                                        ConcentricRectangleBackground(
                                            cornerRadius: 12,
                                            layers: 4,
                                            baseColor: .nexusTeal,
                                            spacing: 3
                                        )
                                    } else {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.nexusSurface)
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .strokeBorder(Color.nexusBorder, lineWidth: 1)
                                            }
                                    }
                                }
                                .foregroundStyle(amount == Double(ml) ? .white : .primary)
                        }
                    }
                }
                .padding(.horizontal, 20)

                VStack(spacing: 8) {
                    Slider(value: $amount, in: 50...1000, step: 50)
                        .tint(Color.nexusTeal)

                    HStack {
                        Text("50 ml")
                            .font(.nexusCaption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("1000 ml")
                            .font(.nexusCaption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                ConcentricButton("Log Water", icon: "drop.fill", color: .nexusTeal) {
                    logWater()
                    dismiss()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color.nexusBackground)
            .navigationTitle("Log Water")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
