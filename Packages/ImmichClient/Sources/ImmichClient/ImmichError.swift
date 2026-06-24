public enum ImmichError: Error, Equatable {
    case unauthorized
    case unreachable
    case invalidResponse
    case invalidShareLink
    case shareLinkExpired
    case wrongPassword
    case passwordRequired
}
