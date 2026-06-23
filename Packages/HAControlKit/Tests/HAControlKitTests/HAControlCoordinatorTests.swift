import Foundation
import Testing
@testable import HAControlKit

@MainActor
@Suite
struct HAControlCoordinatorTests {
    @Test
    func startConnectsAnnouncesSubscribesAndEchoesPlaybackState() async throws {
        let transport = FakeMQTTTransport()
        let control = FakeRemoteControl()
        let coordinator = makeCoordinator(transport: transport, control: control)

        await coordinator.start()

        #expect(coordinator.connection == .connected)
        #expect(transport.will?.topic == HATopics.availability(deviceID: "dev1"))
        #expect(transport.will?.payload.string == "offline")
        #expect(transport.will?.retain == true)
        #expect(transport.published.containsMessage(topic: HATopics.availability(deviceID: "dev1"), payload: "online", retain: true))
        #expect(transport.published.contains { message in
            message.topic == HATopics.discoveryConfigTopic(deviceID: "dev1", entity: .playback) && message.retain
        })
        #expect(transport.subscriptions.contains(HATopics.commandTopic(deviceID: "dev1", entity: .playback)))
        #expect(transport.published.containsMessage(topic: HATopics.stateTopic(deviceID: "dev1", entity: .playback), payload: "ON", retain: true))

        await coordinator.stop()
    }

    @Test
    func playbackCommandsPauseResumeAndEchoActualState() async throws {
        let transport = FakeMQTTTransport()
        let control = FakeRemoteControl()
        let coordinator = makeCoordinator(transport: transport, control: control)

        await coordinator.handleIncoming(message("OFF", entity: .playback))

        #expect(control.pauseCount == 1)
        #expect(control.resumeCount == 0)
        #expect(transport.published.last?.topic == HATopics.stateTopic(deviceID: "dev1", entity: .playback))
        #expect(transport.published.last?.payload.string == "OFF")

        await coordinator.handleIncoming(message("ON", entity: .playback))

        #expect(control.pauseCount == 1)
        #expect(control.resumeCount == 1)
        #expect(transport.published.last?.topic == HATopics.stateTopic(deviceID: "dev1", entity: .playback))
        #expect(transport.published.last?.payload.string == "ON")
    }

    @Test
    func rapidPlaybackCommandsApplyLatestValidCommandAndEchoActualState() async throws {
        let transport = FakeMQTTTransport()
        let control = FakeRemoteControl()
        let coordinator = makeCoordinator(transport: transport, control: control)

        await coordinator.handleIncoming(message("OFF", entity: .playback))
        await coordinator.handleIncoming(message("ON", entity: .playback))
        await coordinator.handleIncoming(message("OFF", entity: .playback))

        #expect(control.playbackState == .paused)
        #expect(control.pauseCount == 2)
        #expect(control.resumeCount == 1)
        #expect(transport.published.last?.topic == HATopics.stateTopic(deviceID: "dev1", entity: .playback))
        #expect(transport.published.last?.payload.string == "OFF")
    }

    @Test
    func invalidPlaybackPayloadDoesNotChangeStateButEchoesCurrentState() async throws {
        let transport = FakeMQTTTransport()
        let control = FakeRemoteControl()
        let coordinator = makeCoordinator(transport: transport, control: control)

        await coordinator.handleIncoming(message("garbage", entity: .playback))

        #expect(control.pauseCount == 0)
        #expect(control.resumeCount == 0)
        #expect(control.playbackState == .playing)
        #expect(transport.published.last?.topic == HATopics.stateTopic(deviceID: "dev1", entity: .playback))
        #expect(transport.published.last?.payload.string == "ON")
    }

    @Test
    func localChangeEchoesActualPlaybackState() async throws {
        let transport = FakeMQTTTransport()
        let control = FakeRemoteControl()
        let coordinator = makeCoordinator(transport: transport, control: control)

        await coordinator.start()
        control.pause()
        control.onLocalChange?()
        try await Task.sleep(for: .milliseconds(10))

        #expect(transport.published.last?.topic == HATopics.stateTopic(deviceID: "dev1", entity: .playback))
        #expect(transport.published.last?.payload.string == "OFF")

        await coordinator.stop()
    }

    @Test
    func reconnectReAnnouncesDiscoveryAndState() async throws {
        let transport = FakeMQTTTransport()
        let control = FakeRemoteControl()
        let coordinator = makeCoordinator(transport: transport, control: control)

        await coordinator.start()
        let publishCountAfterStart = transport.published.count

        await coordinator.handleConnection(false)
        #expect(coordinator.connection == .disconnected)

        await coordinator.handleConnection(true)

        #expect(coordinator.connection == .connected)
        #expect(transport.published.count > publishCountAfterStart)
        #expect(transport.published.suffix(from: publishCountAfterStart).containsMessage(topic: HATopics.availability(deviceID: "dev1"), payload: "online", retain: true))
        #expect(transport.published.suffix(from: publishCountAfterStart).contains { message in
            message.topic == HATopics.discoveryConfigTopic(deviceID: "dev1", entity: .playback) && message.retain
        })
        #expect(transport.published.suffix(from: publishCountAfterStart).containsMessage(topic: HATopics.stateTopic(deviceID: "dev1", entity: .playback), payload: "ON", retain: true))

        await coordinator.stop()
    }

    @Test
    func brightnessCommandSetsClampedBrightnessAndEchoesAppliedValue() async throws {
        let transport = FakeMQTTTransport()
        let control = FakeRemoteControl()
        let coordinator = makeCoordinator(transport: transport, control: control, entities: [.brightness])

        await coordinator.handleIncoming(message("128", entity: .brightness))
        #expect(abs(control.brightness - 128.0 / 255.0) < 0.001)
        #expect(transport.published.last?.topic == HATopics.stateTopic(deviceID: "dev1", entity: .brightness))
        #expect(transport.published.last?.payload.string == "128")

        await coordinator.handleIncoming(message("300", entity: .brightness))
        #expect(control.brightness == 1.0)
        #expect(transport.published.last?.payload.string == "255")

        await coordinator.handleIncoming(message("-10", entity: .brightness))
        #expect(control.brightness == 0.0)
        #expect(transport.published.last?.payload.string == "0")
    }

    @Test
    func brightnessInvalidPayloadKeepsStateAndEchoesCurrent() async throws {
        let transport = FakeMQTTTransport()
        let control = FakeRemoteControl()
        control.brightness = 0.4
        let coordinator = makeCoordinator(transport: transport, control: control, entities: [.brightness])

        await coordinator.handleIncoming(message("not-a-number", entity: .brightness))

        #expect(control.brightness == 0.4)
        #expect(transport.published.last?.topic == HATopics.stateTopic(deviceID: "dev1", entity: .brightness))
        #expect(transport.published.last?.payload.string == "102") // round(0.4 * 255)
    }

    @Test
    func albumCommandSelectsValidAlbumAndEchoesSelection() async throws {
        let transport = FakeMQTTTransport()
        let control = FakeRemoteControl()
        control.albumOptions = ["Wohnzimmer", "Urlaub"]
        let coordinator = makeCoordinator(transport: transport, control: control, entities: [.album])

        await coordinator.handleIncoming(message("Urlaub", entity: .album))

        #expect(control.currentAlbum == "Urlaub")
        #expect(transport.published.last?.topic == HATopics.stateTopic(deviceID: "dev1", entity: .album))
        #expect(transport.published.last?.payload.string == "Urlaub")
    }

    @Test
    func albumCommandIgnoresUnknownAlbumAndEchoesCurrent() async throws {
        let transport = FakeMQTTTransport()
        let control = FakeRemoteControl()
        control.albumOptions = ["Wohnzimmer", "Urlaub"]
        control.currentAlbum = "Wohnzimmer"
        let coordinator = makeCoordinator(transport: transport, control: control, entities: [.album])

        await coordinator.handleIncoming(message("Nonexistent", entity: .album))

        #expect(control.currentAlbum == "Wohnzimmer")
        #expect(transport.published.last?.topic == HATopics.stateTopic(deviceID: "dev1", entity: .album))
        #expect(transport.published.last?.payload.string == "Wohnzimmer")
    }

    @Test
    func startEchoesAllEnabledEntityStates() async throws {
        let transport = FakeMQTTTransport()
        let control = FakeRemoteControl()
        control.brightness = 1.0
        control.albumOptions = ["Wohnzimmer"]
        control.currentAlbum = "Wohnzimmer"
        let coordinator = makeCoordinator(transport: transport, control: control, entities: [.playback, .brightness, .album])

        await coordinator.start()

        #expect(transport.subscriptions.contains(HATopics.commandTopic(deviceID: "dev1", entity: .brightness)))
        #expect(transport.subscriptions.contains(HATopics.commandTopic(deviceID: "dev1", entity: .album)))
        #expect(transport.published.containsMessage(topic: HATopics.stateTopic(deviceID: "dev1", entity: .brightness), payload: "255", retain: true))
        #expect(transport.published.containsMessage(topic: HATopics.stateTopic(deviceID: "dev1", entity: .album), payload: "Wohnzimmer", retain: true))

        await coordinator.stop()
    }

    @Test
    func startWithoutConfigDoesNotConnectOrPublish() async throws {
        let transport = FakeMQTTTransport()
        let control = FakeRemoteControl()
        let coordinator = HAControlCoordinator(
            transport: transport,
            control: control,
            configStore: FakeBrokerConfigStore(config: nil),
            deviceName: "Slideshow"
        )

        await coordinator.start()

        #expect(coordinator.connection == .disconnected)
        #expect(transport.connectCount == 0)
        #expect(transport.published.isEmpty)
    }

    @Test
    func failedConnectLeavesCoordinatorDisconnected() async throws {
        let transport = FakeMQTTTransport()
        transport.connectShouldThrow = true
        let control = FakeRemoteControl()
        let coordinator = makeCoordinator(transport: transport, control: control)

        await coordinator.start()

        #expect(coordinator.connection == .disconnected)
        #expect(transport.connectCount == 1)
        #expect(transport.published.isEmpty)
    }

    @Test
    func stopCancelsConsumersDisconnectsAndMarksDisconnected() async throws {
        let transport = FakeMQTTTransport()
        let control = FakeRemoteControl()
        let coordinator = makeCoordinator(transport: transport, control: control)

        await coordinator.start()
        await coordinator.stop()

        #expect(transport.disconnectCount == 1)
        #expect(coordinator.connection == .disconnected)
    }

    private func makeCoordinator(
        transport: FakeMQTTTransport,
        control: FakeRemoteControl,
        entities: Set<HAEntity> = [.playback]
    ) -> HAControlCoordinator {
        HAControlCoordinator(
            transport: transport,
            control: control,
            configStore: FakeBrokerConfigStore(config: BrokerConfig(
                host: "broker.local",
                port: 8883,
                username: "secret-user",
                password: "secret-pass",
                deviceID: "dev1"
            )),
            deviceName: "Slideshow",
            enabledEntities: entities
        )
    }

    private func message(_ payload: String, entity: HAEntity) -> MQTTMessage {
        MQTTMessage(
            topic: HATopics.commandTopic(deviceID: "dev1", entity: entity),
            payload: Data(payload.utf8),
            retain: false
        )
    }
}

private extension Data {
    var string: String? {
        String(data: self, encoding: .utf8)
    }
}

private extension Sequence where Element == MQTTMessage {
    func containsMessage(topic: String, payload: String, retain: Bool) -> Bool {
        contains { message in
            message.topic == topic && message.payload.string == payload && message.retain == retain
        }
    }
}
