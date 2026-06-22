import ImmichClient

public enum ConnectionValidationOutcome: Sendable {
    case malformed
    case unreachable
    case unauthorized
    case invalidResponse
    case keychainFailure
    case albumMissing(albums: [Album])
    case success
}
