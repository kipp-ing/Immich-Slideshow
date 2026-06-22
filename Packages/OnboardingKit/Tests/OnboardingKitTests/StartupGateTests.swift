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

@Test func startupGateReturnsConnectionForCompleteConfigWithoutAPIKey() {
    let config = InMemoryConfigStore(
        configuration: AppConfiguration(baseURL: url, selectedAlbumID: "a1")
    )
    let keychain = InMemoryKeychainStore()
    let gate = StartupGate(config: config, keychain: keychain)

    #expect(gate.initialStep() == .connection)
}

@Test func startupGateReturnsConnectionWithoutConfigAndWithoutAPIKey() {
    let config = InMemoryConfigStore()
    let keychain = InMemoryKeychainStore()
    let gate = StartupGate(config: config, keychain: keychain)

    #expect(gate.initialStep() == .connection)
}

@Test func startupGateReturnsConnectionWithoutConfigEvenWithAPIKey() {
    let config = InMemoryConfigStore()
    let keychain = InMemoryKeychainStore(apiKey: "key")
    let gate = StartupGate(config: config, keychain: keychain)

    #expect(gate.initialStep() == .connection)
}
