import HAControlKit
import Testing
@testable import BrokerSetupKit

@Test func providerReturnsNilWithoutSettings() {
    let store = InMemoryBrokerSettingsStore()
    let provider = BrokerConfigProvider(settingsStore: store, deviceID: "ipad-wall")

    #expect(provider.load() == nil)
}

@Test func providerBuildsBrokerConfigFromSettingsAndDeviceID() throws {
    let store = InMemoryBrokerSettingsStore()
    try store.save(BrokerSettings(host: "broker.local", port: 1883, username: "mqtt", password: "secret"))
    let provider = BrokerConfigProvider(settingsStore: store, deviceID: "ipad-wall")

    #expect(provider.load() == BrokerConfig(
        host: "broker.local",
        port: 1883,
        username: "mqtt",
        password: "secret",
        deviceID: "ipad-wall"
    ))
}
