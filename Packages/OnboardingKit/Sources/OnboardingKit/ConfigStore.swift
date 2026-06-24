import Foundation

public protocol ConfigStore: Sendable {
    func load() -> AppConfiguration?
    func loadBaseURL() -> URL?
    func save(_ configuration: AppConfiguration)
    /// Persist only the server base URL, independent of any selected album. Used by
    /// onboarding once the connection is validated so a shared-link-first install (no
    /// album) still records its server address for later resolution (120).
    func saveBaseURL(_ baseURL: URL)
    func clear()
}

public extension ConfigStore {
    func loadBaseURL() -> URL? {
        load()?.baseURL
    }
}

public struct UserDefaultsConfigStore: ConfigStore, @unchecked Sendable {
    private enum Keys {
        static let baseURL = "immich.baseURL"
        static let selectedAlbumID = "immich.selectedAlbumID"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> AppConfiguration? {
        guard
            let baseURL = loadBaseURL(),
            let selectedAlbumID = defaults.string(forKey: Keys.selectedAlbumID),
            !selectedAlbumID.isEmpty
        else {
            return nil
        }

        return AppConfiguration(baseURL: baseURL, selectedAlbumID: selectedAlbumID)
    }

    public func loadBaseURL() -> URL? {
        guard
            let baseURLString = defaults.string(forKey: Keys.baseURL),
            let baseURL = URL(string: baseURLString),
            baseURL.scheme == "https",
            baseURL.host != nil
        else {
            return nil
        }

        return baseURL
    }

    public func save(_ configuration: AppConfiguration) {
        defaults.set(configuration.baseURL.absoluteString, forKey: Keys.baseURL)
        defaults.set(configuration.selectedAlbumID, forKey: Keys.selectedAlbumID)
    }

    public func saveBaseURL(_ baseURL: URL) {
        defaults.set(baseURL.absoluteString, forKey: Keys.baseURL)
    }

    public func clear() {
        defaults.removeObject(forKey: Keys.baseURL)
        defaults.removeObject(forKey: Keys.selectedAlbumID)
    }
}
