import Foundation
import Testing
@testable import HAControlKit

@Suite
struct HADiscoveryTests {
    @Test
    func playbackDiscoveryContainsStableTopicsAndDevice() throws {
        let first = HADiscovery.config(for: .playback, deviceID: "dev1", deviceName: "Slideshow", albumOptions: [])
        let second = HADiscovery.config(for: .playback, deviceID: "dev1", deviceName: "Slideshow", albumOptions: [])

        #expect(first == second)

        let json = try Self.object(from: first)
        #expect(json["unique_id"] as? String == "dev1_playback")
        #expect(json["availability_topic"] as? String == HATopics.availability(deviceID: "dev1"))
        #expect(json["command_topic"] as? String == HATopics.commandTopic(deviceID: "dev1", entity: .playback))
        #expect(json["state_topic"] as? String == HATopics.stateTopic(deviceID: "dev1", entity: .playback))
        #expect(json["payload_on"] as? String == "ON")
        #expect(json["payload_off"] as? String == "OFF")

        let device = try #require(json["device"] as? [String: Any])
        #expect(device["identifiers"] as? [String] == ["dev1"])
        #expect(device["name"] as? String == "Slideshow")
    }

    @Test
    func brightnessDiscoveryIsDimmableLightWithBrightnessTopics() throws {
        let data = HADiscovery.config(for: .brightness, deviceID: "dev1", deviceName: "Slideshow", albumOptions: [])
        let json = try Self.object(from: data)

        #expect(json["unique_id"] as? String == "dev1_brightness")
        #expect(json["availability_topic"] as? String == HATopics.availability(deviceID: "dev1"))
        #expect(json["command_topic"] as? String == HATopics.commandTopic(deviceID: "dev1", entity: .brightness))
        #expect(json["state_topic"] as? String == HATopics.stateTopic(deviceID: "dev1", entity: .brightness))
        #expect(json["brightness_command_topic"] as? String == HATopics.commandTopic(deviceID: "dev1", entity: .brightness))
        #expect(json["brightness_state_topic"] as? String == HATopics.stateTopic(deviceID: "dev1", entity: .brightness))
        #expect(json["brightness_scale"] as? Int == 255)

        let device = try #require(json["device"] as? [String: Any])
        #expect(device["identifiers"] as? [String] == ["dev1"])
    }

    @Test
    func albumDiscoveryIsSelectWithOptions() throws {
        let options = ["Wohnzimmer", "Urlaub 2026"]
        let data = HADiscovery.config(for: .album, deviceID: "dev1", deviceName: "Slideshow", albumOptions: options)
        let json = try Self.object(from: data)

        #expect(json["unique_id"] as? String == "dev1_album")
        #expect(json["command_topic"] as? String == HATopics.commandTopic(deviceID: "dev1", entity: .album))
        #expect(json["state_topic"] as? String == HATopics.stateTopic(deviceID: "dev1", entity: .album))
        #expect(json["options"] as? [String] == options)
    }

    @Test
    func discoveryPayloadContainsNoCredentialFields() throws {
        let data = HADiscovery.config(for: .playback, deviceID: "dev1", deviceName: "Slideshow", albumOptions: [])
        let json = try Self.object(from: data)

        #expect(json["username"] == nil)
        #expect(json["password"] == nil)
        #expect(json["user"] == nil)
        #expect(json["pass"] == nil)
    }

    private static func object(from data: Data) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
