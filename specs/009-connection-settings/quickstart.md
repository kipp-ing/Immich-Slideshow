# Quickstart: Editable Connection Settings

Validation guide proving the feature end to end. Host unit tests cover the view-model logic; simulator
steps cover the SwiftUI editor + live reconnect.

## Prerequisites

- `OnboardingKit` builds; existing onboarding tests green (the URL/error extraction is a no-op refactor).
- Simulator steps use the hermetic `--uitest` seam (stub `ImmichAPI`, in-memory config/keychain) per
  `Immich_SlideshowApp.swift`.

## 1. Host unit tests (US1 core — run first, must fail before implementation)

```
swift test --package-path Packages/OnboardingKit
```

Expected `ConnectionSettingsViewModelTests` coverage (maps to the contract table):
- malformed URL → `.malformed`, no network, nothing persisted
- reachable + wrong key → `.unauthorized`, prior config/key intact
- unreachable → `.unreachable`, nothing persisted
- reachable + valid key + album present → `.success`, config+key replaced (Keychain-first)
- Keychain write throws → `.keychainFailure`, config not written
- URL-only change (empty key) → validates with existing key, persists URL, keeps key
- valid connection, album absent → `.albumMissing(albums:)`, connection persisted
- existing onboarding tests still green after the URL/error helper extraction

## 2. Settings entry point (US1 — simulator)

1. Launch with `--uitest --uitest-slideshow --uitest-settings`.
2. Confirm a **Verbindung** row exists in Settings showing the current server URL and a "key is set"
   indicator; the API key is **not** shown in plaintext (FR-001, SC-003).
3. Open the editor → confirm a masked/secure key field and an editable URL field.

## 3. Validation rejects bad input, keeps the show working (US1 — simulator)

1. In the editor, enter a wrong key and save → an "unauthorized" message appears; dismiss → the
   slideshow is still running on the old connection (FR-004, SC-002).
2. Enter a malformed URL and save → inline well-formedness error, no spinner/network (FR-009).

## 4. Successful change applies live (US1 — simulator)

1. Enter a valid connection and save → the editor dismisses and the slideshow reloads against the new
   connection within ~5 s, with no onboarding step (FR-005, FR-006, SC-001, SC-004).
2. Relaunch the app → the new URL/key are still in effect (acceptance scenario 7).

## 5. Recovery from a broken connection (US2 — simulator)

1. Drive the slideshow into the connection-error state (expired/revoked key).
2. From the error state, open the connection editor, enter a valid key, save → the slideshow leaves the
   error state and resumes the previously selected album, no onboarding (FR-012, SC-005).
3. If the new connection lacks the selected album → the album browser appears for re-selection rather
   than onboarding (FR-013).

## 6. Cancel is a no-op (US1 — simulator)

1. Open the editor, edit fields, dismiss without saving → the connection is unchanged (FR-010).

## Security spot-check (review gate)

- Grep the diff: the API key string is passed only to `keychain.save`; it is never logged, never set in
  UserDefaults, never interpolated into a view label (III, FR-007, SC-003).
- No `URLSession`/TLS delegate overrides; all traffic uses the standard `ImmichClient` (IV, FR-008).
