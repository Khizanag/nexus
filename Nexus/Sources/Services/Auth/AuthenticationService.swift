import AuthenticationServices
import Foundation

struct UserAccount: Codable, Sendable {
    let id: String
    let email: String?
    let fullName: String?
    let signInDate: Date

    var displayName: String {
        fullName ?? email ?? "Nexus User"
    }

    var initials: String {
        if let name = fullName, !name.isEmpty {
            let components = name.components(separatedBy: " ")
            let initials = components.compactMap { $0.first }.prefix(2)
            return String(initials).uppercased()
        }
        return "N"
    }
}

@MainActor
protocol AuthenticationServiceProtocol: Sendable {
    var isSignedIn: Bool { get }
    var currentUser: UserAccount? { get }
    func signInWithApple(presentationAnchor: ASPresentationAnchor) async throws -> UserAccount
    func signOut() throws
    func checkExistingCredential() async -> Bool
}

@MainActor
@Observable
final class AuthenticationService: NSObject, AuthenticationServiceProtocol {
    private(set) var isSignedIn: Bool = false
    private(set) var currentUser: UserAccount?

    private let keychainService: KeychainServiceProtocol
    private var signInContinuation: CheckedContinuation<UserAccount, Error>?
    private var presentationWindow: ASPresentationAnchor?

    nonisolated init(keychainService: KeychainServiceProtocol = KeychainService()) {
        self.keychainService = keychainService
        super.init()
        Task { @MainActor in
            await loadStoredUser()
        }
    }

    private func loadStoredUser() async {
        do {
            if let data = try keychainService.load(forKey: KeychainKey.userAccount),
               let user = try? JSONDecoder().decode(UserAccount.self, from: data) {
                currentUser = user
                isSignedIn = true
            }
        } catch {
            print("Failed to load stored user: \(error)")
        }
    }

    func signInWithApple(presentationAnchor: ASPresentationAnchor) async throws -> UserAccount {
        self.presentationWindow = presentationAnchor

        return try await withCheckedThrowingContinuation { continuation in
            self.signInContinuation = continuation

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func signOut() throws {
        try keychainService.delete(forKey: KeychainKey.userAccount)
        try keychainService.delete(forKey: KeychainKey.appleUserID)
        currentUser = nil
        isSignedIn = false
    }

    nonisolated func checkExistingCredential() async -> Bool {
        do {
            guard let userID = try keychainService.loadString(forKey: KeychainKey.appleUserID) else {
                return false
            }

            let provider = ASAuthorizationAppleIDProvider()
            let state = try await provider.credentialState(forUserID: userID)
            return state == .authorized
        } catch {
            return false
        }
    }

    private func saveUser(_ user: UserAccount) throws {
        let data = try JSONEncoder().encode(user)
        try keychainService.save(data, forKey: KeychainKey.userAccount)
        try keychainService.saveString(user.id, forKey: KeychainKey.appleUserID)
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthenticationService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                signInContinuation?.resume(throwing: AuthenticationError.invalidCredential)
                signInContinuation = nil
                return
            }

            var fullName: String?
            if let nameComponents = credential.fullName {
                let formatter = PersonNameComponentsFormatter()
                let name = formatter.string(from: nameComponents)
                if !name.isEmpty {
                    fullName = name
                }
            }

            let user = UserAccount(
                id: credential.user,
                email: credential.email,
                fullName: fullName ?? currentUser?.fullName,
                signInDate: Date()
            )

            do {
                try saveUser(user)
                currentUser = user
                isSignedIn = true
                signInContinuation?.resume(returning: user)
            } catch {
                signInContinuation?.resume(throwing: error)
            }
            signInContinuation = nil
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            if let authError = error as? ASAuthorizationError {
                switch authError.code {
                case .canceled:
                    signInContinuation?.resume(throwing: AuthenticationError.canceled)
                case .failed:
                    signInContinuation?.resume(throwing: AuthenticationError.failed)
                case .invalidResponse:
                    signInContinuation?.resume(throwing: AuthenticationError.invalidResponse)
                case .notHandled:
                    signInContinuation?.resume(throwing: AuthenticationError.notHandled)
                case .unknown:
                    signInContinuation?.resume(throwing: AuthenticationError.unknown)
                case .notInteractive:
                    signInContinuation?.resume(throwing: AuthenticationError.notInteractive)
                default:
                    signInContinuation?.resume(throwing: AuthenticationError.unknown)
                }
            } else {
                signInContinuation?.resume(throwing: error)
            }
            signInContinuation = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthenticationService: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            presentationWindow ?? ASPresentationAnchor()
        }
    }
}

// MARK: - Errors

enum AuthenticationError: Error, LocalizedError {
    case invalidCredential
    case canceled
    case failed
    case invalidResponse
    case notHandled
    case unknown
    case notInteractive

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            "Invalid credential received"
        case .canceled:
            "Sign in was canceled"
        case .failed:
            "Sign in failed"
        case .invalidResponse:
            "Invalid response from Apple"
        case .notHandled:
            "Request not handled"
        case .unknown:
            "An unknown error occurred"
        case .notInteractive:
            "Sign in requires interaction"
        }
    }
}
