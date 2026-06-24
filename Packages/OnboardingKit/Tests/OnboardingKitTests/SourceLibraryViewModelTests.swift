import Foundation
import ImmichClient
import Testing
@testable import OnboardingKit

@MainActor
@Test func sourceLibraryViewModelLoadsLibraryOnInit() {
    var seeded = SourceLibrary()
    seeded.add(Source(id: "source-1", label: "Family", kind: .album(albumID: "album-1")))
    let store = InMemorySourceLibraryStore(library: seeded)

    let viewModel = makeViewModel(store: store)

    #expect(viewModel.sources.map(\.id) == ["source-1"])
    #expect(viewModel.activeID == "source-1")
}

@MainActor
@Test func sourceLibraryViewModelAddAlbumSourcePersistsAndActivatesFirst() {
    let store = InMemorySourceLibraryStore()
    let viewModel = makeViewModel(store: store)

    viewModel.addAlbumSource(albumID: "album-1", label: "Living Room")

    #expect(viewModel.sources.count == 1)
    #expect(viewModel.sources[0].kind == .album(albumID: "album-1"))
    #expect(viewModel.activeID == viewModel.sources[0].id)
    #expect(store.load().sources.map(\.label) == ["Living Room"])
}

@MainActor
@Test func sourceLibraryViewModelRejectsDuplicateLabel() {
    let store = InMemorySourceLibraryStore()
    let viewModel = makeViewModel(store: store)
    viewModel.addAlbumSource(albumID: "album-1", label: "Family")

    viewModel.addAlbumSource(albumID: "album-2", label: "Family")

    #expect(viewModel.sources.count == 1)
    #expect(viewModel.errorMessage != nil)
}

@MainActor
@Test func sourceLibraryViewModelAddSharedLinkResolvesStoresPasswordAndPersists() async {
    let store = InMemorySourceLibraryStore()
    let secretStore = InMemorySharedLinkSecretStore()
    let resolver = StubResolver(result: .success(SharedLinkResolution(key: "k", albumID: "a", expiresAt: nil)))
    let viewModel = makeViewModel(store: store, secretStore: secretStore, resolver: resolver)

    await viewModel.addSharedLinkSource(urlString: "https://bilder.kippings.de/s/geo2026", password: "pw", label: "Geo")

    #expect(viewModel.errorMessage == nil)
    #expect(viewModel.sources.count == 1)
    #expect(viewModel.sources[0].kind == .sharedLink(baseURL: URL(string: "https://bilder.kippings.de")!, slug: "geo2026"))
    #expect(secretStore.readPassword(forSourceID: viewModel.sources[0].id) == "pw")
    #expect(resolver.requests.first?.slug == "geo2026")
    #expect(store.load().sources.count == 1)
}

@MainActor
@Test func sourceLibraryViewModelAddSharedLinkWithoutPasswordStoresNoSecret() async {
    let secretStore = InMemorySharedLinkSecretStore()
    let viewModel = makeViewModel(secretStore: secretStore, resolver: StubResolver())

    await viewModel.addSharedLinkSource(urlString: "https://bilder.kippings.de/s/geo2026", password: nil, label: "Geo")

    #expect(viewModel.sources.count == 1)
    #expect(secretStore.readPassword(forSourceID: viewModel.sources[0].id) == nil)
}

@MainActor
@Test func sourceLibraryViewModelAddSharedLinkRejectsInvalidURL() async {
    let viewModel = makeViewModel(resolver: StubResolver())

    await viewModel.addSharedLinkSource(urlString: "not a url", password: nil, label: "Bad")

    #expect(viewModel.sources.isEmpty)
    #expect(viewModel.errorMessage != nil)
}

@MainActor
@Test func sourceLibraryViewModelAddSharedLinkSurfacesResolveErrorAndPersistsNothing() async {
    let store = InMemorySourceLibraryStore()
    let secretStore = InMemorySharedLinkSecretStore()
    let resolver = StubResolver(result: .failure(ImmichError.wrongPassword))
    let viewModel = makeViewModel(store: store, secretStore: secretStore, resolver: resolver)

    await viewModel.addSharedLinkSource(urlString: "https://bilder.kippings.de/s/geo2026", password: "bad", label: "Geo")

    #expect(viewModel.sources.isEmpty)
    #expect(viewModel.errorMessage == ConnectionError.message(for: .wrongPassword))
    #expect(store.load().sources.isEmpty)
}

