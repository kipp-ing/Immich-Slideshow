import Foundation

public struct MQTTMessage: Sendable, Equatable {
    public var topic: String
    public var payload: Data
    public var retain: Bool

    public init(topic: String, payload: Data, retain: Bool) {
        self.topic = topic
        self.payload = payload
        self.retain = retain
    }
}

public protocol MQTTTransport: Sendable {
    func connect(will: MQTTMessage) async throws
    func disconnect() async
    func publish(_ message: MQTTMessage) async throws
    func subscribe(_ topicFilter: String) async throws
    var incoming: AsyncStream<MQTTMessage> { get }
    var connectionEvents: AsyncStream<Bool> { get }
}
