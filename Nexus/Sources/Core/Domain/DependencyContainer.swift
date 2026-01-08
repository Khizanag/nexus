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
        container.register(AIService.self) { _ in
            DefaultAIService()
        }
        .inObjectScope(.container)

        container.register(KeychainService.self) { _ in
            DefaultKeychainService()
        }
        .inObjectScope(.container)

        container.register(AuthenticationService.self) { resolver in
            let keychainService = resolver.resolve(KeychainService.self)!
            return DefaultAuthenticationService(keychainService: keychainService)
        }
        .inObjectScope(.container)

        container.register(SyncService.self) { resolver in
            let authService = resolver.resolve(AuthenticationService.self)!
            return DefaultSyncService(authService: authService)
        }
        .inObjectScope(.container)

        container.register(CurrencyService.self) { _ in
            DefaultCurrencyService()
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
