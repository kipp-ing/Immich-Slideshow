import Foundation
import Testing
@testable import OnboardingKit

@Test func sourceLibraryFirstAddBecomesActive() {
    var library = SourceLibrary()
    let source = Source(id: "source-1", label: "Family", kind: .album(albumID: "album-1"))

    library.add(source)

    #expect(library.sources == [source])
    #expect(library.activeID == "source-1")
    #expect(library.active == source)
}

@Test func sourceLibraryRejectsDuplicateLabels() {
    var library = SourceLibrary()
    library.add(Source(id: "source-1", label: "Family", kind: .album(albumID: "album-1")))

    library.add(Source(id: "source-2", label: "Family", kind: .album(albumID: "album-2")))

    #expect(library.sources.map(\.id) == ["source-1"])
}

@Test func sourceLibraryRemoveActivePromotesFirstRemainingSource() {
    var library = SourceLibrary()
    library.add(Source(id: "source-1", label: "Family", kind: .album(albumID: "album-1")))
    library.add(Source(id: "source-2", label: "Travel", kind: .album(albumID: "album-2")))
    library.setActive(id: "source-2")

    library.remove(id: "source-2")

    #expect(library.sources.map(\.id) == ["source-1"])
    #expect(library.activeID == "source-1")
}

@Test func sourceLibraryRemoveActivePromotesNextRemainingSourceWhenAvailable() {
    var library = SourceLibrary()
    library.add(Source(id: "source-1", label: "Family", kind: .album(albumID: "album-1")))
    library.add(Source(id: "source-2", label: "Travel", kind: .album(albumID: "album-2")))
    library.add(Source(id: "source-3", label: "Shared", kind: .sharedLink(baseURL: URL(string: "https://photos.example.test")!, slug: "shared")))
    library.setActive(id: "source-2")

    library.remove(id: "source-2")

    #expect(library.sources.map(\.id) == ["source-1", "source-3"])
    #expect(library.activeID == "source-3")
}

@Test func sourceLibraryRemoveLastActiveClearsActiveID() {
    var library = SourceLibrary()
    library.add(Source(id: "source-1", label: "Family", kind: .album(albumID: "album-1")))

    library.remove(id: "source-1")

    #expect(library.sources.isEmpty)
    #expect(library.activeID == nil)
}

@Test func sourceLibraryDecodingRestoresActiveInvariant() throws {
    let json = """
    {
      "sources": [
        { "id": "source-1", "label": "Family", "kind": { "album": { "albumID": "album-1" } } }
      ],
      "activeID": "missing"
    }
    """

    let library = try JSONDecoder().decode(SourceLibrary.self, from: Data(json.utf8))

    #expect(library.activeID == "source-1")
}

@Test func sourceLibraryMovesSourcesWithoutChangingActive() {
    var library = SourceLibrary()
    library.add(Source(id: "source-1", label: "Family", kind: .album(albumID: "album-1")))
    library.add(Source(id: "source-2", label: "Travel", kind: .album(albumID: "album-2")))
    library.add(Source(id: "source-3", label: "Shared", kind: .sharedLink(baseURL: URL(string: "https://photos.example.test")!, slug: "shared")))
    library.setActive(id: "source-2")

    library.move(from: IndexSet(integer: 2), to: 0)

    #expect(library.sources.map(\.id) == ["source-3", "source-1", "source-2"])
    #expect(library.activeID == "source-2")
}

@Test func sourceLibraryRenameEnforcesUniqueNonEmptyLabel() {
    var library = SourceLibrary()
    library.add(Source(id: "source-1", label: "Family", kind: .album(albumID: "album-1")))
    library.add(Source(id: "source-2", label: "Travel", kind: .album(albumID: "album-2")))

    library.rename(id: "source-2", to: "Family")
    #expect(library.sources[1].label == "Travel")

    library.rename(id: "source-2", to: "")
    #expect(library.sources[1].label == "Travel")

    library.rename(id: "source-2", to: "Summer")
    #expect(library.sources[1].label == "Summer")
}

@Test func sourceLibrarySetActiveIgnoresUnknownIDs() {
    var library = SourceLibrary()
    library.add(Source(id: "source-1", label: "Family", kind: .album(albumID: "album-1")))

    library.setActive(id: "missing")

    #expect(library.activeID == "source-1")
}
