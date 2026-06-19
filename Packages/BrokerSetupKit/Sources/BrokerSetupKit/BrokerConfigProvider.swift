import Foundation
import HAControlKit

public struct BrokerConfigProvider: BrokerConfigStore {
    private let settingsStore: any BrokerSettingsStore
    private let deviceID: String

    public init(settingsStore: any BrokerSettingsStore, deviceID: String) {
        self.settingsStore = settingsStore
        self.deviceID = deviceID
    }

    public func load() -> BrokerConfig? {
        guard let settings = settingsStore.load() else {
            return nil
        }
        guard settings.validate() == nil else {
            return nil
        }

        return BrokerConfig(
            host: settings.host,
            port: settings.port,
            username: settings.username,
            password: settings.password,
            deviceID: deviceID
        )
    }
}
