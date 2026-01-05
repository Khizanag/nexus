import Foundation
import Swinject

@MainActor
@Observable
final class DependencyContainer: Sendable {
    static let shared = DependencyContainer()

    private let container = Container()

    private init() {}

    func registerAll() {
        registerServices()
        registerRepositories()
        registerUseCases()
    }

    func resolve<T>(_ type: T.Type) -> T? {
        container.resolve(type)
    }
}

// MARK: - Registration

private extension DependencyContainer {
    func registerServices() {
        container.register(AIServiceProtocol.self) { _ in
            AIService()
        }
        .inObjectScope(.container)

        container.register(SyncServiceProtocol.self) { _ in
            SyncService()
        }
        .inObjectScope(.container)

        container.register(CurrencyServiceProtocol.self) { _ in
            CurrencyService()
        }
        .inObjectScope(.container)
    }

    func registerRepositories() {
    }

    func registerUseCases() {
    }
}

// MARK: - Inject Property Wrapper

@MainActor
@propertyWrapper
struct Inject<T> {
    private var service: T?

    var wrappedValue: T {
        mutating get {
            if service == nil {
                service = DependencyContainer.shared.resolve(T.self)
            }
            guard let service else {
                fatalError("Could not resolve dependency: \(T.self)")
            }
            return service
        }
    }

    init() {}
}
