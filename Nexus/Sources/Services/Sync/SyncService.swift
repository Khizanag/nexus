import Foundation
import Combine

@MainActor
protocol SyncServiceProtocol: Sendable {
    var isSyncing: Bool { get }
    var lastSyncDate: Date? { get }

    func sync() async throws
    func startAutoSync()
    func stopAutoSync()
}

@MainActor
final class SyncService: SyncServiceProtocol {
    private(set) var isSyncing = false
    private(set) var lastSyncDate: Date?

    private var syncTimer: AnyCancellable?
    private let syncInterval: TimeInterval = 300

    init() {}

    func sync() async throws {
        guard !isSyncing else { return }

        isSyncing = true

        defer {
            isSyncing = false
            lastSyncDate = .now
        }

        try await performSync()
    }

    func startAutoSync() {
        stopAutoSync()

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

    private func performSync() async throws {
        try await Task.sleep(for: .seconds(1))
    }
}
