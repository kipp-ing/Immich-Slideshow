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
            break
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
