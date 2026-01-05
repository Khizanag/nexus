import SwiftUI

enum Tab: String, CaseIterable, Identifiable {
    case home
    case notes
    case tasks
    case finance
    case health

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .notes: "Notes"
        case .tasks: "Tasks"
        case .finance: "Finance"
        case .health: "Health"
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .notes: "doc.text.fill"
        case .tasks: "checkmark.circle.fill"
        case .finance: "creditcard.fill"
        case .health: "heart.fill"
        }
    }

    @MainActor @ViewBuilder
    var view: some View {
        switch self {
        case .home: HomeView()
        case .notes: NotesView()
        case .tasks: TasksView()
        case .finance: FinanceView()
        case .health: HealthView()
        }
    }
}
