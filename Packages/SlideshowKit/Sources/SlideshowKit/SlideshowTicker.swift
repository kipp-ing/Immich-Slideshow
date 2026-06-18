import Foundation

/// Zeit-Naht für den automatischen Bildwechsel. Trennt „wann" (Intervall) von „was" (Vorrücken),
/// damit Wechsel deterministisch ohne echte Wartezeit testbar sind (Konstitution II).
public protocol SlideshowTicker: Sendable {
    /// Kehrt beim nächsten fälligen Tick zurück. Wirft `CancellationError`, wenn der laufende Tick
    /// abgebrochen wird (für `pause()`/Teardown).
    func waitForNextTick() async throws
}

/// Produktive Uhr: wartet `interval` über die Swift-Concurrency-Uhr; respektiert Cancellation.
public struct RealTicker: SlideshowTicker {
    private let interval: Duration

    public init(interval: Duration) {
        self.interval = interval
    }

    public func waitForNextTick() async throws {
        try await Task.sleep(for: interval)
    }
}
