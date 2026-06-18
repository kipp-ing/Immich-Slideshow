public struct StartupGate: Sendable {
    private let config: ConfigStore
    private let keychain: KeychainStore

    public init(config: ConfigStore, keychain: KeychainStore) {
        self.config = config
        self.keychain = keychain
    }

    public func initialStep() -> OnboardingStep {
        guard config.load() != nil else { return .server }
        return keychain.read() != nil ? .done : .apiKey
    }
}
