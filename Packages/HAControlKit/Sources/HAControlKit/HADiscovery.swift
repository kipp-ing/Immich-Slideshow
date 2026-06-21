import Foundation

public enum HADiscovery {
    public static func config(
        for entity: HAEntity,
        deviceID: String,
        deviceName: String,
        albumOptions: [String]
    ) -> Data {
        var json: [String: Any] = [
            "unique_id": "\(deviceID)_\(entity.rawValue)",
            "availability_topic": HATopics.availability(deviceID: deviceID),
            "command_topic": HATopics.commandTopic(deviceID: deviceID, entity: entity),
            "state_topic": HATopics.stateTopic(deviceID: deviceID, entity: entity),
            "name": name(for: entity),
            "device": [
                "identifiers": [deviceID],
                "name": deviceName,
            ],
        ]

        switch entity {
        case .playback:
            json["payload_on"] = "ON"
            json["payload_off"] = "OFF"
        case .brightness:
            // Dimmable light on the basic schema: brightness is the control. HA
            // publishes 0–brightness_scale to the (shared) command topic and reads
            // the applied level back from the (shared) state topic.
            json["brightness_command_topic"] = HATopics.commandTopic(deviceID: deviceID, entity: entity)
            json["brightness_state_topic"] = HATopics.stateTopic(deviceID: deviceID, entity: entity)
            json["brightness_scale"] = 255
            json["on_command_type"] = "brightness"
            json["payload_off"] = "OFF"
        case .album:
            json["options"] = albumOptions
        }

        return (try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])) ?? Data()
    }

    private static func name(for entity: HAEntity) -> String {
        switch entity {
        case .playback:
            "Slideshow Playback"
        case .brightness:
            "Slideshow Brightness"
        case .album:
            "Slideshow Album"
        }
    }
}
