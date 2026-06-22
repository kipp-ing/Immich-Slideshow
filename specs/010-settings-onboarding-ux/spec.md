# Feature Specification: Settings & Onboarding UX Consolidation

**Feature Branch**: `010-settings-onboarding-ux`

**Created**: 2026-06-22

**Status**: Implemented

**Input**: User description: "Consolidate the onboarding and settings UX (no new backend / no new Immich
API). Merge the onboarding server-URL and API-key steps into one screen with a single Continue button
and explanatory text; fold Connection and MQTT/broker settings into the main settings screen as
collapsible sections (MQTT is currently only reachable via the hidden reset dialog); and fix the
settings screen so all sections are reachable by scrolling. UI/UX only — no new Immich REST endpoints;
the optional shared-album-link entry is reserved as a visual seam but deferred to spec 011. Keychain
and TLS rules unchanged."

This feature reshapes how existing configuration is presented. It changes **no** backend behavior and
adds **no** Immich REST endpoints: it reuses the onboarding validation (002), the in-place connection
editing (009), and the broker setup (006). The optional shared-album-link feature is **out of scope**
here and tracked separately in spec 011 — this feature only reserves a visible placement for it.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - One-screen connection during first-run onboarding (Priority: P1) 🎯 MVP

On first launch the user reaches a single setup screen that asks for the Immich server address and an
API key together, with short explanations of each, and a single primary **Continue** button. Pressing
Continue checks in one step that the server is reachable and the key is authorized, then moves the
user straight to album selection. Today this is split across two screens ("Continue" on the server
screen, then "Connect" on the API-key screen), which feels like two setups for one connection.

**Why this priority**: This is the most visible friction in first-run setup and the headline of the
request. It delivers value on its own — a shorter, clearer onboarding — independent of the settings
and scroll work.

**Independent Test**: With a mocked data source, open first-run onboarding, enter a valid server
address and a valid API key on the one combined screen, press Continue once, and confirm the user
lands on album selection with the key stored in the Keychain. Enter a wrong key and confirm the screen
stays open with a clear error and the entered values preserved.

**Acceptance Scenarios**:

1. **Given** no prior setup, **When** the user opens onboarding, **Then** the server address and API
   key fields appear together on one screen, each with concise helper text, above a single primary
   Continue action.
2. **Given** a valid server address and a valid API key entered on the combined screen, **When** the
   user presses Continue, **Then** the app validates reachability and authorization in one action,
   stores the key in the Keychain, and advances to album selection.
3. **Given** a reachable server but an unauthorized key, **When** the user presses Continue, **Then**
   the screen stays open, the entered values are preserved, and a clear error distinguishes an
   unauthorized key from an unreachable server.
4. **Given** the combined screen, **When** either the server field or the API-key field is empty,
   **Then** the Continue action is unavailable until both are provided.
5. **Given** a successful connection, **When** album selection appears and the user picks an album,
   **Then** onboarding completes exactly as it does today (album step is unchanged).

---

### User Story 2 - Connection and MQTT folded into Settings (Priority: P2)

While the slideshow is running the user opens Settings and finds the **Connection** (server URL + API
key) and **MQTT / broker** configuration as collapsible sections within the same screen, alongside
brightness and display options. Today the broker setup is only reachable through the "Reset
configuration?" confirmation dialog — effectively hidden — and the connection is a row that pushes a
separate sheet. After this story, both are discoverable and editable directly in Settings.

**Why this priority**: Fixes a real discoverability bug (buried MQTT setup) and unifies configuration
in one place. It is independently testable and valuable, but the headline onboarding improvement (US1)
comes first.

**Independent Test**: From a running slideshow open Settings and confirm a Connection section and an
MQTT/broker section are both present as collapsible sections. Expand MQTT, change the host, and save —
confirm it persists without going through the reset dialog. Confirm the reset dialog no longer hosts
broker setup.

**Acceptance Scenarios**:

1. **Given** a running slideshow, **When** the user opens Settings, **Then** a Connection section and
   an MQTT/broker section are both present as collapsible sections in the same screen.
2. **Given** the Settings screen, **When** the user expands the MQTT section, **Then** they can edit
   and save broker host/port/username/password with the same behavior as today (credentials to
   Keychain, "password is set" hint, change/remove), without opening the reset dialog.
3. **Given** the Settings screen, **When** the user expands the Connection section and changes the URL
   or API key and saves, **Then** the change is validated before persisting and applied to the running
   slideshow without re-onboarding, and the stored key is never shown (009 behavior preserved).
4. **Given** the "Reset configuration?" confirmation dialog, **When** it is shown, **Then** it no
   longer offers broker setup — its only actions are reset and cancel.
5. **Given** the advanced sections (Connection, MQTT), **When** Settings first opens, **Then** they
   default to collapsed so the calm/simple default is preserved.

---

### User Story 3 - Every settings section is reachable (Priority: P3)

The user can scroll the Settings screen to reach every section, including the newly folded-in
Connection and MQTT sections, regardless of how tall the content is, in both orientations and while
the keyboard is shown. Today the lower part of the screen is reportedly cut off / cannot be scrolled
to ("swallows" the lower sections).

**Why this priority**: Without this, the folded-in sections from US2 may be unreachable, but it is a
distinct, independently testable defect (the screen must scroll) and the lowest-risk slice.

**Independent Test**: On an iPad, open Settings with all sections present and confirm the bottom-most
section can be scrolled into view in both portrait and landscape, and remains reachable when a text
field's keyboard is presented.

**Acceptance Scenarios**:

1. **Given** the Settings screen with all sections present, **When** the user scrolls, **Then** the
   bottom-most section becomes fully visible.
