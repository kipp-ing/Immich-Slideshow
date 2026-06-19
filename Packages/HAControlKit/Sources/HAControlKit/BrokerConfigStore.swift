import Foundation

public protocol BrokerConfigStore: Sendable {
    func load() -> BrokerConfig?
}

public struct BrokerConfig: Sendable, Equatable {
    public var host: String
    public var port: Int
    public var username: String
    public var password: String
    public var deviceID: String

    public init(host: String, port: Int, username: String, password: String, deviceID: String) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.deviceID = deviceID
    }
}
