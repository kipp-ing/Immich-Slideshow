import Foundation
import ImmichClient

public struct ResolvedSource: Sendable {
    public let serverConfig: ServerConfig
    public let albumID: String

    public init(serverConfig: ServerConfig, albumID: String) {
        self.serverConfig = serverConfig
        self.albumID = albumID
    }
}

public struct ActiveSourceResolver: Sendable {
    private let albumBaseURL: URL
    private let apiKey: String
    private let secretStore: any SharedLinkSecretStore
    private let sharedLinkResolver: any SharedLinkResolving

    public init(
        albumBaseURL: URL,
        apiKey: String,
        secretStore: any SharedLinkSecretStore,
        sharedLinkResolver: any SharedLinkResolving
    ) {
        self.albumBaseURL = albumBaseURL
        self.apiKey = apiKey
        self.secretStore = secretStore
        self.sharedLinkResolver = sharedLinkResolver
    }

    public func resolve(_ source: Source) async throws -> ResolvedSource {
        switch source.kind {
        case let .album(albumID):
            return ResolvedSource(
                serverConfig: ServerConfig(baseURL: albumBaseURL, auth: .apiKey(apiKey)),
                albumID: albumID
            )
        case let .sharedLink(baseURL, slug):
            let password = secretStore.readPassword(forSourceID: source.id)
            let resolution = try await sharedLinkResolver.resolve(baseURL: baseURL, slug: slug, password: password)
            return ResolvedSource(
                serverConfig: ServerConfig(baseURL: baseURL, auth: .shareKey(resolution.key)),
                albumID: resolution.albumID
            )
        }
    }
}
