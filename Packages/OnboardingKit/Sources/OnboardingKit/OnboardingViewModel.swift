import Foundation
import ImmichClient
import Observation

@Observable public final class OnboardingViewModel {
    public var step: OnboardingStep = .connection
    public var serverURLInput: String = ""
    public var apiKeyInput: String = ""
    public var albums: [Album] = []
    public var selectedAlbumID: String?
    public var isBusy: Bool = false
    public var errorMessage: String?

    @ObservationIgnored private let api: (ServerConfig) -> any ImmichAPI
    @ObservationIgnored private let config: ConfigStore
    @ObservationIgnored private let keychain: KeychainStore

    public init(
        api: @escaping (ServerConfig) -> any ImmichAPI,
        config: ConfigStore,
        keychain: KeychainStore
    ) {
        self.api = api
        self.config = config
        self.keychain = keychain
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

        albums = list
        if list.isEmpty {
            errorMessage = String(localized: "No albums found. Create an album in Immich.", bundle: .module)
            return
        }

        step = .album
    }

    public func selectAlbum(id: String) async {
        errorMessage = nil

        guard let url = normalizedURL() else {
            errorMessage = String(localized: "Please enter a valid HTTPS address.", bundle: .module)
            return
        }

        selectedAlbumID = id
        config.save(AppConfiguration(baseURL: url, selectedAlbumID: id))
        step = .done
    }

    public func reset() {
        config.clear()
        keychain.delete()
        step = .connection
        serverURLInput = ""
        apiKeyInput = ""
        albums = []
        selectedAlbumID = nil
        errorMessage = nil
    }

    private func normalizedURL() -> URL? {
        ConnectionURL.normalize(serverURLInput)
    }
}
