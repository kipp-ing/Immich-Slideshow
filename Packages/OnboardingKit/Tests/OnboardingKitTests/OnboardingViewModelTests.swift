import Foundation
import Testing
@testable import OnboardingKit
import ImmichClient

@Test func rejectsNonHTTPSURL() async {
    let api = AlbumsAPI(result: .failure(ImmichError.unreachable))
    let vm = makeVM(api: api)
    vm.serverURLInput = "http://foo"
    vm.apiKeyInput = "key"

    await vm.submitConnection()

    #expect(vm.step == .connection)
    #expect(vm.errorMessage != nil)
    #expect(await api.albumsCallCount == 0)
}

@Test func advancesToSourceWhenReachableAndAuthorized() async throws {
    let keychain = InMemoryKeychainStore()
    let config = InMemoryConfigStore()
    let api = AlbumsAPI(result: .success([Album(id: "a1", name: "Fam")]))
    let vm = makeVM(api: api, config: config, keychain: keychain)
    vm.serverURLInput = "https://photos.example.test"
    vm.apiKeyInput = "key"

    await vm.submitConnection()

    #expect(vm.step == .source)
    #expect(keychain.read() == "key")
    // The base URL is persisted at connection so a shared-link-first source still resolves.
    #expect(config.loadBaseURL()?.host == "photos.example.test")
    #expect(vm.albums.map(\.id) == ["a1"])
    #expect(vm.errorMessage == nil)
    #expect(await api.albumsCallCount == 1)
}

@Test func advancesToSourceEvenWhenAlbumListEmpty() async throws {
    // An empty album list still proves the connection works; the user can add a shared
    // link on the source step, so onboarding advances instead of erroring (120, US2).
    let keychain = InMemoryKeychainStore()
    let config = InMemoryConfigStore()
    let api = AlbumsAPI(result: .success([]))
    let vm = makeVM(api: api, config: config, keychain: keychain)
    vm.serverURLInput = "https://photos.example.test"
    vm.apiKeyInput = "key"

    await vm.submitConnection()

    #expect(vm.step == .source)
    #expect(keychain.read() == "key")
    #expect(config.loadBaseURL()?.host == "photos.example.test")
    #expect(vm.albums.isEmpty)
    #expect(vm.errorMessage == nil)
}

@Test func finishWithActiveAlbumSourcePersistsConfigurationAndCompletes() async throws {
    let config = InMemoryConfigStore()
    var library = SourceLibrary()
    library.add(Source(label: "Fam", kind: .album(albumID: "a1")))
    let sourceStore = InMemorySourceLibraryStore(library: library)
    let vm = makeVM(api: AlbumsAPI(result: .success([])), config: config, sourceStore: sourceStore)
    config.saveBaseURL(URL(string: "https://photos.example.test")!)
    vm.step = .confirm

    vm.finish()

    #expect(vm.step == .done)
    let saved = config.load()
    #expect(saved?.selectedAlbumID == "a1")
    #expect(saved?.baseURL.host == "photos.example.test")
}

@Test func finishWithActiveSharedLinkSourceCompletesWithoutSelectedAlbum() async throws {
    let config = InMemoryConfigStore()
    var library = SourceLibrary()
    library.add(Source(label: "Korsika", kind: .sharedLink(baseURL: URL(string: "https://bilder.example.test")!, slug: "korsika")))
    let sourceStore = InMemorySourceLibraryStore(library: library)
    let vm = makeVM(api: AlbumsAPI(result: .success([])), config: config, sourceStore: sourceStore)
    config.saveBaseURL(URL(string: "https://photos.example.test")!)
    vm.step = .confirm

    vm.finish()

    #expect(vm.step == .done)
    // No album was chosen, so there is no AppConfiguration — only the saved base URL.
    #expect(config.load() == nil)
    #expect(config.loadBaseURL()?.host == "photos.example.test")
}

