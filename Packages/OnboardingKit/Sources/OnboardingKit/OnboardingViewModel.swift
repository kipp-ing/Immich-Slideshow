import Foundation
import ImmichClient
import Observation

@Observable public final class OnboardingViewModel {
    public var step: OnboardingStep = .connection
    public var serverURLInput: String = ""
    public var apiKeyInput: String = ""
    public var albums: [Album] = []
    public var isBusy: Bool = false
    public var errorMessage: String?

    @ObservationIgnored private let api: (ServerConfig) -> any ImmichAPI
    @ObservationIgnored private let config: ConfigStore
    @ObservationIgnored private let keychain: KeychainStore
    @ObservationIgnored private let sourceStore: any SourceLibraryStore

    public init(
        api: @escaping (ServerConfig) -> any ImmichAPI,
        config: ConfigStore,
        keychain: KeychainStore,
        sourceStore: any SourceLibraryStore = InMemorySourceLibraryStore()
    ) {
        self.api = api
        self.config = config
        self.keychain = keychain
        self.sourceStore = sourceStore
    }

    public func submitConnection() async {
        guard !isBusy else { return }
        errorMessage = nil

        guard let url = normalizedURL() else {
            errorMessage = String(localized: "Please enter a valid HTTPS address.", bundle: .module)
            return
        }

        isBusy = true
        defer { isBusy = false }

        let list: [Album]
        do {
            list = try await api(ServerConfig(baseURL: url, apiKey: apiKeyInput)).albums()
        } catch let error as ImmichError {
            errorMessage = ConnectionError.message(for: error)
            return
        } catch {
            errorMessage = String(localized: "Unexpected response from the server.", bundle: .module)
            return
        }

        do {
            try keychain.save(apiKeyInput)
        } catch {
            errorMessage = String(localized: "Could not securely store the API key.", bundle: .module)
            return
        }

        // Connection validated — persist the server address so the active source can be
        // resolved later even when the first source is a shared link with no album (120).
        config.saveBaseURL(url)
        albums = list
        // An empty album list still proves the connection works; the user can add a shared
        // link on the next step, so advance rather than dead-end at connection (120, US2).
        step = .source
    }

    /// Load the album list for the source step when it isn't already in memory — e.g. when
    /// onboarding resumes at `.source` on a fresh launch. Best-effort: a failure leaves the
    /// list empty (the user can still add a shared link).
    public func loadAlbumsIfNeeded() async {
        guard albums.isEmpty, !isBusy,
              let url = config.loadBaseURL(), let key = keychain.read() else { return }
        albums = (try? await api(ServerConfig(baseURL: url, apiKey: key)).albums()) ?? []
    }

    /// Move from the add-source step to the confirmation step. The view guards this on the
    /// library having at least one source.
    public func proceedToConfirm() {
        errorMessage = nil
        step = .confirm
    }

    /// Return from confirmation to add another source.
    public func backToSource() {
        errorMessage = nil
        step = .source
    }

    /// Finish onboarding from the confirmation step and route to the running slideshow. An
    /// album active source keeps `AppConfiguration` fully populated so the legacy album
    /// paths (HA album list, 009 album re-select) keep working; a shared-link active source
    /// needs only the base URL already saved at connection (120).
    public func finish() {
        if case let .album(albumID)? = sourceStore.load().active?.kind,
           let url = config.loadBaseURL() ?? normalizedURL() {
            config.save(AppConfiguration(baseURL: url, selectedAlbumID: albumID))
        }
        step = .done
    }

    public func reset() {
        config.clear()
        keychain.delete()
        sourceStore.clear()
        step = .connection
        serverURLInput = ""
        apiKeyInput = ""
        albums = []
        errorMessage = nil
    }

    private func normalizedURL() -> URL? {
        ConnectionURL.normalize(serverURLInput)
    }
}
