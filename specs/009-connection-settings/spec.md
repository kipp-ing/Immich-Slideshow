# Feature Specification: Editable Connection Settings

**Feature Branch**: `009-connection-settings`

**Created**: 2026-06-22

**Status**: Draft

**Input**: User description: "Allow adjusting the Immich connection settings — server URL and API
key — from the in-app Settings screen, not only during initial onboarding. The API key must stay in
the Keychain (never UserDefaults or logs); TLS validation must not be disabled. Saving a changed URL
or key should validate the connection (reachable + authorized) before persisting, surface a clear
error on failure, and apply to the running slideshow without requiring a full reset/re-onboarding."

Today the server URL and API key can only be set during the 3-step onboarding (002). Changing either
— a rotated API key, a moved server — forces a full reset back to onboarding, tearing down the
running slideshow. This feature surfaces those two values in the existing in-app Settings screen
(built in 008) so they can be reviewed and changed in place, validated before they take effect, and
applied to the running slideshow without re-onboarding.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Change the connection from Settings, validated before it takes effect (Priority: P1) 🎯 MVP

While the slideshow is running, the user opens Settings and finds a **Connection** (Verbindung)
section showing the current server URL and that an API key is set (the key itself is never shown).
They edit the URL and/or replace the API key and save. The app first checks the new connection is
reachable and the key is authorized; only then does it persist the change and continue the slideshow
against the new connection. If the check fails, nothing is changed and a clear error explains why.

**Why this priority**: This is the whole point of the feature — making the two connection values
editable after onboarding, safely. It carries the validation + atomic-persist + Keychain plumbing
that the recovery story (US2) reuses. It is the minimal slice that delivers value on its own.

**Independent Test**: With a working slideshow, open Settings → Connection, change the API key to a
wrong value and save → the change is rejected with an "unauthorized" message and the slideshow keeps
running on the old key. Change it to the correct (e.g. rotated) key and save → it persists, the
slideshow reloads against the new key, and the value survives an app relaunch.

**Acceptance Scenarios**:

1. **Given** a working connection, **When** the user opens Settings, **Then** the Connection section
   shows the current server URL and an indication that an API key is set, with the key never shown in
   plaintext.
2. **Given** the Connection editor, **When** the user enters a syntactically invalid URL (no
   scheme/host) and saves, **Then** an inline well-formedness error is shown and no network request is
   made.
3. **Given** a reachable server but a wrong API key, **When** the user saves, **Then** the change is
   rejected with an "unauthorized" error, and the previously working URL and key remain in effect.
4. **Given** a URL that cannot be reached, **When** the user saves, **Then** the change is rejected
   with an "unreachable" error, and the previous connection remains in effect.
5. **Given** a reachable server and a valid key, **When** the user saves, **Then** the URL is
   persisted to app config, the key is persisted to the Keychain, and both replace the prior values
   with no half-applied state.
6. **Given** a successful change, **When** the user dismisses Settings, **Then** the running slideshow
   continues against the new connection without returning to onboarding.
7. **Given** any successful change, **When** the app is relaunched, **Then** the new server URL and key
   are still in effect.
8. **Given** the Connection editor with unsaved edits, **When** the user cancels/dismisses without
   saving, **Then** the existing connection is unchanged.

---

### User Story 2 - Recover a broken connection in place, without re-onboarding (Priority: P2)

The slideshow is showing the calm error state because the connection broke — the API key expired or
the server address changed. Instead of resetting the whole app (which clears the album and returns to
onboarding step 1), the user reaches the Connection editor, fixes the URL and/or key, and on a
successful save the slideshow resumes against the corrected connection.

**Why this priority**: Recovering from a broken connection is the highest-stress moment for an ambient
frame, but it builds directly on US1's editor and validation; the show already runs without it (via
the existing reset path). This makes the fix a quiet in-place correction rather than a full
re-setup.

**Independent Test**: Put the slideshow into a connection-error state (revoke/expire the key), open
the Connection editor from the error state, enter a valid key, and save → the slideshow leaves the
error state and resumes showing photos from the previously selected album, with no onboarding steps.

**Acceptance Scenarios**:

1. **Given** the slideshow is in a connection-error state, **When** the user opens the Connection
   editor and saves a valid connection, **Then** the slideshow leaves the error state and resumes the
   previously selected album without re-running onboarding.
2. **Given** only the API key changed (URL unchanged), **When** the user saves, **Then** the save
   succeeds without requiring the URL to be re-entered (and vice versa for a URL-only change).
3. **Given** the new connection is valid but no longer contains the previously selected album,
   **When** the change is saved, **Then** the user is prompted to re-select an album rather than being
   dropped into onboarding.

---

### Edge Cases

- **New server lacks the selected album**: the previously selected album does not exist under the new
  connection → surface album re-selection (reuse the existing album browser), not a reset to
  onboarding.
