import SwiftUI
import SwiftData
import UserNotifications

@main
struct NexusApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let container: DependencyContainer
    private let modelContainer: ModelContainer
    @State private var authService: DefaultAuthenticationService

    init() {
        container = DependencyContainer.shared
        container.registerAll()

        let keychainService = DefaultKeychainService()
        let auth = DefaultAuthenticationService(keychainService: keychainService)
        _authService = State(initialValue: auth)

        let schema = Schema([
            NoteModel.self,
            TaskModel.self,
            SubtaskModel.self,
            TaskGroupModel.self,
            PersonModel.self,
            TransactionModel.self,
            HealthEntryModel.self,
            TagModel.self,
            ChatMessageModel.self,
            CurrencyRateCacheModel.self,
            CurrencyPreferenceModel.self,
            BudgetModel.self,
            PlannedExpenseModel.self,
            SubscriptionModel.self,
            SubscriptionPaymentModel.self,
            HouseModel.self,
            UtilityAccountModel.self,
            UtilityPaymentModel.self,
            UtilityReadingModel.self,
        ])

        modelContainer = Self.createModelContainer(schema: schema)
    }

    private static func createModelContainer(schema: Schema) -> ModelContainer {
        // Get app's document directory for the store
        let storeURL = URL.documentsDirectory.appending(path: "Nexus.sqlite")

        // Try CloudKit first
        do {
            let config = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .automatic
            )
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            print("CloudKit failed: \(error)")
        }

        // Try local storage with explicit URL
        do {
            let localConfig = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, configurations: localConfig)
        } catch {
            print("Local storage failed: \(error)")
        }

        // Last resort: default container
        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("All ModelContainer attempts failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
                .environment(authService)
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        return true
    }
}

// Separate delegate to avoid actor isolation issues
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationDelegate()

    // Handle notification tap (foreground)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // Handle notification interaction
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if let taskIdString = userInfo["taskId"] as? String,
           let taskId = UUID(uuidString: taskIdString) {

            switch response.actionIdentifier {
            case "COMPLETE_TASK":
                // Mark task as complete
                Task { @MainActor in
                    TaskLauncher.shared.markTaskComplete(taskId: taskId)
                }

            case "SNOOZE_TASK":
                // Snooze for 1 hour
                Task { @MainActor in
                    TaskLauncher.shared.snoozeTask(taskId: taskId)
                }

            case UNNotificationDefaultActionIdentifier:
                // User tapped the notification - open the task
                Task { @MainActor in
                    TaskLauncher.shared.openTask(taskId: taskId)
                }

            default:
                break
            }
        }

        completionHandler()
    }
}

// MARK: - Task Launcher

@MainActor
@Observable
final class TaskLauncher {
    static let shared = TaskLauncher()

    var pendingTaskId: UUID?
    var shouldMarkComplete: Bool = false

    private init() {}

    func openTask(taskId: UUID) {
        pendingTaskId = taskId
        shouldMarkComplete = false
    }

    func markTaskComplete(taskId: UUID) {
        pendingTaskId = taskId
        shouldMarkComplete = true
    }

    func snoozeTask(taskId: UUID) {
        // Handled by RootView
        pendingTaskId = taskId
    }

    func consumePendingTask() -> (UUID, Bool)? {
        guard let taskId = pendingTaskId else { return nil }
        let markComplete = shouldMarkComplete
        pendingTaskId = nil
        shouldMarkComplete = false
        return (taskId, markComplete)
    }
}
