# Contract: ConnectionSettingsViewModel (OnboardingKit)

Backs the in-app connection editor: validate a candidate server URL + API key (reachable + authorized)
and, only then, persist atomically. Lives in `OnboardingKit`, depends only on injected protocols, and is
host-unit-testable against the package's in-memory fakes. No new network path is introduced — it reuses
`serverVersion()` (reachability) and `albums()` (authorization) on `ImmichClient`.

## Surface (intended shape)

```swift
@Observable public final class ConnectionSettingsViewModel {
    public var serverURLInput: String       // pre-filled from the stored AppConfiguration.baseURL
    public var apiKeyInput: String           // starts empty; empty on save = keep existing key
    public private(set) var isBusy: Bool
    public private(set) var errorMessage: String?
    public private(set) var keyIsSet: Bool   // drives the "key is set" indicator (never the key itself)

    public init(
        api: @escaping (ServerConfig) -> any ImmichAPI,
        config: ConfigStore,
        keychain: KeychainStore
    )

    /// Validate the draft and, on success, persist atomically. Returns the outcome so the app layer
    /// can drive the live reconnect / album re-selection.
    public func save() async -> ConnectionValidationOutcome
}
```

`ConnectionURL.normalize(_:) -> URL?` and `ConnectionError.message(for: ImmichError) -> String` are the
helpers extracted from `OnboardingViewModel` and shared by both view models.

## Behavior

| # | Given | When | Then |
|---|-------|------|------|
| 1 | stored config exists | the editor opens | `serverURLInput` is pre-filled with the stored URL; `apiKeyInput` is empty; `keyIsSet == (keychain.read() != nil)` — the stored key is never read into `apiKeyInput` (FR-001, FR-007, D6) |
| 2 | URL without scheme/host | `save()` | returns `.malformed`, **no** network call, nothing persisted (FR-009) |
| 3 | reachable server, wrong key | `save()` | `albums()` → `.unauthorized`; returns `.unauthorized`; prior config + key intact (FR-004, SC-002) |
| 4 | unreachable URL | `save()` | `serverVersion()`/`albums()` → `.unreachable`; returns `.unreachable`; nothing persisted (FR-004) |
| 5 | reachable + valid key + album still present | `save()` | Keychain write then config write; returns `.success`; values replace prior ones atomically (FR-003, FR-005, D3) |
| 6 | valid key but Keychain write throws | `save()` | returns `.keychainFailure`; config **not** written (FR-005, D3) |
| 7 | URL-only change, `apiKeyInput` empty | `save()` | validates with the existing stored key; on success persists the new URL and keeps the key (FR-011) |
| 8 | valid connection, selected album absent in `albums()` | `save()` | persists the validated connection, returns `.albumMissing(albums:)` for re-selection (FR-013) |
| 9 | any failure outcome | `save()` | `errorMessage` set to the classified message; `isBusy` returns to false; prior state unchanged (FR-004, FR-010) |
| 10 | a `save()` already in flight | `save()` called again | guarded by `isBusy`; a single validation runs; no double-persist (edge case) |

## Constitution / security checks (review gate)

- API key never logged, never written to UserDefaults, never read back into the UI; only `keychain.save`
  receives it (III, FR-007, SC-003).
- All requests go through the standard `ImmichClient`; no TLS bypass (IV, FR-008).
- Validate-before-persist and Keychain-first ordering give all-or-nothing saves (FR-005, D3).

## Notes

- The live reconnect (rebuilding `SlideshowViewModel`'s client) and the entry points (settings row,
  error-state "fix connection") are app-target/SwiftUI concerns, verified via XcodeBuildMCP — not part
  of this host-testable contract.
- Confirm no new Immich path is needed: only `serverVersion()` and `albums()` are used, both already in
  `ImmichAPI` and verified against the live OpenAPI in 001/002.
