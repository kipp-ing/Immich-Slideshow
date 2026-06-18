import Foundation
import Testing
@testable import OnboardingKit

private let url = URL(string: "https://photos.example.test")!

@Test func startupGateReturnsDoneForCompleteConfigAndAPIKey() {
    let config = InMemoryConfigStore(
        configuration: AppConfiguration(baseURL: url, selectedAlbumID: "a1")
    )
    let keychain = InMemoryKeychainStore(apiKey: "key")
    let gate = StartupGate(config: config, keychain: keychain)

    #expect(gate.initialStep() == .done)
}

@Test func startupGateReturnsAPIKeyForCompleteConfigWithoutAPIKey() {
    let config = InMemoryConfigStore(
        configuration: AppConfiguration(baseURL: url, selectedAlbumID: "a1")
    )
    let keychain = InMemoryKeychainStore()
    let gate = StartupGate(config: config, keychain: keychain)

    #expect(gate.initialStep() == .apiKey)
}

@Test func startupGateReturnsServerWithoutConfigAndWithoutAPIKey() {
    let config = InMemoryConfigStore()
    let keychain = InMemoryKeychainStore()
    let gate = StartupGate(config: config, keychain: keychain)

    #expect(gate.initialStep() == .server)
}

@Test func startupGateReturnsServerWithoutConfigEvenWithAPIKey() {
    let config = InMemoryConfigStore()
    let keychain = InMemoryKeychainStore(apiKey: "key")
    let gate = StartupGate(config: config, keychain: keychain)

    #expect(gate.initialStep() == .server)
}
