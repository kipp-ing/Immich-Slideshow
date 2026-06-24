public struct StartupGate: Sendable {
    private let config: ConfigStore
    private let keychain: KeychainStore
    private let sourceStore: any SourceLibraryStore

    public init(config: ConfigStore, keychain: KeychainStore, sourceStore: any SourceLibraryStore) {
        self.config = config
        self.keychain = keychain
        self.sourceStore = sourceStore
    }

    public func initialStep() -> OnboardingStep {
        // Server URL and API key are collected on one screen (.connection), so any state
        // without the API key or the server base URL starts there. With the connection in
        // place, the active source — not a single selectedAlbumID — decides the rest (120):
        // a saved active source routes straight to the slideshow; otherwise resume at the
        // add-source step. `load()` migrates a legacy selectedAlbumID into a one-entry
        // library, so existing installs still resolve to `.done`.
        guard keychain.read() != nil else { return .connection }
        guard config.loadBaseURL() != nil else { return .connection }
        if sourceStore.load().active != nil {
            return .done
        }
        return .source
    }
}
