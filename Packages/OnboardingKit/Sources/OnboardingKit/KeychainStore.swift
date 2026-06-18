public protocol KeychainStore: Sendable {
    func save(_ apiKey: String) throws
    func read() -> String?
    func delete()
}
