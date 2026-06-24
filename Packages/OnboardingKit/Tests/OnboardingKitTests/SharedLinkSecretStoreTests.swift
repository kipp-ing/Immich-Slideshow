import Testing
@testable import OnboardingKit

@Test func inMemorySharedLinkSecretStoreStoresPasswordsBySourceID() throws {
    let store = InMemorySharedLinkSecretStore()

    try store.savePassword("first-password", forSourceID: "source-1")
    try store.savePassword("second-password", forSourceID: "source-2")

    #expect(store.readPassword(forSourceID: "source-1") == "first-password")
    #expect(store.readPassword(forSourceID: "source-2") == "second-password")
}

@Test func inMemorySharedLinkSecretStoreOverwritesAndDeletesPasswords() throws {
    let store = InMemorySharedLinkSecretStore()

    try store.savePassword("old-password", forSourceID: "source-1")
    try store.savePassword("new-password", forSourceID: "source-1")
    store.deletePassword(forSourceID: "source-1")

    #expect(store.readPassword(forSourceID: "source-1") == nil)
}
