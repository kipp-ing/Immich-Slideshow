import Foundation

public struct ServerConfig: Sendable {
    public let baseURL: URL
    public let auth: Auth

    public enum Auth: Sendable, Equatable {
        case apiKey(String)
        case shareKey(String)
    }

    public var apiKey: String {
        guard case let .apiKey(apiKey) = auth else {
            return ""
        }
        return apiKey
    }

    public init(baseURL: URL, apiKey: String) {
        self.baseURL = baseURL
        self.auth = .apiKey(apiKey)
    }

    public init(baseURL: URL, auth: Auth) {
        self.baseURL = baseURL
        self.auth = auth
    }
}
