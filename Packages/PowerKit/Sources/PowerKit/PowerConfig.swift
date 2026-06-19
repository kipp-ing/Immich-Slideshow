public struct PowerConfig: Sendable, Equatable {
    public var softDimDuration: Duration
    public var softDimSteps: Int

    public init(softDimDuration: Duration, softDimSteps: Int) {
        self.softDimDuration = softDimDuration > .zero ? softDimDuration : .milliseconds(1)
        self.softDimSteps = max(softDimSteps, 2)
    }

    public static let `default` = PowerConfig(softDimDuration: .milliseconds(600), softDimSteps: 8)
}
