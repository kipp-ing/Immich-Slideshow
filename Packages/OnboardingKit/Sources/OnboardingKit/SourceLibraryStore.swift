import Foundation

public protocol SourceLibraryStore: Sendable {
    func load() -> SourceLibrary
    func save(_ library: SourceLibrary)
    func clear()
}

public struct UserDefaultsSourceLibraryStore: SourceLibraryStore, @unchecked Sendable {
    private enum Keys {
        static let library = "immich.sourceLibrary"
        static let legacySelectedAlbumID = "immich.selectedAlbumID"
    }

    private let defaults: UserDefaults
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> SourceLibrary {
        if let data = defaults.data(forKey: Keys.library),
           let library = try? decoder.decode(SourceLibrary.self, from: data) {
            return library
        }

        guard
            defaults.object(forKey: Keys.library) == nil,
            let legacyAlbumID = defaults.string(forKey: Keys.legacySelectedAlbumID),
            !legacyAlbumID.isEmpty
        else {
            return SourceLibrary()
        }

        var library = SourceLibrary()
        library.add(Source(label: legacyAlbumID, kind: .album(albumID: legacyAlbumID)))
        save(library)
        return library
    }

    public func save(_ library: SourceLibrary) {
        guard let data = try? encoder.encode(library) else {
            return
        }

        defaults.set(data, forKey: Keys.library)
    }

    public func clear() {
        defaults.removeObject(forKey: Keys.library)
    }
}

public final class InMemorySourceLibraryStore: SourceLibraryStore, @unchecked Sendable {
    private var library: SourceLibrary

    public init(library: SourceLibrary = SourceLibrary()) {
        self.library = library
    }

    public func load() -> SourceLibrary {
        library
    }

    public func save(_ library: SourceLibrary) {
        self.library = library
    }

    public func clear() {
        library = SourceLibrary()
    }
}