- **URL without a scheme** (e.g. `photos.example`): treated as a well-formedness error (or normalized
  consistently with onboarding) before any network call.
- **Trailing slash / path variants** in the URL are normalized the same way onboarding normalizes
  them, so the same server is not treated as two.
- **Network drops mid-validation**: treated as "unreachable"; nothing is persisted.
- **Empty URL or empty key on save**: inline validation error; no network call, no persist.
- **Validation succeeds for the URL but the key check then fails** (or vice versa): the save is
  all-or-nothing — neither value is persisted.
- **Save tapped twice / while a check is in flight**: only one validation runs; the editor reflects an
  in-progress state and does not double-persist.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Settings MUST present a Connection section showing the current server URL and an
  indication that an API key is set, without ever revealing the key in plaintext.
- **FR-002**: Users MUST be able to edit the server URL and replace the API key from that section; the
  API-key entry field MUST be masked/secure.
- **FR-003**: On save, the system MUST validate that the entered server URL is reachable AND that the
  entered API key is authorized for it (an authorized request such as fetching the server version or
  album list succeeds) BEFORE persisting anything.
- **FR-004**: On failed validation, the system MUST NOT persist any change, MUST keep the previously
  working connection in effect, and MUST surface a clear, specific error that distinguishes
  "unreachable" from "unauthorized" where the underlying result allows.
- **FR-005**: On successful validation, the system MUST persist the server URL to app configuration
  and the API key to the Keychain, replacing the prior values atomically (no state where one is
  updated and the other is not).
- **FR-006**: After a successful change, the running slideshow MUST adopt the new connection without a
  full reset/re-onboarding, reloading the current album's assets under the new connection.
- **FR-007**: The API key MUST reside only in the Keychain; it MUST NEVER be written to UserDefaults,
  logs, the source tree, or any exported/committed file, and MUST NEVER be rendered in plaintext.
- **FR-008**: All connection attempts MUST use standard TLS-validated transport (as in onboarding);
  TLS validation MUST NOT be disabled or bypassed.
- **FR-009**: The server URL MUST be checked for basic well-formedness (scheme + host) before any
  network attempt; malformed input surfaces an inline error without a network call.
- **FR-010**: Dismissing/canceling the editor without a successful save MUST leave the existing
  connection unchanged.
- **FR-011**: When only one of the two values changes, the user MUST be able to save without
  re-entering the unchanged value.
- **FR-012**: The Connection editor MUST be reachable both during normal playback (proactive change)
  and from the slideshow's connection-error state (recovery), and a successful save from the error
  state MUST resume the slideshow without re-running onboarding.
- **FR-013**: If, after a successful connection change, the previously selected album no longer exists
  under the new connection, the system MUST prompt for album re-selection rather than returning to
  onboarding.

### Key Entities *(include if feature involves data)*

- **Connection configuration**: the pairing the slideshow runs against — a non-secret server base URL
  (persisted in app configuration) and a secret API key (persisted only in the Keychain). Exactly one
  is active at a time.
- **Connection validation result**: the outcome of checking a candidate configuration — well-formed,
  reachable, authorized — or a specific failure classification (malformed, unreachable, unauthorized)
  used to drive the error message and the persist/skip decision.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can change the server URL or API key and return to a working slideshow in under
  60 seconds, without performing any onboarding step.
- **SC-002**: 100% of save attempts against an unreachable server or with an incorrect key are
  rejected with a clear error and leave the prior working connection fully intact (the slideshow never
  ends up in a broken state caused by a rejected change).
- **SC-003**: The API key is never present in plaintext anywhere outside the Keychain — not in the UI,
  logs, UserDefaults, or any committed/exported file — verifiable by inspection.
- **SC-004**: After a successful change, the slideshow shows photos from the new connection within
  5 seconds, with no app restart.
- **SC-005**: A user whose connection has broken (expired key or moved server) can restore the running
  slideshow from Settings in under 60 seconds without a full reset/re-onboarding.

## Assumptions

- The reachability + authorization check reuses the same validation the onboarding flow already
  performs (002), so "valid" means the same thing in both places.
- The server presents a valid TLS certificate; self-signed and plaintext/local-downgrade connections
  remain out of scope (Constitution IV) and are not enabled by this feature.
- Exactly one server + one API key are active at a time; multi-account/multi-server is out of scope.
- The Connection editor lives in the existing in-app Settings screen built in 008 and reuses the
  existing config store, Keychain store, and `ImmichAPI` client seams.
- URL normalization (scheme, trailing slash) matches onboarding's behavior so the two entry points
  agree on what a given server is.
- The currently selected album persists across a connection change when it still exists under the new
  connection; absence triggers album re-selection (reusing the 007 album browser), not onboarding.
- The existing full-reset path (clear server + key + album, return to onboarding) remains available
  and unchanged; this feature adds an in-place edit alongside it, it does not replace it.
