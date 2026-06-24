import Foundation
import Testing
@testable import OnboardingKit

private let url = URL(string: "https://photos.example.test")!

private func activeLibrary() -> InMemorySourceLibraryStore {
    var library = SourceLibrary()
    library.add(Source(label: "Wohnzimmer", kind: .album(albumID: "a1")))
    return InMemorySourceLibraryStore(library: library)
}

@Test func startupGateReturnsDoneForConnectionAndActiveSource() {
    let config = InMemoryConfigStore(
        configuration: AppConfiguration(baseURL: url, selectedAlbumID: "a1")
    )
    let keychain = InMemoryKeychainStore(apiKey: "key")
    let gate = StartupGate(config: config, keychain: keychain, sourceStore: activeLibrary())

    #expect(gate.initialStep() == .done)
}

@Test func startupGateReturnsConnectionWithoutAPIKey() {
    let config = InMemoryConfigStore(
        configuration: AppConfiguration(baseURL: url, selectedAlbumID: "a1")
    )
    let keychain = InMemoryKeychainStore()
    let gate = StartupGate(config: config, keychain: keychain, sourceStore: activeLibrary())

    #expect(gate.initialStep() == .connection)
}

@Test func startupGateReturnsConnectionWithoutBaseURL() {
    let config = InMemoryConfigStore()
    let keychain = InMemoryKeychainStore(apiKey: "key")
    let gate = StartupGate(config: config, keychain: keychain, sourceStore: activeLibrary())

    #expect(gate.initialStep() == .connection)
}

@Test func startupGateReturnsConnectionWithoutConfigAndWithoutAPIKey() {
    let config = InMemoryConfigStore()
    let keychain = InMemoryKeychainStore()
    let gate = StartupGate(config: config, keychain: keychain, sourceStore: InMemorySourceLibraryStore())

    #expect(gate.initialStep() == .connection)
}

@Test func startupGateReturnsSourceWhenConnectedButLibraryEmpty() {
    // Connection validated (key + baseURL persisted) but no source added yet → resume at
    // the add-source step rather than dead-ending at the slideshow (120, US2).
    let config = InMemoryConfigStore()
    config.saveBaseURL(url)
    let keychain = InMemoryKeychainStore(apiKey: "key")
    let gate = StartupGate(config: config, keychain: keychain, sourceStore: InMemorySourceLibraryStore())

    #expect(gate.initialStep() == .source)
}

@Test func startupGateMigratesLegacySelectedAlbumIDToDone() {
    // A pre-120 install: baseURL + key + legacy selectedAlbumID, no library yet. The store
    // migrates the album into a one-entry active library on load, so the gate routes to the
    // running slideshow without re-onboarding.
    let defaults = makeStartupGateDefaults()
    defaults.set(url.absoluteString, forKey: "immich.baseURL")
    defaults.set("a1", forKey: "immich.selectedAlbumID")
    let config = UserDefaultsConfigStore(defaults: defaults)
    let sourceStore = UserDefaultsSourceLibraryStore(defaults: defaults)
    let keychain = InMemoryKeychainStore(apiKey: "key")
    let gate = StartupGate(config: config, keychain: keychain, sourceStore: sourceStore)

    #expect(gate.initialStep() == .done)
}

private func makeStartupGateDefaults() -> UserDefaults {
    let suiteName = "StartupGateTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}
