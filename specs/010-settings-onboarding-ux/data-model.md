# Phase 1 Data Model: Settings & Onboarding UX Consolidation

No new persisted entities. This feature re-presents existing configuration. The only model-level
changes are (a) the onboarding step enum and (b) a new in-memory view-model holding the broker form
state. Persisted shapes (`AppConfiguration`, `BrokerSettings`, Keychain secrets) are unchanged.

## Changed: `OnboardingStep`

```
OnboardingStep (before): .server | .apiKey | .album | .done
OnboardingStep (after):  .connection | .album | .done
```

- `.connection` replaces the former `.server` + `.apiKey` pair: one screen collects server URL + API
  key and validates them in a single action.
- `.album` and `.done` are unchanged.
- **State transitions**:
  - `.connection → .album` on a successful `submitConnection()` (server reachable AND key authorized
    AND album list non-empty; key persisted to Keychain).
  - `.connection → .connection` (stays) on any failure: invalid URL, unreachable server, unauthorized
    key, Keychain save failure, or empty album list — with an inline error and entered values kept.
  - `.album → .done` on `selectAlbum(id:)` (unchanged).
  - `reset()` returns to `.connection` and clears inputs (was `.server`).

## Onboarding view-model fields (existing, reused)

`OnboardingViewModel` keeps its fields: `serverURLInput`, `apiKeyInput`, `albums`, `selectedAlbumID`,
`isBusy`, `errorMessage`, plus `step`. The two submit methods collapse into one:

- `submitConnection()` — validates URL via `ConnectionURL.normalize`, calls `albums()` once with
  `ServerConfig(baseURL:, apiKey: apiKeyInput)`, maps `ImmichError` via `ConnectionError.message(for:)`
  (distinct unreachable vs unauthorized), saves the key to the Keychain only on success, sets `albums`,
  and advances to `.album` (or stays with an error if the list is empty).

## New: `BrokerSetupViewModel` (in-memory, `@Observable`)

Extracted from `BrokerSetupView`'s `@State` + private methods so the broker form logic is host-testable
and embeddable inline in Settings.

| Field | Type | Notes |
|-------|------|-------|
| `host` | `String` | broker host |
| `port` | `String` | numeric text input; parsed to `Int` on save |
| `username` | `String` | broker username |
| `password` | `String` | secure input; empty + existing ⇒ keep stored (FR-013) |
| `passwordIsSet` | `Bool` | true when a password is already stored; drives the "is set" hint |
| `validationMessage` | `String?` | mapped from `BrokerValidationError` |

**Behaviors** (move verbatim from the current view, no behavior change):
- `load()` — prefill host/port/username from the stored `BrokerSettings`; leave password blank and set
  `passwordIsSet = true` (never prefill the secret).
- `save()` — if password is empty and a broker is stored, reuse the stored secret; build
  `BrokerSettings`, persist via `BrokerSettingsStore.save`, map `BrokerValidationError` to
  `validationMessage` on failure.
- `remove()` — `BrokerSettingsStore.clear()`.

Dependencies are injected (`BrokerSettingsStore`), matching the existing protocol; tests use an
in-memory store (the existing `BrokerSetupUITestStore` pattern / a test double).

## Unchanged persisted shapes

- **`AppConfiguration`**: `baseURL` + `selectedAlbumID` in UserDefaults via `ConfigStore`.
- **API key**: Keychain only via `KeychainStore`.
- **`BrokerSettings`**: `host`/`port`/`username` + `password`; password in the Keychain via
  `KeychainBrokerSettingsStore`.

## Reserved (not modeled here): shared-album-link

The onboarding screen reserves a visible, inert placeholder for a future shared-album-link entry. No
field, storage, or state backs it in this feature — it is deferred to spec 011.
