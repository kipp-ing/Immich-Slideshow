import Foundation

public enum HAEntity: String, CaseIterable, Sendable {
    case playback
    case brightness
    case album
}

public enum PlaybackState: Sendable, Equatable {
    case playing
    case paused
}

public enum ConnectionState: Sendable, Equatable {
    case disconnected
    case connecting
    case connected
}
