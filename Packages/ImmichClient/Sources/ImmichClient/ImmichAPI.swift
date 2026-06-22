import Foundation

public protocol ImmichAPI: Sendable {
    func serverVersion() async throws -> String
    func albums() async throws -> [Album]
    func assets(albumID: String) async throws -> [Asset]
    func assetInfo(assetID: String) async throws -> AssetInfo
    func preview(assetID: String) async throws -> Data
    func thumbnail(assetID: String) async throws -> Data
    func original(assetID: String) async throws -> Data
}

public extension ImmichAPI {
    func assetInfo(assetID: String) async throws -> AssetInfo {
        AssetInfo(id: assetID, takenAt: nil, city: nil, state: nil, country: nil)
    }

    func thumbnail(assetID: String) async throws -> Data {
        try await preview(assetID: assetID)
    }

    func original(assetID: String) async throws -> Data {
        try await preview(assetID: assetID)
    }
}
