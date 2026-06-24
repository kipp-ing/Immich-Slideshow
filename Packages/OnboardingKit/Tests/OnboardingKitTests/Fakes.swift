import Foundation
import OnboardingKit

final class InMemoryConfigStore: ConfigStore, @unchecked Sendable {
    private var baseURL: URL?
    private var selectedAlbumID: String?

    init(configuration: AppConfiguration? = nil) {
        self.baseURL = configuration?.baseURL
        self.selectedAlbumID = configuration?.selectedAlbumID
    }

    func load() -> AppConfiguration? {
        guard let baseURL, let selectedAlbumID, !selectedAlbumID.isEmpty else { return nil }
        return AppConfiguration(baseURL: baseURL, selectedAlbumID: selectedAlbumID)
    }

    func loadBaseURL() -> URL? {
        baseURL
    }

    func save(_ configuration: AppConfiguration) {
        baseURL = configuration.baseURL
        selectedAlbumID = configuration.selectedAlbumID
    }

    func saveBaseURL(_ baseURL: URL) {
        self.baseURL = baseURL
    }

    func clear() {
        baseURL = nil
        selectedAlbumID = nil
    }
}

final class InMemoryKeychainStore: KeychainStore, @unchecked Sendable {
    enum SaveError: Error, Equatable {
        case forced
    }

    private let failSave: Bool
    private var apiKey: String?

    init(apiKey: String? = nil, failSave: Bool = false) {
        self.apiKey = apiKey
        self.failSave = failSave
    }

    func save(_ apiKey: String) throws {
        if failSave {
            throw SaveError.forced
        }

        self.apiKey = apiKey
    }

    func read() -> String? {
        apiKey
    }

    func delete() {
        apiKey = nil
    }
}
