import Foundation

public struct BrokerSettings: Sendable, Equatable {
    public var host: String
    public var port: Int
    public var username: String
    public var password: String

    public init(host: String, port: Int, username: String, password: String) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
    }

    public func validate() -> BrokerValidationError? {
        if host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .emptyHost
        }
        if !(1...65_535).contains(port) {
            return .invalidPort
        }
        if username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .emptyUsername
        }
        if password.isEmpty {
            return .emptyPassword
        }
        return nil
    }
}

public enum BrokerValidationError: Error, Equatable {
    case emptyHost
    case invalidPort
    case emptyUsername
    case emptyPassword
}
