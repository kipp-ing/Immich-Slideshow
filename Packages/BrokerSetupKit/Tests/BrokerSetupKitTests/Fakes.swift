import Foundation
@testable import BrokerSetupKit

final class InMemoryBrokerSettingsStore: BrokerSettingsStore, @unchecked Sendable {
    private var settings: BrokerSettings?

    init(settings: BrokerSettings? = nil) {
        self.settings = settings
    }

    func save(_ settings: BrokerSettings) throws {
        if let error = settings.validate() {
            throw error
        }
        self.settings = settings
    }

    func load() -> BrokerSettings? {
        settings
    }

    func clear() {
        settings = nil
    }
}
