import Foundation
import HAControlKit
import MQTTNIO
import NIOCore

public final class NIOMQTTTransport: MQTTTransport, @unchecked Sendable {
    public let incoming: AsyncStream<MQTTMessage>
    public let connectionEvents: AsyncStream<Bool>

    private let config: BrokerConfig
    private let client: MQTTClient
    private let incomingContinuation: AsyncStream<MQTTMessage>.Continuation
    private let connectionContinuation: AsyncStream<Bool>.Continuation

    public init(config: BrokerConfig) {
        self.config = config
        self.client = MQTTClient(
            host: config.host,
            port: config.port,
            identifier: config.deviceID,
            eventLoopGroupProvider: .createNew,
            configuration: .init(
                version: .v3_1_1,
                keepAliveInterval: .seconds(30),
                userName: config.username,
                password: config.password,
                useSSL: true
            )
        )

        var incomingContinuation: AsyncStream<MQTTMessage>.Continuation!
        self.incoming = AsyncStream { continuation in
            incomingContinuation = continuation
        }
        self.incomingContinuation = incomingContinuation

        var connectionContinuation: AsyncStream<Bool>.Continuation!
        self.connectionEvents = AsyncStream { continuation in
            connectionContinuation = continuation
        }
        self.connectionContinuation = connectionContinuation

        client.addPublishListener(named: "hacontrol") { [incomingContinuation] result in
            guard case .success(let info) = result else {
                return
            }

            incomingContinuation?.yield(MQTTMessage(
                topic: info.topicName,
                payload: Data(buffer: info.payload),
                retain: info.retain
            ))
        }

        client.addCloseListener(named: "hacontrol") { [connectionContinuation] _ in
            connectionContinuation?.yield(false)
        }
    }

    public func connect(will: MQTTMessage) async throws {
        _ = try await client.connect(
            cleanSession: true,
            will: (
                topicName: will.topic,
                payload: ByteBuffer(bytes: will.payload),
                qos: .atLeastOnce,
                retain: will.retain
            )
        ).get()
        connectionContinuation.yield(true)
    }

    public func disconnect() async {
        try? await client.disconnect().get()
        try? await client.shutdown()
    }

    public func publish(_ message: MQTTMessage) async throws {
        try await client.publish(
            to: message.topic,
            payload: ByteBuffer(bytes: message.payload),
            qos: .atLeastOnce,
            retain: message.retain
        ).get()
    }

    public func subscribe(_ topicFilter: String) async throws {
        _ = try await client.subscribe(to: [
            MQTTSubscribeInfo(topicFilter: topicFilter, qos: .atLeastOnce),
        ]).get()
    }
}
