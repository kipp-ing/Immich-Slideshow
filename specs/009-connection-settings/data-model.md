# Phase 1 Data Model: Editable Connection Settings

No new persisted entities. The feature reuses `AppConfiguration` (server URL + selected album ID, in
UserDefaults) and the Keychain-stored API key. The new types below are transient (in-memory) view-model
state.

## ConnectionDraft (transient)

The editor's in-progress input.

| Field | Type | Notes |
|-------|------|-------|
| `serverURLInput` | String | User-entered URL; normalized by `ConnectionURL` before use. |
| `apiKeyInput` | String | Masked/secure entry. **Empty = keep existing key** (D6, FR-011). |

Derived: `hasURLChange` (normalized input differs from the stored URL), `hasKeyChange`
(`apiKeyInput` non-empty). At least one must be true for a meaningful save; an all-unchanged save is a
no-op success.

## ConnectionValidationOutcome (transient)

Result of validating a draft, before any persistence.

| Case | Meaning | Source |
|------|---------|--------|
| `.malformed` | URL fails scheme+host well-formedness | `ConnectionURL.normalize` returns nil (no network) — FR-009 |
| `.unreachable` | Server did not respond | `ImmichError.unreachable` from `serverVersion()`/`albums()` — FR-004 |
| `.unauthorized` | Key rejected | `ImmichError.unauthorized` from `albums()` — FR-004 |
| `.invalidResponse` | Unexpected server response | `ImmichError.invalidResponse` |
| `.keychainFailure` | Validated, but Keychain write failed | `keychain.save` threw — D3 |
| `.albumMissing(albums:)` | Valid connection, selected album absent | auth `albums()` list lacks stored album ID — FR-013 |
| `.success` | Validated and persisted | both checks passed, atomic persist done |

State rule: persistence happens **only** on the path to `.success` (or `.albumMissing`, which still
persists the validated connection and then routes to album re-selection). All failure cases persist
nothing and leave the prior `AppConfiguration` + Keychain key intact (FR-004, SC-002).

## Validation rules (from requirements)

- **URL well-formedness** (FR-009): trimmed, `https` scheme, non-nil host; `https://` prepended when no
  scheme is present (matches onboarding normalization, D2). Checked before any network call.
- **Reachable + authorized before persist** (FR-003): `serverVersion()` then `albums()` must both
  succeed against the candidate config before any store write.
- **Atomic persist** (FR-005, D3): Keychain write first (fallible), then config write (infallible);
  abort with `.keychainFailure` if the Keychain write throws.
- **Key secrecy** (FR-007): `apiKeyInput` is never logged or persisted outside the Keychain; the stored
  key is never read back for display.
- **No-op on cancel** (FR-010): dismissing without a `.success`/`.albumMissing` outcome changes nothing.

## Relationships

- `ConnectionSettingsViewModel` depends on the injected `ImmichAPI` factory `(ServerConfig) -> ImmichAPI`,
  `ConfigStore`, and `KeychainStore` — the same seams `OnboardingViewModel` uses.
- On `.success`/`.albumMissing`, the app layer rebuilds the running `SlideshowViewModel`'s client from
  the updated stores (D4) — no data model change to `SlideshowViewModel`.
