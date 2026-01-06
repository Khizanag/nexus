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
        ])

        modelContainer = Self.createModelContainer(schema: schema)
    }

    private static func createModelContainer(schema: Schema) -> ModelContainer {
        // Try CloudKit first if entitlements are configured
        if let cloudContainer = try? ModelContainer(
            for: schema,
            configurations: ModelConfiguration(
                "Nexus",
                schema: schema,
                cloudKitDatabase: .private("iCloud.com.nexus.app")
            )
        ) {
            return cloudContainer
        }

        // Fall back to local storage
        do {
            let localConfig = ModelConfiguration(
                "Nexus",
                schema: schema,
                isStoredInMemoryOnly: false
            )
            return try ModelContainer(for: schema, configurations: localConfig)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
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