@Test func retriesUnreachableThenAdvancesWhenPermissionGranted() async {
    // The iOS Local Network prompt makes the first connection fail on a fresh install;
    // once the user grants access the retry succeeds. A bounded auto-retry rides that
    // out so onboarding advances instead of dead-ending on "server not available" the
    // user has to dismiss and re-trigger (Bug 1).
    let keychain = InMemoryKeychainStore()
    let config = InMemoryConfigStore()
    let api = FlakyAlbumsAPI(failuresBeforeSuccess: 1, albums: [Album(id: "a1", name: "Fam")])
    let vm = makeVM(api: api, config: config, keychain: keychain, retryLimit: 4)
    vm.serverURLInput = "https://photos.example.test"
    vm.apiKeyInput = "key"

    await vm.submitConnection()

    #expect(vm.step == .source)
    #expect(keychain.read() == "key")
    #expect(config.loadBaseURL()?.host == "photos.example.test")
    #expect(vm.albums.map(\.id) == ["a1"])
    #expect(vm.errorMessage == nil)
    // One failed attempt + one successful retry.
    #expect(await api.albumsCallCount == 2)
}

@Test func surfacesUnreachableAfterExhaustingRetries() async {
    // A genuinely unreachable server still errors out — bounded, not an infinite loop.
    let keychain = InMemoryKeychainStore()
    let api = AlbumsAPI(result: .failure(ImmichError.unreachable))
    let vm = makeVM(api: api, keychain: keychain, retryLimit: 2)
    vm.serverURLInput = "https://photos.example.test"
    vm.apiKeyInput = "key"

    await vm.submitConnection()

    #expect(vm.step == .connection)
    #expect(keychain.read() == nil)
    #expect(vm.errorMessage == ConnectionError.message(for: .unreachable))
    // Initial attempt + retryLimit retries, then it gives up.
    #expect(await api.albumsCallCount == 3)
}

@Test func doesNotRetryDeterministicErrors() async {
    // Auth failures won't change on retry, so they surface immediately without burning
    // the retry budget (the retry is scoped to `.unreachable`).
    let keychain = InMemoryKeychainStore()
    let api = AlbumsAPI(result: .failure(ImmichError.unauthorized))
    let vm = makeVM(api: api, keychain: keychain, retryLimit: 4)
    vm.serverURLInput = "https://photos.example.test"
    vm.apiKeyInput = "key"

    await vm.submitConnection()

    #expect(vm.step == .connection)
    #expect(vm.errorMessage == ConnectionError.message(for: .unauthorized))
    #expect(await api.albumsCallCount == 1)
}

@Test func staysWhenServerUnreachable() async {
    let keychain = InMemoryKeychainStore()
    let api = AlbumsAPI(result: .failure(ImmichError.unreachable))
    let vm = makeVM(api: api, keychain: keychain)
    vm.serverURLInput = "https://photos.example.test"
    vm.apiKeyInput = "key"

    await vm.submitConnection()

    #expect(vm.step == .connection)
    #expect(keychain.read() == nil)
    #expect(vm.errorMessage == ConnectionError.message(for: .unreachable))
    #expect(await api.albumsCallCount == 1)
}

@Test func staysWhenUnauthorized() async {
    let keychain = InMemoryKeychainStore()
    let api = AlbumsAPI(result: .failure(ImmichError.unauthorized))
    let vm = makeVM(api: api, keychain: keychain)
    vm.serverURLInput = "https://photos.example.test"
    vm.apiKeyInput = "key"

    await vm.submitConnection()

    let unauthorizedMessage = ConnectionError.message(for: .unauthorized)
    let unreachableMessage = ConnectionError.message(for: .unreachable)
    #expect(vm.step == .connection)
    #expect(keychain.read() == nil)
    #expect(vm.errorMessage == unauthorizedMessage)
    #expect(unauthorizedMessage != unreachableMessage)
    #expect(await api.albumsCallCount == 1)
}

@Test func staysWhenInvalidResponsePreservesConnectionInputsAndClassifiesError() async {
    let keychain = InMemoryKeychainStore()
    let api = AlbumsAPI(result: .failure(ImmichError.invalidResponse))
    let vm = makeVM(api: api, keychain: keychain)
    vm.serverURLInput = "https://photos.example.test"
    vm.apiKeyInput = "key"

    await vm.submitConnection()

    let invalidResponseMessage = ConnectionError.message(for: .invalidResponse)
    #expect(vm.step == .connection)
    #expect(keychain.read() == nil)
    #expect(vm.serverURLInput == "https://photos.example.test")
    #expect(vm.apiKeyInput == "key")
    #expect(vm.errorMessage == invalidResponseMessage)
    #expect(invalidResponseMessage != ConnectionError.message(for: .unreachable))
    #expect(invalidResponseMessage != ConnectionError.message(for: .unauthorized))
    #expect(await api.albumsCallCount == 1)
}

