import Foundation
import OnboardingKit

final class InMemoryConfigStore: ConfigStore, @unchecked Sendable {
    private var configuration: AppConfiguration?

    init(configuration: AppConfiguration? = nil) {
        self.configuration = configuration
    }

    func load() -> AppConfiguration? {
        configuration
    }

    func save(_ configuration: AppConfiguration) {
        self.configuration = configuration
    }

    func clear() {
        configuration = nil
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
