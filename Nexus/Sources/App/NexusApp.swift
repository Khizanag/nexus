import SwiftUI
import SwiftData

@main
struct NexusApp: App {
    private let container: DependencyContainer
    private let modelContainer: ModelContainer
    @State private var authService: AuthenticationService

    init() {
        container = DependencyContainer.shared
        container.registerAll()

        let keychainService = KeychainService()
        let auth = AuthenticationService(keychainService: keychainService)
        _authService = State(initialValue: auth)

        let schema = Schema([
            NoteModel.self,
            TaskModel.self,
            SubtaskModel.self,
            TransactionModel.self,
            HealthEntryModel.self,
            TagModel.self,
            ChatMessageModel.self,
            CurrencyRateCacheModel.self,
            CurrencyPreferenceModel.self,
            BudgetModel.self,
            PlannedExpenseModel.self,
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
