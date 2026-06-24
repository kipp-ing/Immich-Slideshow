---
description: "Task list for Source Library (120) implementation"
---

# Tasks: Source Library (multiple switchable slideshow sources)

**Input**: Design documents in `specs/120-source-library/` (plan.md, spec.md, research.md,
data-model.md, contracts/source-library.md, quickstart.md)

**Tests**: REQUIRED — Constitution I (Test-First, NON-NEGOTIABLE). Every implementation task is
preceded by a red Swift Testing (host) or XCUITest task; no code before a demonstrably red test.

**Organization**: by user story (US1–US4 from spec.md). Setup + Foundational are shared prerequisites.

## Progress (2026-06-24) — branch `feat/120-source-library`

- **Done & verified**: T001–T013 (Setup + all Foundational + US1 ActiveSourceResolver). OnboardingKit
  49 tests + ImmichClient 34 tests green on host; app builds via XcodeBuildMCP. Plus an off-task
  integration fix: new shared-link `ImmichError` cases mapped in OnboardingKit (`2ec4365`).
- **Resume here → T014** (US1 app wiring in `Immich_SlideshowApp`, inline/SwiftUI + simulator).
- Remaining: T014–T016 (US1 wiring), T017–T022 (US2 UI, inline), T023–T026 (US3 HA, Codex+wiring),
  T027–T029 (US4 persistence/secret gate, Codex), T030–T033 (polish). Then the carried-over 300/500
  items (clock-overlay renderer, disk cache, auto-retry, periodic refresh).

## Format: `[ID] [P?] [Story] Description with file path`

- **[P]**: parallelizable (different files, no dependency on an incomplete task)
- Delegation: logic phases (Setup/Foundational/US1/US3/US4 logic) → **Codex** (host `swift test`).
  SwiftUI/onboarding/Settings (US2) and all simulator/XCUITest verification → **Claude inline**.

---

## Phase 1: Setup

- [ ] T001 Establish a green host baseline: run `swift test` for `ImmichClient`, `OnboardingKit`,
  `HAControlKit` before any change; record the passing baseline.

---

## Phase 2: Foundational (blocking — required by all stories)

**Source model + persistence + secrets + auth/transport. Complete before US1–US4.**

- [ ] T002 [P] Red tests for `Source`/`SourceKind` + `SourceLibrary` operations (add → first becomes
  active; `setActive`; `remove(active)` promotes next else nil; `move`; `rename`; unique-label
  enforcement; single-active invariant) in `Packages/OnboardingKit/Tests/OnboardingKitTests/SourceLibraryTests.swift`
- [ ] T003 Implement `Source.swift` + `SourceLibrary.swift` in
  `Packages/OnboardingKit/Sources/OnboardingKit/` to green T002
- [ ] T004 [P] Red tests for `UserDefaultsSourceLibraryStore`: round-trip save/load of a mixed
  library; migration from legacy `immich.selectedAlbumID` (absent library → one-entry album library,
  active) in `Packages/OnboardingKit/Tests/OnboardingKitTests/SourceLibraryStoreTests.swift`
- [ ] T005 Implement `SourceLibraryStore.swift` (protocol + `UserDefaultsSourceLibraryStore` + migration
  + in-memory fake) in `Packages/OnboardingKit/Sources/OnboardingKit/` to green T004
- [ ] T006 [P] Red tests for `SharedLinkSecretStore` (per-source password save/read/delete; deleting a
  source deletes its password) in `Packages/OnboardingKit/Tests/OnboardingKitTests/SharedLinkSecretStoreTests.swift`
- [ ] T007 Implement `SharedLinkSecretStore.swift` (protocol + Keychain impl + in-memory fake) in
  `Packages/OnboardingKit/Sources/OnboardingKit/` to green T006
- [ ] T008 [P] Red tests for `ServerConfig.Auth`: `ImmichClient` sets the `x-api-key` header (no
  `key=` query) for `.apiKey`, and appends `key=<token>` (no header) for `.shareKey`, on album/asset
  requests, in `Packages/ImmichClient/Tests/ImmichClientTests/AuthModeTests.swift`
- [ ] T009 Implement `ServerConfig.Auth` (`.apiKey`/`.shareKey`, keep an `apiKey:` convenience init)
  + request-building branch in `Packages/ImmichClient/Sources/ImmichClient/ServerConfig.swift` and
  `ImmichClient.swift` to green T008
