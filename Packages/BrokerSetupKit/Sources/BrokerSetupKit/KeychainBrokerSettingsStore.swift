import Foundation
import Security

public struct KeychainBrokerSettingsStore: BrokerSettingsStore, @unchecked Sendable {
    public enum KeychainError: Error, Equatable {
        case unexpectedStatus(OSStatus)
    }

    private struct Credentials: Codable {
        var username: String
        var password: String
    }

    private static let hostKey = "mqtt.brokerHost"
    private static let portKey = "mqtt.brokerPort"
    private static let account = "mqtt-credentials"

    private let userDefaults: UserDefaults
    private let service: String

    public init(
        userDefaults: UserDefaults = .standard,
        service: String = "de.kippings.ImmichSlideshow.mqttCredentials"
    ) {
        self.userDefaults = userDefaults
        self.service = service
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Self.account,
        ]
    }

    public func save(_ settings: BrokerSettings) throws {
        if let error = settings.validate() {
            throw error
        }

        let credentials = Credentials(username: settings.username, password: settings.password)
        let data = try JSONEncoder().encode(credentials)

        SecItemDelete(baseQuery as CFDictionary)

        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }

        userDefaults.set(settings.host, forKey: Self.hostKey)
        userDefaults.set(settings.port, forKey: Self.portKey)
    }

    public func load() -> BrokerSettings? {
        guard
            let host = userDefaults.string(forKey: Self.hostKey),
            userDefaults.object(forKey: Self.portKey) != nil
        else {
            return nil
        }

        let port = userDefaults.integer(forKey: Self.portKey)

        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard
            status == errSecSuccess,
            let data = result as? Data,
            let credentials = try? JSONDecoder().decode(Credentials.self, from: data)
        else {
            return nil
        }

        return BrokerSettings(
            host: host,
            port: port,
            username: credentials.username,
            password: credentials.password
        )
    }

    public func clear() {
        userDefaults.removeObject(forKey: Self.hostKey)
        userDefaults.removeObject(forKey: Self.portKey)
        SecItemDelete(baseQuery as CFDictionary)
    }
}
