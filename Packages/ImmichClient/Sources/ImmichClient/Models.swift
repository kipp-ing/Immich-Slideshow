import Foundation

public struct Album: Codable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name = "albumName"
    }
}

public struct Asset: Codable, Sendable {
    public let id: String
    public let type: String

    public init(id: String, type: String) {
        self.id = id
        self.type = type
    }
}

struct AlbumDetail: Decodable, Sendable {
    let assets: [Asset]
}

public struct AssetInfo: Sendable, Equatable {
    public let id: String
    public let takenAt: Date?
    public let city: String?
    public let state: String?
    public let country: String?

    public init(id: String, takenAt: Date?, city: String?, state: String?, country: String?) {
        self.id = id
        self.takenAt = takenAt
        self.city = city
        self.state = state
        self.country = country
    }
}

struct AssetDetail: Decodable, Sendable {
    let id: String
    let localDateTime: String?
    let fileCreatedAt: String?
    let exifInfo: ExifInfo?

    struct ExifInfo: Decodable, Sendable {
        let dateTimeOriginal: String?
        let city: String?
        let state: String?
        let country: String?
    }
}
