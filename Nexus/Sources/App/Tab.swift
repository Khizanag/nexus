import SwiftUI

enum AppTab: String, CaseIterable, Identifiable, Hashable {
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
        case .finance: "chart.pie.fill"
        }
    }
}
