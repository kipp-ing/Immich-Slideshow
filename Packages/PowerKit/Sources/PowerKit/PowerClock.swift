public protocol PowerClock: Sendable {
    func sleep(for duration: Duration) async throws
}

public struct RealClock: PowerClock {
    public init() {}

    public func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}
