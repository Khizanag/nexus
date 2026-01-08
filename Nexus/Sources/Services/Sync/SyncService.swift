import Foundation
import Combine
import CloudKit

enum SyncStatus: Equatable {
    case idle
    case syncing
    case synced(Date)
    case offline
    case notSignedIn
    case error(String)

    var displayText: String {
        switch self {
        case .idle:
            "Not synced"
        case .syncing:
            "Syncing..."
        case .synced(let date):
            "Synced \(date.timeAgoDisplay)"
        case .offline:
            "Offline"
        case .notSignedIn:
            "Sign in to sync"
        case .error(let message):
            "Sync error: \(message)"
        }
    }

    var isHealthy: Bool {
        switch self {
        case .synced, .syncing:
            true
        default:
            false
        }
    }
}

@MainActor
protocol SyncService: Sendable {
    var status: SyncStatus { get }
    var isSyncing: Bool { get }
    var lastSyncDate: Date? { get }

    func sync() async throws
    func startAutoSync()
    func stopAutoSync()
    func checkCloudKitStatus() async
}

@MainActor
@Observable
final class DefaultSyncService: SyncService {
    private(set) var status: SyncStatus = .idle
    private(set) var lastSyncDate: Date?

    var isSyncing: Bool {
        status == .syncing
    }

    private var syncTimer: AnyCancellable?
    private let syncInterval: TimeInterval = 300
    private let authService: AuthenticationService

    init(authService: AuthenticationService) {
        self.authService = authService
    }

    func sync() async throws {
        guard !isSyncing else { return }

        guard authService.isSignedIn else {
            status = .notSignedIn
            return
        }

        status = .syncing

        do {
            try await performSync()
            lastSyncDate = .now
            status = .synced(lastSyncDate!)
        } catch {
            status = .error(error.localizedDescription)
            throw error
        }
    }

    func startAutoSync() {
        stopAutoSync()

        Task {
            await checkCloudKitStatus()
        }

        syncTimer = Timer
            .publish(every: syncInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    try? await self?.sync()
                }
            }
    }

    func stopAutoSync() {
        syncTimer?.cancel()
        syncTimer = nil
    }

    func checkCloudKitStatus() async {
        guard authService.isSignedIn else {
            status = .notSignedIn
            return
        }

        do {
            let accountStatus = try await CKContainer.default().accountStatus()
            switch accountStatus {
            case .available:
                if lastSyncDate != nil {
                    status = .synced(lastSyncDate!)
                } else {
                    status = .idle
                }
            case .noAccount:
                status = .notSignedIn
            case .restricted, .couldNotDetermine:
                status = .error("iCloud not available")
            case .temporarilyUnavailable:
                status = .offline
            @unknown default:
                status = .error("Unknown iCloud status")
            }
        } catch {
            status = .offline
        }
    }

    private func performSync() async throws {
        try await Task.sleep(for: .milliseconds(500))
    }
}

// MARK: - Date Extension

private extension Date {
    var timeAgoDisplay: String {
        let interval = Date().timeIntervalSince(self)
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}
