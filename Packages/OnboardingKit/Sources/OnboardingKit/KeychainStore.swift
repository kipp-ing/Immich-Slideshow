import Foundation
import Security

public protocol KeychainStore: Sendable {
    func save(_ apiKey: String) throws
    func read() -> String?
    func delete()
}

/// Reale `KeychainStore`-Implementierung über die Security-API
/// (`kSecClassGenericPassword`, fester Service/Account). Der API-Key liegt nie
/// in UserDefaults oder Logs (Konstitution III).
public struct KeychainAPIKeyStore: KeychainStore {
    public enum KeychainError: Error, Equatable {
        case unexpectedStatus(OSStatus)
    }

    private let service: String
    private let account: String

    public init(
        service: String = "de.kippings.ImmichSlideshow.apiKey",
        account: String = "immich-api-key"
    ) {
        self.service = service
        self.account = account
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    public func save(_ apiKey: String) throws {
        // Idempotentes Überschreiben: vorhandenen Eintrag entfernen, dann neu anlegen.
        SecItemDelete(baseQuery as CFDictionary)

        var attributes = baseQuery
        attributes[kSecValueData as String] = Data(apiKey.utf8)
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    public func read() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    public func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
