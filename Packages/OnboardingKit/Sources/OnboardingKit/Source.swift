import Foundation

public struct Source: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public var label: String
    public var kind: SourceKind

    public init(id: String = UUID().uuidString, label: String, kind: SourceKind) {
        self.id = id
        self.label = label
        self.kind = kind
    }
}

public enum SourceKind: Codable, Sendable, Equatable {
    case album(albumID: String)
    case sharedLink(baseURL: URL, slug: String)
}