@Test func staysWhenKeychainSaveFails() async {
    let keychain = InMemoryKeychainStore(failSave: true)
    let api = AlbumsAPI(result: .success([Album(id: "a1", name: "Fam")]))
    let vm = makeVM(api: api, keychain: keychain)
    vm.serverURLInput = "https://photos.example.test"
    vm.apiKeyInput = "key"

    await vm.submitConnection()

    #expect(vm.step == .connection)
    #expect(vm.errorMessage != nil)
    #expect(await api.albumsCallCount == 1)
}

@Test func resetReturnsToConnectionAndClearsLibrary() {
    let config = InMemoryConfigStore(configuration: AppConfiguration(
        baseURL: URL(string: "https://photos.example.test")!,
        selectedAlbumID: "a1"
    ))
    let keychain = InMemoryKeychainStore(apiKey: "key")
    var library = SourceLibrary()
    library.add(Source(label: "Fam", kind: .album(albumID: "a1")))
    let sourceStore = InMemorySourceLibraryStore(library: library)
    let vm = makeVM(api: AlbumsAPI(result: .success([])), config: config, keychain: keychain, sourceStore: sourceStore)
    vm.step = .confirm
    vm.serverURLInput = "https://photos.example.test"
    vm.apiKeyInput = "key"
    vm.albums = [Album(id: "a1", name: "Fam")]
    vm.errorMessage = "etwas"

    vm.reset()

    #expect(config.load() == nil)
    #expect(keychain.read() == nil)
    #expect(sourceStore.load().sources.isEmpty)
    #expect(vm.step == .connection)
    #expect(vm.serverURLInput == "")
    #expect(vm.apiKeyInput == "")
    #expect(vm.albums.isEmpty)
    #expect(vm.errorMessage == nil)
}

private func makeVM(
    api: any ImmichAPI,
    config: InMemoryConfigStore = .init(),
    keychain: InMemoryKeychainStore = .init(),
    sourceStore: InMemorySourceLibraryStore = .init(),
    retryLimit: Int = 0
) -> OnboardingViewModel {
    OnboardingViewModel(
        api: { _ in api },
        config: config,
        keychain: keychain,
        sourceStore: sourceStore,
        connectionRetryLimit: retryLimit,
        connectionRetryDelay: .zero,
        // No real waiting in tests — the retry cadence is host behaviour, not under test.
        sleep: { _ in }
    )
}

private actor AlbumsAPI: ImmichAPI {
    private let result: Result<[Album], Error>
    private(set) var albumsCallCount = 0

    init(result: Result<[Album], Error>) {
        self.result = result
    }

    func serverVersion() async throws -> String {
        "1.119.0"
    }

    func albums() async throws -> [Album] {
        albumsCallCount += 1
        return try result.get()
    }

    func assets(albumID: String) async throws -> [Asset] {
        []
    }

    func preview(assetID: String) async throws -> Data {
        Data()
    }
}

/// Fails `.unreachable` for the first `failuresBeforeSuccess` calls, then returns
/// `albums` — models the Local Network prompt blocking the first request and the
/// retry succeeding once the user grants access.
private actor FlakyAlbumsAPI: ImmichAPI {
    private let failuresBeforeSuccess: Int
    private let albumsResult: [Album]
    private(set) var albumsCallCount = 0

    init(failuresBeforeSuccess: Int, albums: [Album]) {
        self.failuresBeforeSuccess = failuresBeforeSuccess
        self.albumsResult = albums
    }

    func serverVersion() async throws -> String {
        "1.119.0"
    }

    func albums() async throws -> [Album] {
        albumsCallCount += 1
        if albumsCallCount <= failuresBeforeSuccess {
            throw ImmichError.unreachable
        }
        return albumsResult
    }

    func assets(albumID: String) async throws -> [Asset] {
        []
    }

    func preview(assetID: String) async throws -> Data {
        Data()
    }
}
