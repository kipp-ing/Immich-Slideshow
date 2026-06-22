import Foundation
import Testing
@testable import OnboardingKit
import ImmichClient
import ImmichClientTestSupport

@MainActor @Test func connectionSettingsPrefillsStoredConnectionWithoutExposingStoredKey() {
    let config = CountingConfigStore(configuration: AppConfiguration(
        baseURL: URL(string: "https://photos.example.test")!,
        selectedAlbumID: "a1"
    ))
    let keychain = CountingKeychainStore(apiKey: "stored-key")
    let vm = makeConnectionSettingsVM(
        transportResult: .failure(URLError(.badURL)),
        config: config,
        keychain: keychain
    )

    #expect(vm.serverURLInput == "https://photos.example.test")
    #expect(vm.apiKeyInput == "")
    #expect(vm.keyIsSet == true)
}

@MainActor @Test(arguments: ["", "http://x", "https:///missing-host"])
func connectionSettingsRejectsMalformedURL(rawURL: String) async {
    let config = CountingConfigStore.seeded()
    let keychain = CountingKeychainStore(apiKey: "stored-key")
    let vm = makeConnectionSettingsVM(
        transportResult: .failure(URLError(.badURL)),
        config: config,
        keychain: keychain
    )
    vm.serverURLInput = rawURL
    vm.apiKeyInput = "new-key"

    let outcome = await vm.save()

    #expect(outcome.isMalformed)
    #expect(config.saveCount == 0)
    #expect(keychain.saveCount == 0)
}

@MainActor @Test func connectionSettingsDoesNotPersistUnauthorizedConnection() async throws {
    let response = try makeConnectionSettingsResponse(path: "/api/albums", statusCode: 401)
    let config = CountingConfigStore.seeded()
    let keychain = CountingKeychainStore(apiKey: "stored-key")
    let vm = makeConnectionSettingsVM(
        transportResult: .success((Data(), response)),
        config: config,
        keychain: keychain
    )
    vm.serverURLInput = "https://new.example.test"
    vm.apiKeyInput = "wrong-key"

    let outcome = await vm.save()

    #expect(outcome.isUnauthorized)
    #expect(config.load()?.baseURL.host == "photos.example.test")
    #expect(keychain.read() == "stored-key")
    #expect(config.saveCount == 0)
    #expect(keychain.saveCount == 0)
}

@MainActor @Test func connectionSettingsDoesNotPersistUnreachableConnection() async {
    let config = CountingConfigStore.seeded()
    let keychain = CountingKeychainStore(apiKey: "stored-key")
    let vm = makeConnectionSettingsVM(
        transportResult: .failure(URLError(.timedOut)),
        config: config,
        keychain: keychain
    )
    vm.serverURLInput = "https://new.example.test"
    vm.apiKeyInput = "new-key"

    let outcome = await vm.save()

    #expect(outcome.isUnreachable)
    #expect(config.load()?.baseURL.host == "photos.example.test")
    #expect(keychain.read() == "stored-key")
    #expect(config.saveCount == 0)
    #expect(keychain.saveCount == 0)
}

