import Foundation
import ImmichClient
import SlideshowKit
import ThemeKit
import ThemeKitTestSupport

/// A deterministic settings store for the engine tests that assert album-order
/// behavior. Sequential order keeps `start()`/`advance()` walking the album in a
/// predictable sequence; tests that exercise shuffle inject their own store.
@MainActor
func sequentialThemeStore(duration: Duration = .seconds(15)) -> InMemoryThemeStore {
    InMemoryThemeStore(settings: ThemeSettings(order: .sequential, duration: duration))
}

final class ManualTicker: SlideshowTicker, @unchecked Sendable {
    private let lock = NSLock()
    private var waiters: [CheckedContinuation<Void, any Error>] = []
    private var waiterObservers: [CheckedContinuation<Void, Never>] = []
    private var consumedObservers: [CheckedContinuation<Void, Never>] = []
    private var consumedTickCount = 0

    func waitForNextTick() async throws {
        if Task.isCancelled {
            throw CancellationError()
        }

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.withLock {
                    waiters.append(continuation)
                    waiterObservers.forEach { $0.resume() }
                    waiterObservers.removeAll()
                }
            }
        } onCancel: {
            lock.withLock {
                guard !waiters.isEmpty else { return }
                let waiter = waiters.removeFirst()
                waiter.resume(throwing: CancellationError())
            }
        }

        lock.withLock {
            consumedTickCount += 1
            consumedObservers.forEach { $0.resume() }
            consumedObservers.removeAll()
        }
    }

    func tick() {
        let waiter = lock.withLock {
            waiters.isEmpty ? nil : waiters.removeFirst()
        }

        waiter?.resume()
    }

    func waitUntilWaiting() async {
        await withCheckedContinuation { continuation in
            lock.withLock {
                if waiters.isEmpty {
                    waiterObservers.append(continuation)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func waitUntilConsumedTickCount(_ expectedCount: Int) async {
        await withCheckedContinuation { continuation in
            lock.withLock {
                if consumedTickCount >= expectedCount {
                    continuation.resume()
                } else {
                    consumedObservers.append(continuation)
                }
            }
        }
    }
}

final class StubImmichAPI: ImmichAPI, @unchecked Sendable {
    private struct State {
        var assetsByAlbumID: [String: [Asset]] = [:]
        var previewDataByAssetID: [String: Data] = [:]
        var previewErrorsByAssetID: [String: any Error] = [:]
        var assetErrorsByAlbumID: [String: any Error] = [:]
        var albumList: [Album] = []
        var serverVersion = "stub"
        var serverVersionCallCount = 0
        var albumsCallCount = 0
        var assetsCallCount = 0
        var previewCallCount = 0
        var previewCallCountByAssetID: [String: Int] = [:]
    }

    private let lock = NSLock()
    private var state = State()

    func setAssets(_ assets: [Asset], for albumID: String) {
        lock.withLock {
            state.assetsByAlbumID[albumID] = assets
            state.assetErrorsByAlbumID[albumID] = nil
        }
    }

    func setAssetsError(_ error: any Error, for albumID: String) {
        lock.withLock {
            state.assetErrorsByAlbumID[albumID] = error
            state.assetsByAlbumID[albumID] = nil
        }
    }

    func setPreviewData(_ data: Data, for assetID: String) {
        lock.withLock {
            state.previewDataByAssetID[assetID] = data
            state.previewErrorsByAssetID[assetID] = nil
        }
    }

    func setPreviewError(_ error: any Error, for assetID: String) {
        lock.withLock {
            state.previewErrorsByAssetID[assetID] = error
            state.previewDataByAssetID[assetID] = nil
        }
    }

    func serverVersion() async throws -> String {
        lock.withLock {
            state.serverVersionCallCount += 1
            return state.serverVersion
        }
    }

    func albums() async throws -> [Album] {
        lock.withLock {
            state.albumsCallCount += 1
            return state.albumList
        }
    }

    func assets(albumID: String) async throws -> [Asset] {
        try lock.withLock {
            state.assetsCallCount += 1
            if let error = state.assetErrorsByAlbumID[albumID] {
                throw error
            }
            return state.assetsByAlbumID[albumID] ?? []
        }
    }

    func preview(assetID: String) async throws -> Data {
        try lock.withLock {
            state.previewCallCount += 1
            state.previewCallCountByAssetID[assetID, default: 0] += 1

            if let error = state.previewErrorsByAssetID[assetID] {
                throw error
            }

            return state.previewDataByAssetID[assetID] ?? Data(assetID.utf8)
        }
    }

    var albumsCallCount: Int {
        lock.withLock { state.albumsCallCount }
    }

    var assetsCallCount: Int {
        lock.withLock { state.assetsCallCount }
    }

    var previewCallCount: Int {
        lock.withLock { state.previewCallCount }
    }

    func previewCallCount(for assetID: String) -> Int {
        lock.withLock { state.previewCallCountByAssetID[assetID, default: 0] }
    }
}

extension NSLock {
    @discardableResult
    fileprivate func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
