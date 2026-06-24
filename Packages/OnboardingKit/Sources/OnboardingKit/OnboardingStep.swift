public enum OnboardingStep: Sendable, Equatable {
    case connection
    // Add the first source after connecting: an Immich album (picker) or a shared
    // link (URL + optional password). Replaces the old single-album step (120, US2).
    case source
    // Review the saved library and start: lists the sources with the active one marked.
    case confirm
    case done
}