@MainActor @Test func connectionSettingsPersistsNewURLAndKeyWhenSelectedAlbumStillExists() async throws {
    let response = try makeConnectionSettingsResponse(path: "/api/albums", statusCode: 200)
    let data = Data(#"[{"id":"a1","albumName":"Fam"},{"id":"a2","albumName":"Trips"}]"#.utf8)
    let config = CountingConfigStore.seeded()
    let keychain = CountingKeychainStore(apiKey: "stored-key")
    let vm = makeConnectionSettingsVM(
        transportResult: .success((data, response)),
        config: config,
        keychain: keychain
    )
    vm.serverURLInput = "https://new.example.test"
    vm.apiKeyInput = "new-key"

    let outcome = await vm.save()

    #expect(outcome.isSuccess)
    #expect(config.load()?.baseURL.host == "new.example.test")
    #expect(config.load()?.selectedAlbumID == "a1")
    #expect(keychain.read() == "new-key")
    #expect(config.saveCount == 1)
    #expect(keychain.saveCount == 1)
    #expect(vm.keyIsSet == true)
}

@MainActor @Test func connectionSettingsDoesNotPersistConfigWhenKeychainSaveFails() async throws {
    let response = try makeConnectionSettingsResponse(path: "/api/albums", statusCode: 200)
    let data = Data(#"[{"id":"a1","albumName":"Fam"}]"#.utf8)
    let config = CountingConfigStore.seeded()
    let keychain = CountingKeychainStore(apiKey: "stored-key", failSave: true)
    let vm = makeConnectionSettingsVM(
        transportResult: .success((data, response)),
        config: config,
        keychain: keychain
    )
    vm.serverURLInput = "https://new.example.test"
    vm.apiKeyInput = "new-key"

    let outcome = await vm.save()

    #expect(outcome.isKeychainFailure)
    #expect(config.load()?.baseURL.host == "photos.example.test")
    #expect(keychain.read() == "stored-key")
    #expect(config.saveCount == 0)
    #expect(keychain.saveCount == 1)
}

@MainActor @Test func connectionSettingsURLOnlyChangeUsesStoredKeyAndDoesNotWriteKeychain() async throws {
    let response = try makeConnectionSettingsResponse(path: "/api/albums", statusCode: 200)
    let data = Data(#"[{"id":"a1","albumName":"Fam"}]"#.utf8)
    let config = CountingConfigStore.seeded()
    let keychain = CountingKeychainStore(apiKey: "stored-key")
    let vm = makeConnectionSettingsVM(
        transportResult: .success((data, response)),
        config: config,
        keychain: keychain
    )
    vm.serverURLInput = "https://new.example.test"

    let outcome = await vm.save()

    #expect(outcome.isSuccess)
    #expect(config.load()?.baseURL.host == "new.example.test")
    #expect(config.load()?.selectedAlbumID == "a1")
    #expect(keychain.read() == "stored-key")
    #expect(config.saveCount == 1)
    #expect(keychain.saveCount == 0)
}

@MainActor @Test func connectionSettingsReturnsAlbumMissingAfterPersistingWhenSelectedAlbumIsAbsent() async throws {
    let response = try makeConnectionSettingsResponse(path: "/api/albums", statusCode: 200)
    let data = Data(#"[{"id":"a2","albumName":"Trips"}]"#.utf8)
    let config = CountingConfigStore.seeded()
    let keychain = CountingKeychainStore(apiKey: "stored-key")
    let vm = makeConnectionSettingsVM(
        transportResult: .success((data, response)),
        config: config,
        keychain: keychain
    )
    vm.serverURLInput = "https://new.example.test"
    vm.apiKeyInput = "new-key"

    let outcome = await vm.save()

    guard case let .albumMissing(albums) = outcome else {
        Issue.record("Expected albumMissing, got \(outcome)")
        return
    }
    #expect(albums.map(\.id) == ["a2"])
    #expect(config.load()?.baseURL.host == "new.example.test")
    #expect(config.load()?.selectedAlbumID == "a1")
    #expect(keychain.read() == "new-key")
}

@MainActor @Test func connectionSettingsGuardsReentrantSaveWhileBusy() async throws {
    let api = BlockingAlbumsAPI()
    let config = CountingConfigStore.seeded()
    let keychain = CountingKeychainStore(apiKey: "stored-key")
    let vm = ConnectionSettingsViewModel(
        api: { _ in api },
        config: config,
        keychain: keychain
    )
    vm.serverURLInput = "https://new.example.test"

    let first = Task { @MainActor in
        await vm.save()
    }
    await api.waitUntilStarted()

    let second = await vm.save()
    await api.finish(with: [Album(id: "a1", name: "Fam")])
    let firstOutcome = await first.value

    #expect(second.isSuccess)
    #expect(firstOutcome.isSuccess)
    #expect(await api.albumsCallCount == 1)
    #expect(config.saveCount == 1)
}

@MainActor private func makeConnectionSettingsVM(
    transportResult: Result<(Data, URLResponse), Error>,
    config: CountingConfigStore = .seeded(),
    keychain: CountingKeychainStore = .init(apiKey: "stored-key")
) -> ConnectionSettingsViewModel {
    ConnectionSettingsViewModel(
        api: { serverConfig in
            ImmichClient(
                config: serverConfig,
                transport: MockTransport(result: transportResult)
            )
        },
        config: config,
        keychain: keychain
    )
}

private func makeConnectionSettingsResponse(path: String, statusCode: Int) throws -> HTTPURLResponse {
    let url = try #require(URL(string: "https://photos.example.test\(path)"))
    return try #require(HTTPURLResponse(
        url: url,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
    ))
}

private final class CountingConfigStore: ConfigStore, @unchecked Sendable {
    private var configuration: AppConfiguration?
    private(set) var saveCount = 0

    static  func seeded() -> CountingConfigStore {
        CountingConfigStore(configuration: AppConfiguration(
            baseURL: URL(string: "https://photos.example.test")!,
            selectedAlbumID: "a1"
        ))
    }

    init(configuration: AppConfiguration? = nil) {
        self.configuration = configuration
    }

    func load() -> AppConfiguration? {
        configuration
    }

    func save(_ configuration: AppConfiguration) {
        saveCount += 1
        self.configuration = configuration
    }

    func clear() {
        configuration = nil
    }
}

private final class CountingKeychainStore: KeychainStore, @unchecked Sendable {
    enum SaveError: Error {
        case forced
    }

    private let failSave: Bool
    private var apiKey: String?
    private(set) var saveCount = 0

    init(apiKey: String? = nil, failSave: Bool = false) {
        self.apiKey = apiKey
        self.failSave = failSave
    }

    func save(_ apiKey: String) throws {
        saveCount += 1
        if failSave {
            throw SaveError.forced
        }
        self.apiKey = apiKey
    }

    func read() -> String? {
        apiKey
    }

    func delete() {
        apiKey = nil
    }
}

private actor BlockingAlbumsAPI: ImmichAPI {
    private var continuation: CheckedContinuation<[Album], Error>?
    private var startedContinuation: CheckedContinuation<Void, Never>?
    private(set) var albumsCallCount = 0

    func serverVersion() async throws -> String {
        "1.119.0"
    }

    func albums() async throws -> [Album] {
        albumsCallCount += 1
        startedContinuation?.resume()
        startedContinuation = nil
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func assets(albumID: String) async throws -> [Asset] {
        []
    }

    func preview(assetID: String) async throws -> Data {
        Data()
    }

    func finish(with albums: [Album]) {
        continuation?.resume(returning: albums)
        continuation = nil
    }

    func waitUntilStarted() async {
        if albumsCallCount > 0 {
            return
        }

        await withCheckedContinuation { continuation in
            startedContinuation = continuation
        }
    }
}

private extension ConnectionValidationOutcome {
    var isMalformed: Bool {
        if case .malformed = self { return true }
        return false
    }

    var isUnreachable: Bool {
        if case .unreachable = self { return true }
        return false
    }

    var isUnauthorized: Bool {
        if case .unauthorized = self { return true }
        return false
    }

    var isKeychainFailure: Bool {
        if case .keychainFailure = self { return true }
        return false
    }

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
