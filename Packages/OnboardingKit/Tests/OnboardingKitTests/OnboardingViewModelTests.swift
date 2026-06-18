import Foundation
import Testing
@testable import OnboardingKit
import ImmichClient
import ImmichClientTestSupport

@Test func submitServerURLRejectsNonHTTPSURL() async {
    let vm = makeVM(transportResult: .failure(URLError(.badURL)))
    vm.serverURLInput = "http://foo"

    await vm.submitServerURL()

    #expect(vm.step == .server)
    #expect(vm.errorMessage != nil)
}

@Test func submitServerURLAdvancesToAPIKeyWhenVersionLoads() async throws {
    let response = try makeResponse(path: "/api/server/version", statusCode: 200)
    let data = try #require(#"{"major":1,"minor":119,"patch":0}"#.data(using: .utf8))
    let vm = makeVM(transportResult: .success((data, response)))
    vm.serverURLInput = "https://photos.example.test"

    await vm.submitServerURL()

    #expect(vm.step == .apiKey)
    #expect(vm.errorMessage == nil)
}

@Test func submitServerURLKeepsServerStepWhenServerIsUnreachable() async {
    let vm = makeVM(transportResult: .failure(URLError(.timedOut)))
    vm.serverURLInput = "https://photos.example.test"

    await vm.submitServerURL()

    #expect(vm.step == .server)
    #expect(vm.errorMessage != nil)
}

@Test func submitAPIKeyLoadsAlbumsAndSavesKey() async throws {
    let response = try makeResponse(path: "/api/albums", statusCode: 200)
    let data = try #require(#"[{"id":"a1","albumName":"Fam"}]"#.data(using: .utf8))
    let keychain = InMemoryKeychainStore()
    let vm = makeVM(transportResult: .success((data, response)), keychain: keychain)
    vm.serverURLInput = "https://photos.example.test"
    vm.step = .apiKey
    vm.apiKeyInput = "key"

    await vm.submitAPIKey()

    #expect(vm.step == .album)
    #expect(vm.albums.count == 1)
    #expect(keychain.read() == "key")
    #expect(vm.errorMessage == nil)
}

@Test func submitAPIKeyKeepsAPIKeyStepWhenUnauthorizedAndDoesNotSaveKey() async throws {
    let response = try makeResponse(path: "/api/albums", statusCode: 401)
    let data = Data()
    let keychain = InMemoryKeychainStore()
    let vm = makeVM(transportResult: .success((data, response)), keychain: keychain)
    vm.serverURLInput = "https://photos.example.test"
    vm.step = .apiKey
    vm.apiKeyInput = "key"

    await vm.submitAPIKey()

    #expect(vm.step == .apiKey)
    #expect(vm.errorMessage != nil)
    #expect(keychain.read() == nil)
}

@Test func submitAPIKeyKeepsAPIKeyStepWhenKeychainSaveFails() async throws {
    let response = try makeResponse(path: "/api/albums", statusCode: 200)
    let data = try #require(#"[{"id":"a1","albumName":"Fam"}]"#.data(using: .utf8))
    let keychain = InMemoryKeychainStore(failSave: true)
    let vm = makeVM(transportResult: .success((data, response)), keychain: keychain)
    vm.serverURLInput = "https://photos.example.test"
    vm.step = .apiKey
    vm.apiKeyInput = "key"

    await vm.submitAPIKey()

    #expect(vm.step == .apiKey)
    #expect(vm.errorMessage != nil)
}

@Test func submitAPIKeyKeepsAPIKeyStepWhenAlbumListIsEmpty() async throws {
    let response = try makeResponse(path: "/api/albums", statusCode: 200)
    let data = Data("[]".utf8)
    let vm = makeVM(transportResult: .success((data, response)))
    vm.serverURLInput = "https://photos.example.test"
    vm.step = .apiKey
    vm.apiKeyInput = "key"

    await vm.submitAPIKey()

    #expect(vm.step == .apiKey)
    #expect(vm.errorMessage != nil)
    #expect(vm.albums.isEmpty)
}

@Test func selectAlbumPersistsConfigurationAndFinishes() async {
    let config = InMemoryConfigStore()
    let vm = makeVM(transportResult: .failure(URLError(.badURL)), config: config)
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
    transportResult: Result<(Data, URLResponse), Error>,
    config: InMemoryConfigStore = .init(),
    keychain: InMemoryKeychainStore = .init()
) -> OnboardingViewModel {
    OnboardingViewModel(
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

private func makeResponse(path: String, statusCode: Int) throws -> HTTPURLResponse {
    let url = try #require(URL(string: "https://photos.example.test\(path)"))
    return try #require(HTTPURLResponse(
        url: url,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
    ))
}
