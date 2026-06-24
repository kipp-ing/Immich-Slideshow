import Foundation
import Security

public protocol SharedLinkSecretStore: Sendable {
    func savePassword(_ password: String, forSourceID id: String) throws
    func readPassword(forSourceID id: String) -> String?
    func deletePassword(forSourceID id: String)
}

public struct KeychainSharedLinkSecretStore: SharedLinkSecretStore {
    public enum KeychainError: Error, Equatable {
        case unexpectedStatus(OSStatus)
    }

    private let service: String

    public init(service: String = "de.kippings.ImmichSlideshow.sharedLinkPassword") {
        self.service = service
    }

    private func baseQuery(forSourceID id: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id,
        ]
    }

    public func savePassword(_ password: String, forSourceID id: String) throws {
        let query = baseQuery(forSourceID: id)
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = Data(password.utf8)
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    public func readPassword(forSourceID id: String) -> String? {
        var query = baseQuery(forSourceID: id)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    public func deletePassword(forSourceID id: String) {
        SecItemDelete(baseQuery(forSourceID: id) as CFDictionary)
    }
}

public final class InMemorySharedLinkSecretStore: SharedLinkSecretStore, @unchecked Sendable {
    private var passwordsBySourceID: [String: String]

    public init(passwordsBySourceID: [String: String] = [:]) {
        self.passwordsBySourceID = passwordsBySourceID
    }

    public func savePassword(_ password: String, forSourceID id: String) throws {
        passwordsBySourceID[id] = password
    }

    public func readPassword(forSourceID id: String) -> String? {
        passwordsBySourceID[id]
    }

    public func deletePassword(forSourceID id: String) {
        passwordsBySourceID[id] = nil
    }
}
