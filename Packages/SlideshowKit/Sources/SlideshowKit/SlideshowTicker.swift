import Foundation

/// Timing seam for the automatic photo advance. Separates "when" (the interval) from
/// "what" (advancing) so advances are deterministically testable without real waiting
/// (Constitution II). The interval is passed in per cycle so the engine can supply the
/// live `ThemeSettings.duration` and have a duration change re-arm the timer without a
/// restart (008, review R1).
public protocol SlideshowTicker: Sendable {
    /// Returns at the next due tick after waiting `duration`. Throws `CancellationError`
    /// when the in-flight tick is cancelled (for `pause()`/teardown).
    func waitForNextTick(duration: Duration) async throws
}

/// Production clock: sleeps for the requested `duration` via Swift Concurrency; respects
/// cancellation.
public struct RealTicker: SlideshowTicker {
    public init() {}

    public func waitForNextTick(duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}
