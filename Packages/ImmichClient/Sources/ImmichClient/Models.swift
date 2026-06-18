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

public struct Asset: Sendable {
    public let id: String
    public let type: String

    public init(id: String, type: String) {
        self.id = id
        self.type = type
    }
}
