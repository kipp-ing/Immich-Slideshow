import Foundation
import ImmichClient
import Observation

@Observable public final class OnboardingViewModel {
    public var step: OnboardingStep = .server
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

    public func submitServerURL() async {
        guard !isBusy else { return }
        errorMessage = nil

        guard let url = normalizedURL() else {
            errorMessage = "Bitte eine gültige HTTPS-Adresse eingeben."
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            _ = try await api(ServerConfig(baseURL: url, apiKey: "")).serverVersion()
            step = .apiKey
        } catch let error as ImmichError {
            errorMessage = message(for: error)
        } catch {
            errorMessage = "Unerwartete Antwort vom Server."
        }
    }

    public func submitAPIKey() async {
        guard !isBusy else { return }
        errorMessage = nil

        guard let url = normalizedURL() else {
            errorMessage = "Bitte eine gültige HTTPS-Adresse eingeben."
            return
        }

        isBusy = true
        defer { isBusy = false }

        let list: [Album]
        do {
            list = try await api(ServerConfig(baseURL: url, apiKey: apiKeyInput)).albums()
        } catch let error as ImmichError {
            errorMessage = message(for: error)
            return
        } catch {
            errorMessage = "Unerwartete Antwort vom Server."
            return
        }

        do {
            try keychain.save(apiKeyInput)
        } catch {
            errorMessage = "API-Key konnte nicht sicher gespeichert werden."
            return
        }

        albums = list
        if list.isEmpty {
            errorMessage = "Keine Alben gefunden. Lege in Immich ein Album an."
            return
        }

        step = .album
    }

    public func selectAlbum(id: String) async {
        errorMessage = nil

        guard let url = normalizedURL() else {
            errorMessage = "Bitte eine gültige HTTPS-Adresse eingeben."
            return
        }

        selectedAlbumID = id
        config.save(AppConfiguration(baseURL: url, selectedAlbumID: id))
        step = .done
    }

    public func reset() {
        config.clear()
        keychain.delete()
        step = .server
        serverURLInput = ""
        apiKeyInput = ""
        albums = []
        selectedAlbumID = nil
        errorMessage = nil
    }

    private func normalizedURL() -> URL? {
        let trimmed = serverURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let urlString = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard
            let url = URL(string: urlString),
            url.scheme == "https",
            url.host != nil
        else {
            return nil
        }

        return url
    }

    private func message(for error: ImmichError) -> String {
        switch error {
        case .unauthorized:
            "Ungültiger API-Key."
        case .unreachable:
            "Server nicht erreichbar."
        case .invalidResponse:
            "Unerwartete Antwort vom Server."
        }
    }
}
