import Foundation
import Observation

@MainActor
@Observable
public final class HAControlCoordinator {
    public private(set) var connection: ConnectionState = .disconnected

    private let transport: any MQTTTransport
    private let control: any RemoteControlling
    private let configStore: any BrokerConfigStore
    private let deviceName: String
    private let enabledEntities: Set<HAEntity>
    private var deviceID: String?
    private var incomingTask: Task<Void, Never>?
    private var connectionTask: Task<Void, Never>?

    public init(
        transport: any MQTTTransport,
        control: any RemoteControlling,
        configStore: any BrokerConfigStore,
        deviceName: String,
        enabledEntities: Set<HAEntity> = [.playback]
    ) {
        self.transport = transport
        self.control = control
        self.configStore = configStore
        self.deviceName = deviceName
        self.enabledEntities = enabledEntities
    }

    public func start() async {
        guard let config = configStore.load() else {
            return
        }

        deviceID = config.deviceID
        connection = .connecting

        let will = MQTTMessage(
            topic: HATopics.availability(deviceID: config.deviceID),
            payload: Data("offline".utf8),
            retain: true
        )

        do {
            try await transport.connect(will: will)
        } catch {
            connection = .disconnected
            return
        }

        connection = .connected
        await announce()
        startConsumers()
    }

    public func stop() async {
        incomingTask?.cancel()
        connectionTask?.cancel()
        incomingTask = nil
        connectionTask = nil
        await transport.disconnect()
        connection = .disconnected
    }

    internal func announce() async {
        guard let deviceID = ensureDeviceID() else {
            return
        }

        try? await transport.publish(MQTTMessage(
            topic: HATopics.availability(deviceID: deviceID),
            payload: Data("online".utf8),
            retain: true
        ))

        for entity in orderedEnabledEntities {
            try? await transport.publish(MQTTMessage(
                topic: HATopics.discoveryConfigTopic(deviceID: deviceID, entity: entity),
                payload: HADiscovery.config(
                    for: entity,
                    deviceID: deviceID,
                    deviceName: deviceName,
                    albumOptions: control.albumOptions
                ),
                retain: true
            ))
            try? await transport.subscribe(HATopics.commandTopic(deviceID: deviceID, entity: entity))
            await echo(entity)
        }

        control.onLocalChange = { [weak self] in
            Task { @MainActor in
                await self?.echoAll()
            }
        }
    }

    internal func handleIncoming(_ message: MQTTMessage) async {
        guard let deviceID = ensureDeviceID() else {
            return
        }

        for entity in enabledEntities where message.topic == HATopics.commandTopic(deviceID: deviceID, entity: entity) {
            switch entity {
            case .playback:
                let payload = String(data: message.payload, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .uppercased()

                if payload == "ON" {
                    control.resume()
                } else if payload == "OFF" {
                    control.pause()
                }
                await echo(.playback)
            case .brightness, .album:
                break
            }
            return
        }
    }

    internal func handleConnection(_ up: Bool) async {
        if up {
            connection = .connected
            await announce()
        } else {
            connection = .disconnected
        }
    }

    internal func echo(_ entity: HAEntity) async {
        guard let deviceID = ensureDeviceID() else {
            return
        }

        switch entity {
        case .playback:
            let payload = control.playbackState == .playing ? "ON" : "OFF"
            try? await transport.publish(MQTTMessage(
                topic: HATopics.stateTopic(deviceID: deviceID, entity: .playback),
                payload: Data(payload.utf8),
                retain: true
            ))
        case .brightness, .album:
            break
        }
    }

    internal func echoAll() async {
        for entity in orderedEnabledEntities {
            await echo(entity)
        }
    }

    private var orderedEnabledEntities: [HAEntity] {
        HAEntity.allCases.filter { enabledEntities.contains($0) }
    }

    private func ensureDeviceID() -> String? {
        if let deviceID {
            return deviceID
        }
        guard let config = configStore.load() else {
            return nil
        }
        deviceID = config.deviceID
        return config.deviceID
    }

    private func startConsumers() {
        incomingTask?.cancel()
        connectionTask?.cancel()

        let incoming = transport.incoming
        incomingTask = Task { [weak self] in
            for await message in incoming {
                await self?.handleIncoming(message)
            }
        }

        let connectionEvents = transport.connectionEvents
        connectionTask = Task { [weak self] in
            for await up in connectionEvents {
                await self?.handleConnection(up)
            }
        }
    }
}
