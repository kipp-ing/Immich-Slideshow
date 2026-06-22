import Observation

@Observable public final class BrokerSetupViewModel {
    public var host: String = ""
    public var port: String = "8883"
    public var username: String = ""
    public var password: String = ""
    public private(set) var passwordIsSet: Bool = false
    public private(set) var validationError: BrokerValidationError? = nil

    private let store: any BrokerSettingsStore

    public init(store: any BrokerSettingsStore) {
        self.store = store
    }

    public func load() {
        guard let existing = store.load() else { return }
        host = existing.host
        port = String(existing.port)
        username = existing.username
        password = ""
        passwordIsSet = true
    }

    public func save() -> Bool {
        let effectivePassword: String
        if password.isEmpty, let existing = store.load() {
            effectivePassword = existing.password
        } else {
            effectivePassword = password
        }

        let settings = BrokerSettings(
            host: host,
            port: Int(port) ?? 0,
            username: username,
            password: effectivePassword
        )

        validationError = nil
        do {
            try store.save(settings)
            return true
        } catch let error as BrokerValidationError {
            validationError = error
            return false
        } catch {
            validationError = nil
            return false
        }
    }

    public func remove() {
        store.clear()
        // Reset the form to a pristine state so an inline editor reflects "no broker
        // configured" right after removal (no stale host/username left on screen).
        host = ""
        port = "8883"
        username = ""
        password = ""
        passwordIsSet = false
        validationError = nil
    }
}
