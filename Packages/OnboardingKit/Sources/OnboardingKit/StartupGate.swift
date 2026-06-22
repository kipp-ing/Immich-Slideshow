public struct StartupGate: Sendable {
    private let config: ConfigStore
    private let keychain: KeychainStore

    public init(config: ConfigStore, keychain: KeychainStore) {
        self.config = config
        self.keychain = keychain
    }

    public func initialStep() -> OnboardingStep {
        // Server URL and API key are now collected on one screen (.connection), so any
        // incomplete configuration — missing config or missing key — starts there.
        guard config.load() != nil, keychain.read() != nil else { return .connection }
        return .done
    }
}
