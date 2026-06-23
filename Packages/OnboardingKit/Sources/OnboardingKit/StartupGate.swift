public struct StartupGate: Sendable {
    private let config: ConfigStore
    private let keychain: KeychainStore

    public init(config: ConfigStore, keychain: KeychainStore) {
        self.config = config
        self.keychain = keychain
    }

    public func initialStep() -> OnboardingStep {
        // Server URL and API key are now collected on one screen (.connection), so any
        // state without both of those pieces starts there. If the connection is
        // present but the album is missing, resume at album selection.
        guard keychain.read() != nil else { return .connection }
        if config.load() != nil {
            return .done
        }
        if config.loadBaseURL() != nil {
            return .album
        }
        return .connection
    }
}
