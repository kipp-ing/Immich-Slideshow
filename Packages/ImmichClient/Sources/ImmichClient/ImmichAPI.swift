import Foundation

public protocol ImmichAPI: Sendable {
    func serverVersion() async throws -> String
    func albums() async throws -> [Album]
    func assets(albumID: String) async throws -> [Asset]
    func preview(assetID: String) async throws -> Data
    func thumbnail(assetID: String) async throws -> Data
}

public extension ImmichAPI {
    func thumbnail(assetID: String) async throws -> Data {
        try await preview(assetID: assetID)
    }
}
