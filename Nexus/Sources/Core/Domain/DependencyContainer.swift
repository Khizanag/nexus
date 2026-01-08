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

        container.register(KeychainServiceProtocol.self) { _ in
            KeychainService()
        }
        .inObjectScope(.container)

        container.register(AuthenticationServiceProtocol.self) { resolver in
            let keychainService = resolver.resolve(KeychainServiceProtocol.self)!
            return AuthenticationService(keychainService: keychainService)
        }
        .inObjectScope(.container)

        container.register(SyncServiceProtocol.self) { resolver in
            let authService = resolver.resolve(AuthenticationServiceProtocol.self)!
            return SyncService(authService: authService)
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
