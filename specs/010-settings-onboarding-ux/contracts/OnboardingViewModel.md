# Contract: `OnboardingViewModel` (merged `.connection` step)

Package: `OnboardingKit`. Backs US1. Reuses `ConnectionURL`, `ConnectionError`, `ImmichAPI`,
`ConfigStore`, `KeychainStore`. The two pre-album submit methods collapse into one validated action.

## Surface change

```
// removed: case .server, case .apiKey
enum OnboardingStep { case connection, album, done }

// removed: func submitServerURL(); func submitAPIKey()
func submitConnection() async        // validates server + key in one action
```

`reset()` now returns `step` to `.connection`. All other fields/methods (`serverURLInput`,
`apiKeyInput`, `albums`, `selectedAlbumID`, `isBusy`, `errorMessage`, `selectAlbum(id:)`) unchanged.

## `submitConnection()` behavior

1. No-op if `isBusy`. Clear `errorMessage`.
2. Normalize `serverURLInput` via `ConnectionURL.normalize`; on failure set the invalid-HTTPS message
   and stay on `.connection` (no network call).
3. Set `isBusy`; call `albums()` once with `ServerConfig(baseURL:, apiKey: apiKeyInput)`.
4. On `ImmichError`: set `errorMessage = ConnectionError.message(for:)` and stay on `.connection`
   (key is **not** saved). Unreachable and unauthorized produce **distinct** messages.
5. On success: save the key to the Keychain. If the save throws → secure-store error, stay on
   `.connection`, key not persisted.
6. Set `albums`. If empty → "no albums" message, stay on `.connection`.
7. Otherwise advance `step = .album`.

## Acceptance tests (Swift Testing, host) — rewritten from existing step tests

| Test | Given | Then |
|------|-------|------|
| `rejectsNonHTTPSURL` | `serverURLInput = "http://foo"`, key set | stays `.connection`, invalid-HTTPS error, no network |
| `advancesToAlbumWhenReachableAndAuthorized` | valid URL + key, `albums()` returns ≥1 | `step == .album`, key saved, `albums` populated |
| `staysWhenServerUnreachable` | `albums()` throws `.unreachable` | stays `.connection`, server-style message, key **not** saved |
| `staysWhenUnauthorized` | `albums()` throws `.unauthorized` | stays `.connection`, key-style message (≠ unreachable message), key **not** saved |
| `staysWhenKeychainSaveFails` | `albums()` ok, keychain `save` throws | stays `.connection`, secure-store error, no advance |
| `staysWhenAlbumListEmpty` | `albums()` returns `[]` | stays `.connection`, no-albums message |
| `requiresBothFields` (view-level) | either field empty | Continue disabled (asserted in the SwiftUI/UI layer) |
| `resetReturnsToConnection` | any state | `reset()` → `.connection`, inputs cleared |

Distinct-message assertion (`staysWhenUnauthorized` ≠ `staysWhenServerUnreachable`) covers SC-006.

## Out of scope

No shared-album-link logic (deferred to 011). The reserved seam is view-only and carries no view-model
state.
