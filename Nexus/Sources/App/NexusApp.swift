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

        do {
            let schema = Schema([
                NoteModel.self,
                TaskModel.self,
                SubtaskModel.self,
                TransactionModel.self,
                HealthEntryModel.self,
                TagModel.self,
                ChatMessageModel.self,
                CurrencyRateCacheModel.self,
                CurrencyPreferenceModel.self
            ])

            let cloudKitConfig = ModelConfiguration(
                "Nexus",
                schema: schema,
                cloudKitDatabase: .private("iCloud.com.nexus.app")
            )

            modelContainer = try ModelContainer(
                for: schema,
                configurations: cloudKitConfig
            )
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
