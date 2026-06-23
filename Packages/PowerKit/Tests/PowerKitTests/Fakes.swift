import Foundation
import PowerKit

@MainActor
final class FakeScreenController: ScreenControlling {
    var brightnessWrites: [Double] = []
    private var _brightness: Double
    var isIdleTimerDisabled: Bool = false

    init(brightness: Double = 0.5) {
        _brightness = brightness
    }

    var brightness: Double {
        get { _brightness }
        set {
            _brightness = newValue
            brightnessWrites.append(newValue)
        }
    }
}

struct ManualClock: PowerClock {
    func sleep(for duration: Duration) async throws {}
}

final class BlockingManualClock: PowerClock, @unchecked Sendable {
    private let lock = NSLock()
    private var sleepers: [CheckedContinuation<Void, any Error>] = []
    private var observers: [CheckedContinuation<Void, Never>] = []

    var sleepingCount: Int {
        lock.withLock { sleepers.count }
    }

    func sleep(for duration: Duration) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.withLock {
                    sleepers.append(continuation)
                    observers.forEach { $0.resume() }
                    observers.removeAll()
                }
            }
        } onCancel: {
            cancelOne()
        }
    }

    func advanceOne() {
        let sleeper = lock.withLock {
            sleepers.isEmpty ? nil : sleepers.removeFirst()
        }
        sleeper?.resume()
    }

    func waitUntilSleeping() async {
        await withCheckedContinuation { continuation in
            lock.withLock {
                if sleepers.isEmpty {
                    observers.append(continuation)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func cancelOne() {
        let sleeper = lock.withLock {
            sleepers.isEmpty ? nil : sleepers.removeFirst()
        }
        sleeper?.resume(throwing: CancellationError())
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
