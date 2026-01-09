import Foundation
import UserNotifications

@MainActor
protocol TaskNotificationService {
    func requestAuthorization() async -> Bool
    func scheduleReminder(for task: TaskModel) async
    func cancelReminder(for task: TaskModel)
    func cancelAllTaskReminders()
}

@MainActor
final class DefaultTaskNotificationService: TaskNotificationService {
    static let shared = DefaultTaskNotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()

    private init() {
        setupNotificationCategories()
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    func scheduleReminder(for task: TaskModel) async {
        guard let reminderDate = task.reminderDate, reminderDate > Date() else { return }
        guard !task.isCompleted else { return }

        cancelReminder(for: task)

        let content = UNMutableNotificationContent()
        content.title = "Task Reminder"
        content.body = task.title
        content.sound = .default
        content.categoryIdentifier = "TASK_REMINDER"
        content.userInfo = ["taskId": task.id.uuidString]

        if let dueDate = task.dueDate {
            content.body = "\(task.title) - Due \(formatDate(dueDate))"
        }

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "task-\(task.id.uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to schedule task notification: \(error)")
        }
    }

    func cancelReminder(for task: TaskModel) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [
            "task-\(task.id.uuidString)"
        ])
    }

    func cancelAllTaskReminders() {
        notificationCenter.getPendingNotificationRequests { requests in
            let taskIds = requests
                .filter { $0.identifier.hasPrefix("task-") }
                .map { $0.identifier }

            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: taskIds)
        }
    }

    private func setupNotificationCategories() {
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE_TASK",
            title: "Mark Complete",
            options: []
        )

        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_TASK",
            title: "Snooze 1 Hour",
            options: []
        )

        let taskCategory = UNNotificationCategory(
            identifier: "TASK_REMINDER",
            actions: [completeAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([taskCategory])
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
