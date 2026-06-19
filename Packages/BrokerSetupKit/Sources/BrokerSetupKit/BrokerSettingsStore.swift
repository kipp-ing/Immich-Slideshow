import Foundation

public protocol BrokerSettingsStore: Sendable {
    func save(_ settings: BrokerSettings) throws
    func load() -> BrokerSettings?
    func clear()
}
