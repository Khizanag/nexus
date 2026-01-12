import Foundation
import UserNotifications
import SwiftData

@MainActor
protocol SubscriptionNotificationService {
    func requestAuthorization() async -> Bool
    func scheduleReminders(for subscriptions: [SubscriptionModel]) async
    func scheduleReminder(for subscription: SubscriptionModel) async
    func cancelReminder(for subscription: SubscriptionModel)
    func cancelAllReminders()
}

@MainActor
final class DefaultSubscriptionNotificationService: SubscriptionNotificationService {
    private let notificationCenter = UNUserNotificationCenter.current()

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    func scheduleReminders(for subscriptions: [SubscriptionModel]) async {
        cancelAllReminders()

        for subscription in subscriptions where subscription.isActive && !subscription.isPaused {
            await scheduleReminder(for: subscription)
        }
    }

    func scheduleReminder(for subscription: SubscriptionModel) async {
        guard subscription.isActive, !subscription.isPaused else { return }

        let reminderDate = Calendar.current.date(
            byAdding: .day,
            value: -subscription.reminderDaysBefore,
            to: subscription.nextDueDate
        ) ?? subscription.nextDueDate

        guard reminderDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Subscription Due Soon"
        content.body = "\(subscription.name) (\(subscription.formattedAmount)) is due in \(subscription.reminderDaysBefore) days"
        content.sound = .default
        content.categoryIdentifier = "SUBSCRIPTION_REMINDER"
        content.userInfo = ["subscriptionId": subscription.id.uuidString]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "subscription-\(subscription.id.uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to schedule notification: \(error)")
        }

        await scheduleDueDayReminder(for: subscription)
    }

    private func scheduleDueDayReminder(for subscription: SubscriptionModel) async {
        guard subscription.nextDueDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Subscription Due Today"
        content.body = "\(subscription.name) (\(subscription.formattedAmount)) is due today"
        content.sound = .default
        content.categoryIdentifier = "SUBSCRIPTION_DUE"
        content.userInfo = ["subscriptionId": subscription.id.uuidString]

        var components = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: subscription.nextDueDate
        )
        components.hour = 9
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "subscription-due-\(subscription.id.uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to schedule due day notification: \(error)")
        }
    }

    func cancelReminder(for subscription: SubscriptionModel) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [
            "subscription-\(subscription.id.uuidString)",
            "subscription-due-\(subscription.id.uuidString)"
        ])
    }

    func cancelAllReminders() {
        notificationCenter.getPendingNotificationRequests { requests in
            let subscriptionIds = requests
                .filter { $0.identifier.hasPrefix("subscription-") }
                .map { $0.identifier }

            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: subscriptionIds)
        }
    }

    func setupNotificationCategories() {
        let markPaidAction = UNNotificationAction(
            identifier: "MARK_PAID",
            title: "Mark as Paid",
            options: []
        )

        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE",
            title: "Remind Tomorrow",
            options: []
        )

        let reminderCategory = UNNotificationCategory(
            identifier: "SUBSCRIPTION_REMINDER",
            actions: [markPaidAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        let dueCategory = UNNotificationCategory(
            identifier: "SUBSCRIPTION_DUE",
            actions: [markPaidAction],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([reminderCategory, dueCategory])
    }
}