- [ ] T010 [P] Red tests for shared-link resolve mapping (200 → `(key, albumID, expiresAt)`; 401+pw →
  `wrongPassword`; 401 no-pw → `passwordRequired`; unknown/expired → `invalidShareLink`/
  `shareLinkExpired`; transport fail → `unreachable`; `me` response never logged) with a stub
  transport in `Packages/ImmichClient/Tests/ImmichClientTests/SharedLinkResolverTests.swift`
- [ ] T011 Implement `SharedLinkResolver.swift` + new `ImmichError` cases in
  `Packages/ImmichClient/Sources/ImmichClient/` to green T010

**Checkpoint**: model, store+migration, secret store, dual-auth client, and resolver are green on host.

---

## Phase 3: US1 — Save several sources and switch the active one (P1) 🎯 MVP

**Goal**: the active source (album or shared link) feeds the engine; switching swaps the show.
**Independent test**: seed a 2-source library (album + shared link via stubs); only the active
source's photos show; switching active swaps to the other source's photos.

- [ ] T012 [P] [US1] Red tests for `ActiveSourceResolver`: `.album` → `(ServerConfig.apiKey, albumID)`;
  `.sharedLink` → resolve (stub) → `(ServerConfig.shareKey(key), resolvedAlbumID)`; resolve failure
  surfaces the typed error, in `Packages/OnboardingKit/Tests/OnboardingKitTests/ActiveSourceResolverTests.swift`
- [ ] T013 [US1] Implement `ActiveSourceResolver` (Source + Keychain API key + `SharedLinkSecretStore`
  + `SharedLinkResolving` → `ServerConfig` + albumID) in `Packages/OnboardingKit/Sources/OnboardingKit/`
  to green T012
- [ ] T014 [US1] Wire `Immich_SlideshowApp` factories (`makeSlideshow`, `makeAPI`) to build the
  `ImmichClient` + albumID from the **active source** via `ActiveSourceResolver` instead of
  `selectedAlbumID`, in `Immich Slideshow/Immich_SlideshowApp.swift`
- [ ] T015 [US1] Implement source switching at the app level: switching the active source persists it
  and restarts the slideshow from it — `switchAlbum(albumID)` when only the album changes, full
  slideshow rebuild (existing `connectionGeneration` path) when the client/auth changes (album↔link),
  in `Immich Slideshow/Immich_SlideshowApp.swift` (+ `RootView`)
- [ ] T016 [US1] Verify via XcodeBuildMCP/XCUITest (`--uitest`): hermetic 2-source library switches in
  the running slideshow (extend the UI-test seam + `SlideshowChromeUITests`/a new test)

**Checkpoint**: MVP — sources switchable in-app, only the active source plays.

---

## Phase 4: US2 — Add the first source in onboarding, manage in Settings (P1)

**Goal**: add/manage sources from onboarding + Settings (the `200` surface). **Claude inline (SwiftUI)**.
**Independent test**: onboarding adds a first source and completes; Settings adds a second, switches,
removes; confirmation lists the library with the active one marked.

- [ ] T017 [P] [US2] Red XCUITest: onboarding "add source" (album pick or shared-link form) → confirm
  → slideshow runs the chosen source, in `Immich SlideshowUITests/SourceOnboardingUITests.swift`
- [ ] T018 [P] [US2] Red XCUITest: Settings → Sources manager adds a second source, switches active,
  removes one; running slideshow swaps on switch, in `Immich SlideshowUITests/SourceLibraryUITests.swift`
- [ ] T019 [US2] Build the onboarding add-source step (album picker reusing `AlbumBrowserView`, or a
  shared-link URL+password form) in `Immich Slideshow/Onboarding/SourceStepView.swift` (+ wire into
  `OnboardingFlowView`)
- [ ] T020 [US2] Build the Settings **Sources** manager (list + add/remove/reorder/rename/set-active,
  unique-label enforced) in `Immich Slideshow/Slideshow/SourceLibraryView.swift` and surface it in
  `Immich Slideshow/Slideshow/SlideshowSettingsView.swift`
- [ ] T021 [US2] Make the onboarding confirmation list the library and mark the active source
- [ ] T022 [US2] Green T017/T018 via XcodeBuildMCP/XCUITest; screenshot portrait + landscape

**Checkpoint**: full source management from onboarding + Settings.

---

## Phase 5: US3 — Switch the active source from Home Assistant (P2)