@MainActor
@Test func sourceLibraryViewModelRemoveSharedLinkDeletesPassword() async {
    let store = InMemorySourceLibraryStore()
    let secretStore = InMemorySharedLinkSecretStore()
    let viewModel = makeViewModel(store: store, secretStore: secretStore, resolver: StubResolver())
    await viewModel.addSharedLinkSource(urlString: "https://bilder.kippings.de/s/geo2026", password: "pw", label: "Geo")
    let id = viewModel.sources[0].id

    viewModel.remove(id: id)

    #expect(viewModel.sources.isEmpty)
    #expect(secretStore.readPassword(forSourceID: id) == nil)
    #expect(store.load().sources.isEmpty)
}

@MainActor
@Test func sourceLibraryViewModelRenameAndMovePersist() {
    let store = InMemorySourceLibraryStore()
    let viewModel = makeViewModel(store: store)
    viewModel.addAlbumSource(albumID: "album-1", label: "Family")
    viewModel.addAlbumSource(albumID: "album-2", label: "Travel")

    viewModel.rename(id: viewModel.sources[1].id, to: "Summer")
    viewModel.move(from: IndexSet(integer: 1), to: 0)

    #expect(store.load().sources.map(\.label) == ["Summer", "Family"])
}

@MainActor
@Test func sourceLibraryViewModelSetActiveDelegatesAndReflectsReload() {
    var seeded = SourceLibrary()
    seeded.add(Source(id: "source-1", label: "Family", kind: .album(albumID: "album-1")))
    seeded.add(Source(id: "source-2", label: "Travel", kind: .album(albumID: "album-2")))
    let store = InMemorySourceLibraryStore(library: seeded)
    var switched: [String] = []
    // The app layer owns persisting the active change (US1 switchActiveSource); the VM
    // delegates and then reflects the reloaded library.
    let viewModel = makeViewModel(store: store, onSwitchActive: { id in
        switched.append(id)
        var lib = store.load()
        lib.setActive(id: id)
        store.save(lib)
    })

    viewModel.setActive(id: "source-2")

    #expect(switched == ["source-2"])
    #expect(viewModel.activeID == "source-2")
}

@MainActor
@Test func sourceLibraryViewModelSetActiveIgnoresUnknownAndAlreadyActive() {
    var seeded = SourceLibrary()
    seeded.add(Source(id: "source-1", label: "Family", kind: .album(albumID: "album-1")))
    let store = InMemorySourceLibraryStore(library: seeded)
    var switched: [String] = []
    let viewModel = makeViewModel(store: store, onSwitchActive: { switched.append($0) })

    viewModel.setActive(id: "source-1") // already active
    viewModel.setActive(id: "missing")  // unknown

    #expect(switched.isEmpty)
}

// MARK: - Helpers

@MainActor
private func makeViewModel(
    store: InMemorySourceLibraryStore = InMemorySourceLibraryStore(),
    secretStore: InMemorySharedLinkSecretStore = InMemorySharedLinkSecretStore(),
    resolver: StubResolver = StubResolver(),
    onSwitchActive: @escaping (String) -> Void = { _ in }
) -> SourceLibraryViewModel {
    SourceLibraryViewModel(
        store: store,
        secretStore: secretStore,
        resolver: resolver,
        onSwitchActive: onSwitchActive
    )
}

private final class StubResolver: SharedLinkResolving, @unchecked Sendable {
    struct Request: Equatable {
        let baseURL: URL
        let slug: String
        let password: String?
    }

    private let result: Result<SharedLinkResolution, Error>
    private(set) var requests: [Request] = []

    init(result: Result<SharedLinkResolution, Error> = .success(SharedLinkResolution(key: "k", albumID: "a", expiresAt: nil))) {
        self.result = result
    }

    func resolve(baseURL: URL, slug: String, password: String?) async throws -> SharedLinkResolution {
        requests.append(Request(baseURL: baseURL, slug: slug, password: password))
        return try result.get()
    }
}
