import SwiftUI

enum HomeWidget: String, CaseIterable, Identifiable, Codable {
    case notes
    case tasks
    case calendar
    case subscriptions
    case budgets
    case healthSummary
    case recentTransactions
    case house
    case upcomingBills
    case currencyConverter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notes: "Notes"
        case .tasks: "Tasks"
        case .calendar: "Calendar"
        case .subscriptions: "Subscriptions"
        case .budgets: "Budgets"
        case .healthSummary: "Health"
        case .recentTransactions: "Transactions"
        case .house: "House & Services"
        case .upcomingBills: "Upcoming Bills"
        case .currencyConverter: "Currency"
        }
    }

    var icon: String {
        switch self {
        case .notes: "doc.text.fill"
        case .tasks: "checkmark.circle.fill"
        case .calendar: "calendar"
        case .subscriptions: "repeat.circle.fill"
        case .budgets: "chart.pie.fill"
        case .healthSummary: "heart.fill"
        case .recentTransactions: "creditcard.fill"
        case .house: "house.fill"
        case .upcomingBills: "calendar.badge.clock"
        case .currencyConverter: "dollarsign.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .notes: .notesColor
        case .tasks: .tasksColor
        case .calendar: .nexusTeal
        case .subscriptions: .nexusPurple
        case .budgets: .nexusBlue
        case .healthSummary: .nexusRed
        case .recentTransactions: .financeColor
        case .house: .nexusOrange
        case .upcomingBills: .orange
        case .currencyConverter: .nexusGreen
        }
    }

    var description: String {
        switch self {
        case .notes: "View and create notes"
        case .tasks: "View and manage tasks"
        case .calendar: "Today's events at a glance"
        case .subscriptions: "View and manage subscriptions"
        case .budgets: "Track your budget progress"
        case .healthSummary: "Quick health metrics"
        case .recentTransactions: "Recent transactions"
        case .house: "House and utility services"
        case .upcomingBills: "Upcoming bills and payments"
        case .currencyConverter: "Quick currency conversion"
        }
    }
}

// MARK: - Widget Storage

@MainActor
class HomeWidgetManager: ObservableObject {
    static let shared = HomeWidgetManager()

    @Published var selectedWidgets: [HomeWidget] {
        didSet {
            saveWidgets()
        }
    }

    private let storageKey = "homeWidgets"

    private init() {
        selectedWidgets = Self.loadWidgets()
    }

    private static func loadWidgets() -> [HomeWidget] {
        guard let data = UserDefaults.standard.data(forKey: "homeWidgets"),
              let widgets = try? JSONDecoder().decode([HomeWidget].self, from: data) else {
            return [.subscriptions, .tasks]
        }
        return widgets
    }

    private func saveWidgets() {
        if let data = try? JSONEncoder().encode(selectedWidgets) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func addWidget(_ widget: HomeWidget) {
        guard !selectedWidgets.contains(widget) else { return }
        selectedWidgets.append(widget)
    }

    func removeWidget(_ widget: HomeWidget) {
        selectedWidgets.removeAll { $0 == widget }
    }

    func moveWidget(from source: IndexSet, to destination: Int) {
        selectedWidgets.move(fromOffsets: source, toOffset: destination)
    }

    func isSelected(_ widget: HomeWidget) -> Bool {
        selectedWidgets.contains(widget)
    }
}