**Goal**: the existing HA select lists the saved sources; selecting switches the active source.
**Independent test (mock transport)**: discovery `options` == source labels; known label switches +
echoes; unknown label = no-op echo.

- [ ] T023 [P] [US3] Red tests: `SlideshowRemoteControlAdapter` backed by a 2-source `SourceLibrary`
  → `albumOptions` == labels; `selectAlbum(label)` switches active + `currentAlbum` echoes; unknown
  label no-op, in `Immich SlideshowUITests`/a host test, or `Packages/HAControlKit/Tests/HAControlKitTests/`
  (adapter lives in the app target — place the adapter test where it compiles, mirroring the existing
  adapter tests)
- [ ] T024 [US3] Back `SlideshowRemoteControlAdapter` with the `SourceLibrary` + `ActiveSourceResolver`
  (options/current/select over source labels; select switches active source) in
  `Immich Slideshow/Slideshow/SlideshowRemoteControlAdapter.swift`
- [ ] T025 [US3] Wire `Immich_SlideshowApp.makeCoordinator` to pass the library to the adapter instead
  of the server album list, in `Immich Slideshow/Immich_SlideshowApp.swift` (HA entity key `album`
  stays stable; options now = source labels — research D5)
- [ ] T026 [US3] Verify HA select round-trip with the mock transport (extend the coordinator tests in
  `Packages/HAControlKit/Tests/HAControlKitTests/`)

**Checkpoint**: HA switches the active source.

---

## Phase 6: US4 — Migrate and persist transparently (P2)

**Goal**: legacy single-album installs migrate; library + active survive relaunch; secrets stay in
Keychain. (Migration logic is built in T004/T005; this phase is the end-to-end + secret-hygiene gate.)
**Independent test**: legacy `selectedAlbumID` → one-entry active library; relaunch restores; no
password/bearer key in UserDefaults/logs.

- [ ] T027 [P] [US4] Red test: end-to-end relaunch — save a mixed library (incl. a password-protected
  shared link), reload via a fresh store instance → sources + active restored; password only via the
  secret store, in `Packages/OnboardingKit/Tests/OnboardingKitTests/SourceLibraryPersistenceTests.swift`
- [ ] T028 [P] [US4] Red test: secret hygiene — dump the UserDefaults suite + the encoded library JSON
  and assert no password and no bearer key appear, in the same persistence test file
- [ ] T029 [US4] Make T027/T028 green (adjust store/secret handling as needed); confirm migration leaves
  the legacy key harmless and unread once a library exists

**Checkpoint**: persistence + migration + secret hygiene proven.

---

## Phase 7: Polish & Cross-Cutting

- [ ] T030 [P] Update `specs/200-connection-onboarding/spec.md` and `specs/700-ha-control/spec.md`:
  move the now-built source management / source-select from Roadmap to Active (FR IDs), and reconcile
  `docs/spec-overview.md`
- [ ] T031 Run the **full XCUITest** suite via XcodeBuildMCP (`test_sim`) — green before merge
- [ ] T032 Secret grep over the test suite + a manual log check (no password/bearer key in logs);
  manual end-to-end with the real links (`geo2026`, `korsika2026`/`12345678`)
- [ ] T033 [P] Update `CHANGELOG`/engineering notes if applicable; ensure new files build in the app
  target (synchronized groups — no pbxproj edit)

---

## Dependencies & order

- **Setup (P1)** → **Foundational (P2)** → stories.
- **US1 (P3)** depends on Foundational; it is the MVP.
- **US2 (P4)** depends on US1 (needs the active-source wiring + switch).
- **US3 (P5)** depends on Foundational (library + resolver); independent of US2.
- **US4 (P6)** depends on Foundational (store + migration + secrets); independent of US2/US3.
- **Polish (P7)** last.

## Parallel opportunities

- Within Foundational: T002/T004/T006/T008/T010 (red tests, different files) run in parallel; each
  impl task follows its own red test.
- US3 and US4 can proceed in parallel once Foundational is green.
- US2 is the only inline (SwiftUI) story; it can be built while US3/US4 logic is delegated to Codex.

## Implementation strategy (incremental delivery)

1. **MVP = Setup + Foundational + US1** — sources switchable in-app, only the active source plays.
2. Add **US2** (UI) so users can actually add/manage sources.
3. Add **US3** (HA) and **US4** (migration/persistence gate) — parallelizable.
4. **Polish** — spec reconciliation, full XCUITest, secret check, real-link end-to-end.
