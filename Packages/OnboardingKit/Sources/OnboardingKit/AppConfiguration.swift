import Foundation

public struct AppConfiguration: Sendable, Equatable {
    public let baseURL: URL
    public let selectedAlbumID: String

    public init(baseURL: URL, selectedAlbumID: String) {
        self.baseURL = baseURL
        self.selectedAlbumID = selectedAlbumID
    }
}
