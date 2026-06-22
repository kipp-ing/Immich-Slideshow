# Phase 0 Research: Editable Connection Settings

All technical-context items were known from the existing 002/008 code; the open questions were
design decisions, resolved below.

## D1 — Where the validation/persist logic lives

**Decision**: Add `ConnectionSettingsViewModel` to `OnboardingKit`, and extract the URL normalization
and `ImmichError`→message mapping out of `OnboardingViewModel` into shared `ConnectionURL` /
`ConnectionError` helpers that both view models use.

**Rationale**: `OnboardingKit` already owns `AppConfiguration`, `ConfigStore`, `KeychainStore`, and the
reachable/authorized validation pattern. Reusing it guarantees "valid" means the same thing in
onboarding and in settings (Assumptions), and keeps the new logic host-unit-testable against the
package's existing in-memory fakes (Constitution II). Extraction removes duplication and is a pure
refactor (no behavior change) covered by the existing onboarding tests.

**Alternatives considered**: A brand-new package — rejected as needless module sprawl for logic that
shares all its dependencies with onboarding. Inlining the logic in the SwiftUI view — rejected: not
host-testable, violates MVVM and Constitution I/II.

## D2 — Validation reuse

**Decision**: Validate the candidate connection with a **single `albums()` call** on
`ServerConfig(baseURL, apiKey)`. Because the editor supplies both URL and key together, one authorized
request proves reachability AND authorization at once, and `ImmichError` classifies the failure:
`.unreachable` (no response), `.unauthorized` (401), `.invalidResponse` (other). The same call returns
the album list used for FR-013. Map `ImmichError` to messages via the shared `ConnectionError` helper.

**Rationale**: Onboarding splits the checks only because it collects the URL and key in two separate
steps (`serverVersion()` before any key exists, `albums()` after). The settings editor has both values
at once, so a separate unauthenticated `serverVersion()` call is redundant. A single `albums()` call is
simpler, classifies unreachable vs unauthorized identically, and yields the album-existence list in the
same round-trip — and it is testable with the existing single-response `MockTransport`/in-memory fakes.

**Alternatives considered**: `serverVersion()` then `albums()` (the onboarding pair) — rejected:
redundant for a combined URL+key entry and awkward to test (one fixed mock response can't satisfy both a
version body and an albums body). A dedicated `/auth/validate` path — rejected: a new API path to verify
against OpenAPI for no gain over `albums()`, which we already need.

## D3 — Atomic persist ordering

**Decision**: Validate BOTH values fully before persisting anything. Then persist **Keychain first**
(`keychain.save` can `throw`), and only on its success persist the config (`config.save` cannot throw).
If the Keychain write fails, surface "could not securely store the API key" and persist nothing.

**Rationale**: Two separate stores can't be transactional, but ordering the fallible write first makes
the save effectively all-or-nothing (FR-005): the only failable step happens before the infallible one,
so there is no state where the URL is updated but the key is not.

**Alternatives considered**: Config first then key — rejected: a Keychain failure would leave a new URL
pointing at a server the stored key isn't valid for. Snapshot-and-rollback — rejected as overkill given
the ordering already yields atomicity.

## D4 — Applying the change to the running slideshow without re-onboarding

**Decision**: On a successful save, an app-layer reconnect closure rebuilds the slideshow's
`ImmichClient` from the now-updated `ConfigStore`+`KeychainStore` and re-runs the show against the
preserved album, staying in the `.done` state. This `RootView` wiring is implemented inline (not
delegated) per CLAUDE.md (app-entry/onboarding wiring).

**Rationale**: `SlideshowViewModel` already reloads via `start()`/`switchAlbum()`; rebuilding its client
and restarting is the smallest change that reuses existing, tested reload behavior (FR-006, SC-004).
Keeping the wiring in `RootView` mirrors how the slideshow is constructed today (`makeSlideshow`).

**Alternatives considered**: Mutating `SlideshowViewModel.api` in place + a bespoke `reconnect()` —
rejected for v1: makes the model's `api` mutable shared state for marginal benefit over a clean rebuild.
Returning to onboarding `.done` via the reset path — rejected: it clears the album, which the spec
forbids (no re-onboarding).

## D5 — Album that no longer exists under the new connection (FR-013)

**Decision**: The save already fetches `albums()` for the auth check; if that list does not contain the
previously selected album ID, route the user to album re-selection (reuse the 007 album browser) instead
of onboarding.

**Rationale**: The data needed to detect this is already in hand from the auth check, so no extra call.
Reusing the album browser keeps the recovery in-app and avoids a full reset (FR-013, US2 scenario 3).

**Alternatives considered**: Auto-pick the first album — rejected: surprising and may show the wrong
album. Block the save — rejected: the connection itself is valid; only album selection needs attention.

## D6 — Showing the existing API key

**Decision**: Never display the stored key. Show the current server URL (editable) and a "key is set"
indicator with a masked/secure replace field; an empty key field on save means "keep the existing key"
(supporting URL-only edits, FR-011).

**Rationale**: Constitution III forbids surfacing the secret; reading it back into the UI just to display
it would widen its exposure for no user value. "Empty = unchanged" lets a URL-only change skip
re-entering the key.

**Alternatives considered**: Reveal-on-tap of the stored key — rejected: unnecessary secret exposure.
Requiring the key every save — rejected: fails FR-011 (one-field edits).
