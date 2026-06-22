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

@Test func advancesToAlbumWhenReachableAndAuthorized() async throws {
    let keychain = InMemoryKeychainStore()
    let api = AlbumsAPI(result: .success([Album(id: "a1", name: "Fam")]))
    let vm = makeVM(api: api, keychain: keychain)
    vm.serverURLInput = "https://photos.example.test"
    vm.apiKeyInput = "key"

    await vm.submitConnection()

    #expect(vm.step == .album)
    #expect(keychain.read() == "key")
    #expect(vm.albums.map(\.id) == ["a1"])
    #expect(vm.errorMessage == nil)
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

@Test func staysWhenAlbumListEmpty() async {
    let api = AlbumsAPI(result: .success([]))
    let vm = makeVM(api: api)
    vm.serverURLInput = "https://photos.example.test"
    vm.apiKeyInput = "key"

    await vm.submitConnection()

    #expect(vm.step == .connection)
    #expect(vm.errorMessage == String(localized: "No albums found. Create an album in Immich.", bundle: .module))
    #expect(vm.albums.isEmpty)
    #expect(await api.albumsCallCount == 1)
}

@Test func resetReturnsToConnection() {
    let config = InMemoryConfigStore(configuration: AppConfiguration(
        baseURL: URL(string: "https://photos.example.test")!,
        selectedAlbumID: "a1"
    ))
    let keychain = InMemoryKeychainStore(apiKey: "key")
    let vm = makeVM(api: AlbumsAPI(result: .success([])), config: config, keychain: keychain)
    vm.step = .album
    vm.serverURLInput = "https://photos.example.test"
    vm.apiKeyInput = "key"
    vm.albums = [Album(id: "a1", name: "Fam")]
    vm.selectedAlbumID = "a1"
    vm.errorMessage = "irgendwas"

    vm.reset()

    #expect(config.load() == nil)
    #expect(keychain.read() == nil)
    #expect(vm.step == .connection)
    #expect(vm.serverURLInput == "")
    #expect(vm.apiKeyInput == "")
    #expect(vm.albums.isEmpty)
    #expect(vm.selectedAlbumID == nil)
    #expect(vm.errorMessage == nil)
}

@Test func selectAlbumPersistsConfigurationAndFinishes() async {
    let config = InMemoryConfigStore()
    let vm = makeVM(api: AlbumsAPI(result: .failure(ImmichError.unreachable)), config: config)
    vm.serverURLInput = "https://photos.example.test"
    vm.step = .album
    vm.albums = [Album(id: "a1", name: "Fam")]

    await vm.selectAlbum(id: "a1")

    let saved = config.load()
    #expect(saved?.selectedAlbumID == "a1")
    #expect(saved?.baseURL.host == "photos.example.test")
    #expect(vm.step == .done)
}

private func makeVM(
    api: AlbumsAPI,
    config: InMemoryConfigStore = .init(),
    keychain: InMemoryKeychainStore = .init()
) -> OnboardingViewModel {
    OnboardingViewModel(
        api: { _ in api },
        config: config,
        keychain: keychain
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
