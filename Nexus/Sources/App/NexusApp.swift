import SwiftUI
import SwiftData

@main
struct NexusApp: App {
    private let container: DependencyContainer
    private let modelContainer: ModelContainer

    init() {
        container = DependencyContainer.shared
        container.registerAll()

        do {
            modelContainer = try ModelContainer(
                for: Schema([
                    NoteModel.self,
                    TaskModel.self,
                    TransactionModel.self,
                    HealthEntryModel.self,
                    TagModel.self,
                    ChatMessageModel.self,
                    CurrencyRateCacheModel.self,
                    CurrencyPreferenceModel.self
                ]),
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }
}
