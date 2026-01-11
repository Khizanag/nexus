import SwiftUI

struct CalendarSource: Identifiable, Hashable {
    let id: String
    let title: String
    let color: Color
    let sourceType: CalendarSourceType
    let sourceName: String
    let isEditable: Bool
    var isVisible: Bool

    var icon: String {
        switch sourceType {
        case .local: "calendar"
        case .calDAV: "cloud"
        case .exchange: "building.2"
        case .subscription: "link"
        case .birthday: "gift"
        }
    }

    var sourceIcon: String {
        switch sourceType {
        case .local: "iphone"
        case .calDAV: "icloud"
        case .exchange: "building.2.fill"
        case .subscription: "globe"
        case .birthday: "gift.fill"
        }
    }
}

enum CalendarSourceType: String, Codable {
    case local
    case calDAV
    case exchange
    case subscription
    case birthday

    var displayName: String {
        switch self {
        case .local: "On My iPhone"
        case .calDAV: "iCloud"
        case .exchange: "Exchange"
        case .subscription: "Subscribed"
        case .birthday: "Other"
        }
    }
}
