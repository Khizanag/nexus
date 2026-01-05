import SwiftUI

enum Tab: String, CaseIterable, Identifiable {
    case home
    case notes
    case assistant
    case tasks
    case finance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .notes: "Notes"
        case .assistant: "AI"
        case .tasks: "Tasks"
        case .finance: "Finance"
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .notes: "doc.text.fill"
        case .assistant: "sparkles"
        case .tasks: "checkmark.circle.fill"
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
        case .notes: NotesView()
        case .assistant: EmptyView()
        case .tasks: TasksView()
        case .finance: FinanceView()
        }
    }
}
