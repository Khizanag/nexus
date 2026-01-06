import SwiftUI

enum Tab: String, CaseIterable, Identifiable {
    case home
    case tasks
    case assistant
    case health
    case finance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .tasks: "Tasks"
        case .assistant: "AI"
        case .health: "Health"
        case .finance: "Finance"
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .tasks: "checkmark.circle.fill"
        case .assistant: "sparkles"
        case .health: "heart.fill"
        case .finance: "creditcard.fill"
        }
    }

    var isContent: Bool {
        self != .assistant
    }

    @MainActor @ViewBuilder
    var view: some View {
        switch self {
        case .home: HomeView()
        case .tasks: TasksView()
        case .assistant: EmptyView()
        case .health: HealthView()
        case .finance: FinanceView()
        }
    }
}