2. **Given** the Settings screen in landscape on iPad, **When** the user scrolls, **Then** no section
   is permanently cut off or unreachable.
3. **Given** a text field in a lower section is focused and the keyboard appears, **When** the user
   scrolls, **Then** the focused field and the actions below it remain reachable.

---

### Edge Cases

- **Unreachable server vs. unauthorized key**: the combined onboarding error must tell these apart so
  the user knows which field to fix.
- **Reserved shared-link seam**: the placeholder for the future optional shared-album-link entry must
  be visibly inert (clearly not yet available) so it does not invite interaction or imply broken
  behavior. No tap performs any action in this feature.
- **Unsaved input across collapse/expand**: collapsing then re-expanding a section while Settings is
  open must not discard text the user has typed but not yet saved.
- **Existing configuration**: opening the Connection section with a configuration already present
  shows the current server URL and a "key is set" indicator (never the key itself).
- **Narrow iPad layouts** (split view / Slide Over): sections remain reachable by scrolling at reduced
  widths.
- **Empty album list after a successful combined connection**: the album step's existing empty-state
  hint is shown (unchanged).

## Requirements *(mandatory)*

### Functional Requirements

**Onboarding screen merge (US1)**

- **FR-001**: First-run onboarding MUST present the server address and the API key on a single combined
  screen with one primary Continue action.
- **FR-002**: The Continue action MUST validate, in a single step, that the server is reachable AND the
  API key is authorized before advancing.
- **FR-003**: On validation failure the combined screen MUST remain open, preserve the entered values,
  and show a clear error that distinguishes an unreachable/invalid server from an unauthorized key.
- **FR-004**: The combined screen MUST show concise helper text for each field: what the server address
  is, and where to create an API key in Immich.
- **FR-005**: The Continue action MUST be unavailable until both the server address and the API key are
  non-empty.
- **FR-006**: After a successful combined connection the user MUST advance to the existing album
  selection step, and completing album selection MUST finish onboarding exactly as today.
- **FR-007**: The API key MUST be stored only in the Keychain — never in UserDefaults, logs, or
  committed files (unchanged from current behavior).
- **FR-008**: The combined screen MUST reserve a visible placement for a future optional "shared album
  link + password" entry, shown as not-yet-available, with no functional behavior in this feature
  (deferred to spec 011).

**Settings fold-in (US2)**

- **FR-009**: The main Settings screen MUST present the Connection configuration (server URL, "key is
  set" indicator, edit/save) as a collapsible section within the screen rather than only as a row that
  opens a separate sheet.
- **FR-010**: The main Settings screen MUST present the MQTT/broker configuration as a collapsible
  section reachable directly from Settings.
- **FR-011**: Broker setup MUST be reachable from the Settings screen; the "Reset configuration?"
  confirmation dialog MUST no longer host broker setup (its only actions are reset and cancel).
- **FR-012**: Editing the connection from the folded-in section MUST preserve 009 behavior: validate
  before persisting, apply to the running slideshow without re-onboarding, and never display the stored
  key.
- **FR-013**: Editing the broker from the folded-in section MUST preserve existing broker behavior:
  credentials stored in the Keychain, a "password is set" hint instead of prefilling the secret, and
  change/remove support.
- **FR-014**: The advanced sections (Connection, MQTT) MUST default to collapsed when Settings opens,
  preserving the calm/simple default; brightness and display options remain directly visible.

**Scroll fix (US3)**

- **FR-015**: Every Settings section MUST be reachable by scrolling on iPadOS regardless of total
  content height — no section may be cut off or unreachable.
- **FR-016**: Settings sections MUST remain reachable by scrolling in both portrait and landscape, at
  reduced (split-view) widths, and while a text-field keyboard is presented.

**Cross-cutting**

- **FR-017**: TLS validation MUST NOT be disabled anywhere in these flows.
- **FR-018**: This feature MUST NOT add any new Immich REST endpoints or change the data source; it
  reuses existing onboarding, connection, and broker capabilities.

### Key Entities

No new data entities. The feature re-presents existing configuration: the Immich connection (server
URL + API key, key in Keychain), the selected album, and the MQTT broker settings (host/port/username,
password in Keychain).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new user can enter the server address and API key and reach album selection from a
  single screen with one Continue action — one fewer screen than today (two pre-album screens → one).
- **SC-002**: From a running slideshow, a user can reach and open MQTT/broker setup in at most two taps
  from Settings, with no path through the reset dialog.
- **SC-003**: 100% of Settings sections are reachable by scrolling on iPad in both portrait and
  landscape, including with the keyboard presented.
- **SC-004**: Connection and MQTT can each be edited and saved entirely within the Settings screen,
  with no full-screen detour and no re-onboarding.
- **SC-005**: No regression in existing behavior: onboarding connection validation, live connection
  change (009), and broker change/remove all continue to pass.
- **SC-006**: The combined onboarding screen surfaces a distinct error for an unreachable server versus
  an unauthorized key in 100% of those two failure cases.

## Assumptions

- The album selection step remains a separate, unchanged step after the combined connection screen.
- The shared-album-link entry is a **visual placeholder only** in this feature; its behavior (entering
  a link + password to access a shared album) is deferred to spec 011.
- The feature reuses the existing onboarding validation (002), the connection editor and live-reconnect
  plumbing (009), and the broker settings store (006); no new Immich endpoints are introduced.
- Advanced configuration sections default to collapsed, consistent with the project's calm/simple
  default principle; brightness and display options stay directly visible.
- The combined onboarding screen requires both the server address and the API key to be present before
  validation runs (a single connection is established, not two independent steps).
- Existing test seams (`--uitest*` launch arguments, in-memory broker store) remain the way UI flows
  are exercised without touching the real Keychain or a live server.
