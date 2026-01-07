import Foundation

enum WidgetAction: String {
    case openAssistant
    case logWater
}

enum WidgetDataStore {
    static let suiteName = "group.com.khizanag.nexus"
    static let pendingActionKey = "pendingWidgetAction"

    static func setPendingAction(_ action: WidgetAction) {
        UserDefaults(suiteName: suiteName)?.set(action.rawValue, forKey: pendingActionKey)
    }

    static func consumePendingAction() -> WidgetAction? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let rawValue = defaults.string(forKey: pendingActionKey) else {
            return nil
        }
        defaults.removeObject(forKey: pendingActionKey)
        return WidgetAction(rawValue: rawValue)
    }
}
