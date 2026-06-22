# Feature Specification: Shared Album Link (link + password)

**Feature Branch**: `011-shared-album-link`

**Created**: 2026-06-22

**Status**: Deferred (Backlog) — captured now, not scheduled for implementation

**Input**: User description: "Allow using an Immich **shared album link** (a public/shared link, with an
optional password) as a slideshow source, in addition to the API-key + album path. The user can paste
a shared link and its password during onboarding (on the combined connection screen) and/or from
Settings, and the slideshow plays the photos from that shared album."

> **Status note**: This is a **new capability**, not a UI tweak. Unlike spec 010 (UX consolidation),
> it requires new Immich data-source support: shared/public links are accessed through a different
> mechanism than the authenticated `x-api-key` album path that exists today. It is **deferred** by
> decision on 2026-06-22 — recorded so the reserved seam in spec 010 has a home, but **not to be
> implemented** until explicitly scheduled. Treat the sections below as a first-pass outline to be
> refined (via `/speckit-clarify`) when the feature is picked up.

## Why this is separate from 010

- **010 (UX consolidation)** rearranges *existing* configuration: it merges onboarding steps, folds
  Connection/MQTT into Settings, and fixes scrolling. No new data source.
- **011 (this spec)** adds a *new data source*: an Immich shared link. That means new client/API work
  and a new way to store "this slideshow comes from a shared link (+ password)" rather than from an
  API key + album ID. Keeping it separate preserves a clean test-first boundary for the API work.
- Spec 010 only reserves a **visible, inert placeholder** for the shared-link entry; 011 makes it real.

## User Scenarios & Testing *(mandatory)* — DRAFT

### User Story 1 - Use a shared album link as the slideshow source (Priority: P1) 🎯 MVP

A user who was given an Immich shared album link (and, if the link is protected, its password) pastes
the link and password, and the app plays that album as a slideshow — without needing a personal API
key for that album.

**Why this priority**: It is the entire point of the feature — a second, simpler way to point the
slideshow at photos, useful for guests or shared family albums.

**Independent Test** (to be refined): With a mocked shared-link data source, paste a valid shared link
and correct password and confirm the album's photos load into the slideshow; paste a wrong password
and confirm a clear "password required/incorrect" error with nothing persisted.

**Acceptance Scenarios** (draft):

1. **Given** a valid shared link with no password, **When** the user submits it, **Then** the linked
   album's photos load as the slideshow source.
2. **Given** a valid shared link that is password-protected, **When** the user submits the link with
   the correct password, **Then** the album loads; with an incorrect/missing password, **Then** a
   clear error is shown and nothing is persisted.
3. **Given** a shared link is in use, **When** the app relaunches, **Then** the shared-link source is
   restored (the password is treated as a secret — see open questions).

### User Story 2 - Manage the shared-link source from Settings (Priority: P2)

The user can review, change, or remove the shared-link source from the Settings screen (reusing the
folded-in Connection area introduced in 010).

---

### Edge Cases (draft — to expand during clarify)

- Expired or revoked shared link → clear, distinct error.
- Shared link points to an empty album → existing empty-state hint.
- Link with embedded key vs. link requiring a separate password → both forms handled.
- Switching between an API-key album source and a shared-link source.

## Requirements *(mandatory)* — DRAFT

### Functional Requirements (draft)

- **FR-001**: The app MUST accept an Immich shared album link as a slideshow data source.
- **FR-002**: The app MUST accept an optional password for a protected shared link and use it to access
  the album.
- **FR-003**: A shared-link password MUST be treated as a secret — stored only in the Keychain, never
  in UserDefaults, logs, or committed files. *(Open question: confirm the password is a secret vs. a
  shareable token; see below.)*
- **FR-004**: TLS validation MUST NOT be disabled for shared-link access.
- **FR-005**: The app MUST validate a shared link (and password, if required) before persisting it, and
  surface distinct errors for: invalid/expired link vs. missing/incorrect password vs. unreachable.
- **FR-006**: The shared-link entry MUST be reachable from the combined onboarding screen (filling the
  seam reserved in spec 010) and from Settings.
- **FR-007**: API paths for shared-link access MUST be verified against the OpenAPI spec of the running
  Immich version (Constitution / CLAUDE.md), not assumed from tutorials.

### Key Entities (draft)

- **Shared link source**: the link (URL / share key) and an optional password (secret), as an
  alternative to the API-key + album-ID source. One active source at a time.

## Success Criteria *(mandatory)* — DRAFT

- **SC-001**: A user with only a shared link (+ password) can start a slideshow without creating a
  personal API key.
- **SC-002**: Wrong/missing passwords and expired links each produce a distinct, understandable error.
- **SC-003**: The shared-link source and its secret survive an app relaunch with the password never
  displayed.

## Open Questions (resolve via `/speckit-clarify` before planning)

1. **Immich mechanism**: which exact Immich endpoint(s) back shared/public links in the running server
   version, and how is the password supplied (header, query `key`, separate auth)? Verify against
   `/api/server/version` + OpenAPI.
2. **Secret classification**: is the shared-link password a true secret (Keychain) or a shareable
   token? FR-003 currently assumes secret.
3. **Coexistence**: can a shared-link source and an API-key + album source both be configured, or is it
   strictly one-at-a-time? Draft assumes one active source.
4. **Onboarding path**: is shared-link an alternative to the API-key path (skip API key) or an addition
   alongside it on the combined screen?

## Assumptions (draft)

- Depends on spec 010 having shipped the combined onboarding screen with the reserved shared-link seam
  and the folded-in Settings Connection area.
- Requires new `ImmichClient` support for shared-link access; this is the main reason the feature is
  its own spec.
- One active slideshow source at a time (API-key album OR shared link), pending clarification.
