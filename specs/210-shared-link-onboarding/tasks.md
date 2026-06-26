---
description: "Task list for Shared-Link Onboarding & iOS Share Sheet (210) implementation"
---

# Tasks: Shared-Link Onboarding & iOS Share Sheet

**Input**: Design documents in `specs/210-shared-link-onboarding/` (plan.md, spec.md, research.md,
data-model.md, contracts/shared-link-onboarding.md, quickstart.md)

**Tests**: REQUIRED — Constitution I (Test-First, NON-NEGOTIABLE). Every implementation task is
preceded by a red Swift Testing (host) or XCUITest task; no code before a demonstrably red test.

**Organization**: by user story (US1–US5 from spec.md). Setup + Foundational are shared prerequisites.

**Orchestration note**: per `CLAUDE.md`, pure/host logic (gate, resolve state machine, search
predicate, router, stores, URL extraction) is Codex-delegable; SwiftUI surfaces, the app entry point,
onboarding wiring, the Share Extension target + App Group entitlement, and signing are **keep-inline**.

## Path Conventions

- Packages: `Packages/<Pkg>/Sources/...`, host tests `Packages/<Pkg>/Tests/...` (`swift test`).
- App: `Immich Slideshow/...`; UI tests `Immich SlideshowUITests/...` (XcodeBuildMCP + XCUITest).
- New extension target: `Immich SlideshowShareExtension/...`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Album metadata needed by US2 (default labels) and US3 (search).

- [X] T001 [P] Red test: `Album` decodes `assetCount`/`startDate`/`endDate` from `GET /api/albums` and tolerates their absence (older servers / shared-link album ref) in `Packages/ImmichClient/Tests/ImmichClientTests/AlbumMetadataTests.swift`
- [X] T002 [P] Implement back-compatible `Album` metadata (`assetCount: Int?`, `startDate`/`endDate: Date?`, retain `init(id:name:)` + add CodingKeys) in `Packages/ImmichClient/Sources/ImmichClient/Models.swift`
- [ ] T003 Confirm `assetCount`/`startDate`/`endDate`/`createdAt` field names against the running server's OpenAPI (`/api/server/version`) and adjust decode keys (FR-210-25) — **blocked: needs live server**; implemented against the documented Immich `AlbumResponseDto` (`assetCount`, ISO8601 `startDate`/`endDate`)

**Checkpoint**: Album list carries metadata; existing `albums()` callers unchanged.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The shared entry-routing + the resolve-first/ask-password-only-when-needed engine reused
by US1, US2, and US4.

**⚠️ CRITICAL**: US1/US2/US4 cannot begin until this phase is complete. (US3/US5 are independent.)

- [X] T004 Red test: `OnboardingStep.choice` exists and `StartupGate` routes shared-link active ⇒ `.done` (no API key), album active ⇒ `.done` only with key+baseURL else `.connection`, no source+key+baseURL ⇒ `.source`, empty ⇒ `.choice`, legacy `selectedAlbumID` still ⇒ `.done`, in `Packages/OnboardingKit/Tests/OnboardingKitTests/StartupGateTests.swift`
- [X] T005 Implement `OnboardingStep.choice` + relaxed `StartupGate.initialStep()` in `Packages/OnboardingKit/Sources/OnboardingKit/OnboardingStep.swift` and `StartupGate.swift`
- [X] T006 Red test: two-phase resolve state machine — `resolveSharedLink` (HTTPS-only guard; no network on malformed) → `.resolved` (200) / `.needsPassword` (401 no-pw) / `.error` (else, nothing persisted); `confirmSharedLinkPassword` → saved + password to Keychain (200) / `.error(wrongPassword)` (401, nothing persisted); dedup by `(baseURL,slug)`, in `Packages/OnboardingKit/Tests/OnboardingKitTests/SourceLibraryViewModelTests.swift`
- [X] T007 Implement `SharedLinkAddState` + `resolveSharedLink`/`confirmSharedLinkPassword` + `(baseURL,slug)` dedup in `Packages/OnboardingKit/Sources/OnboardingKit/SourceLibraryViewModel.swift` (added alongside `addSharedLinkSource`; the password-upfront method is removed in US4/T031–T032 once its callers migrate)

**Checkpoint**: Entry routing + the shared resolve engine are green on the host.

---

## Phase 3: User Story 1 - Shared-link-only onboarding (Priority: P1) 🎯 MVP

**Goal**: A user with only a shared link reaches the slideshow with no API key; password asked only if required.

**Independent Test**: From no config, choose the shared-link path, enter a link, and reach the slideshow with no API key stored; a protected link prompts once; an invalid link errors with nothing persisted.

- [X] T008 [P] [US1] Red test: `OnboardingViewModel` choice routing (shared-link choice → shared-link path; server choice → `.connection`) and shared-link `finish` makes a shared-link the active source with no API key, in `Packages/OnboardingKit/Tests/OnboardingKitTests/OnboardingViewModelTests.swift`
- [X] T009 [US1] Implement choice routing + shared-link-only completion in `Packages/OnboardingKit/Sources/OnboardingKit/OnboardingViewModel.swift`
- [X] T010 [US1] Build `OnboardingChoiceView` (two labeled options + one-line descriptions) in `Immich Slideshow/Onboarding/OnboardingChoiceView.swift`
- [X] T011 [US1] Build `SharedLinkSetupView` (link field → resolve → password sheet only on `.needsPassword` → start) using the Phase-2 engine, in `Immich Slideshow/Onboarding/SharedLinkSetupView.swift`
- [X] T012 [US1] Wire `.choice` into `OnboardingFlowView` and app routing; add `--uitest-onboarding-choice` + `--uitest-shared-link-only` seams in `Immich Slideshow/Onboarding/OnboardingFlowView.swift` and `Immich Slideshow/Immich_SlideshowApp.swift`
- [X] T013 [US1] XCUITest: choice → non-protected link → slideshow (no API key); protected link → one prompt → slideshow; malformed/invalid link → classified error, nothing persisted, in `Immich SlideshowUITests/SharedLinkOnboardingUITests.swift` — 3 tests green
- [X] T014 [US1] Screenshot-verify choice + shared-link setup screens (portrait + landscape) via XcodeBuildMCP — **portrait screenshots captured & verified (both screens on-spec)**; landscape verified via the `XCUIDevice.orientation` test (`testSharedLinkOnlyChoiceReachesSlideshowInLandscape`, **green**) since MCP menu-rotate didn't re-layout the app

**Checkpoint**: US1 fully functional and independently testable — the MVP.

---

## Phase 4: User Story 2 - iOS Share Sheet (Priority: P1)

**Goal**: Share an Immich link into the app; it pre-fills setup (unconfigured) or adds+activates (configured), asking for a password only if needed.

**Independent Test**: Inject a pending link via the App-Group fake; unconfigured pre-fills setup, configured adds+activates, a duplicate switches, an invalid link errors — all without the system Share Sheet.

- [X] T015 [P] [US2] Red test: `PendingSharedLinkStore` save → take-once → `nil`; only the URL is stored; missing App Group degrades to `nil`, in `Packages/OnboardingKit/Tests/OnboardingKitTests/PendingSharedLinkStoreTests.swift`
- [X] T016 [US2] Implement `PendingSharedLinkStore` protocol + App-Group `UserDefaults` impl + in-memory fake in `Packages/OnboardingKit/Sources/OnboardingKit/PendingSharedLinkStore.swift`
- [X] T017 [P] [US2] Red test: `IncomingSharedLink.route` — unconfigured → `.prefillOnboarding`; configured+existing `(baseURL,slug)` → `.switchToExisting`; configured+new → `.addAndActivate`; unparseable → `.invalid`, in `Packages/OnboardingKit/Tests/OnboardingKitTests/IncomingSharedLinkTests.swift`
- [X] T018 [US2] Implement pure `IncomingSharedLink` router in `Packages/OnboardingKit/Sources/OnboardingKit/IncomingSharedLink.swift`
- [X] T019 [P] [US2] Red test: `ShareLinkExtraction.url(from:)` extracts a URL from synthetic extension item providers (and returns `nil` for non-URL content), in `Packages/OnboardingKit/Tests/OnboardingKitTests/ShareLinkExtractionTests.swift`
- [X] T020 [US2] Implement pure `ShareLinkExtraction` helper (in OnboardingKit so it stays host-testable; the extension links it) in `Packages/OnboardingKit/Sources/OnboardingKit/ShareLinkExtraction.swift`
- [ ] T021 [US2] Add the Share Extension target + App Group entitlement (host + extension), `NSExtensionActivationRule` accepting exactly one `public.url`, and the `immichslideshow://` hand-off scheme in `Immich Slideshow.xcodeproj/project.pbxproj`, `Immich SlideshowShareExtension/Info.plist`, and entitlement files **(keep-inline: signing/pbxproj)**
- [ ] T022 [US2] Implement `ShareViewController` (extract URL via `ShareLinkExtraction` → `savePendingURL` → open the host scheme → complete) in `Immich SlideshowShareExtension/ShareViewController.swift`
- [ ] T023 [US2] Host: consume the pending link on launch/`scenePhase == .active` (and `onOpenURL`) → `IncomingSharedLink` → resolve+add/activate or prefill onboarding (password only if required); add `--uitest-pending-link` seam, in `Immich Slideshow/Immich_SlideshowApp.swift` **(keep-inline: app entry + onboarding wiring)**
- [ ] T024 [US2] XCUITest: seeded pending link → unconfigured prefills setup; configured adds+activates and playback switches; duplicate switches without a new source; invalid errors, in `Immich SlideshowUITests/ShareSheetIncomingUITests.swift`
- [ ] T025 [US2] Manual human-test: real iOS Share Sheet round trip on device (system sheet not XCUITest-drivable); record in `specs/210-shared-link-onboarding/human-test-findings.md`

**Checkpoint**: US1 and US2 both work independently; the easiest path (share → watch) is live.

---

## Phase 5: User Story 3 - Searchable + subscrollable album picker (Priority: P2)

**Goal**: With 50+ albums, search by name/date/count and keep the primary action pinned.

**Independent Test**: Seed 50+ stub albums; typing narrows by name/date/count; no-match shows an empty state; Continue/Add stays visible while the list scrolls in portrait + landscape.

- [ ] T026 [P] [US3] Red test: `AlbumSearch.filter` — empty query → all (stable order); name/date/count substring match (case/diacritic-insensitive); `nil` date/count tolerated, in `Packages/OnboardingKit/Tests/OnboardingKitTests/AlbumSearchTests.swift`
- [ ] T027 [US3] Implement pure `AlbumSearch.filter` predicate in `Packages/OnboardingKit/Sources/OnboardingKit/AlbumSearch.swift`
- [ ] T028 [US3] Redesign the onboarding album picker: search field + independently scrollable list + pinned Continue/Add (`safeAreaInset(edge: .bottom)`) + name/date·count subtitle + no-results state, in `Immich Slideshow/Onboarding/SourceStepView.swift`
- [ ] T029 [US3] Ensure the picker receives album metadata (count/date) and add the `--uitest-albums-many` seam (50+ stub albums with date/count) in `Immich Slideshow/Immich_SlideshowApp.swift`
- [ ] T030 [US3] XCUITest + screenshot: 50+ albums — search narrows, no-results state shows, action stays pinned (portrait + landscape), in `Immich SlideshowUITests/AlbumSearchUITests.swift`

**Checkpoint**: Album selection is usable at 50+ albums.

---

## Phase 6: User Story 4 - Ask-password-only-when-needed everywhere (Priority: P2)

**Goal**: Remove the always-on optional-password field; resolve first and prompt only when required, in onboarding and Settings.

**Independent Test**: In both the onboarding source step and Settings → Sources, a non-protected link saves with no password field; a protected link prompts once; a wrong password is a distinct error with nothing persisted.

- [ ] T031 [US4] Replace the always-on optional-password field in the onboarding source step's shared-link section with the Phase-2 two-phase flow, in `Immich Slideshow/Onboarding/SourceStepView.swift`
- [ ] T032 [US4] Replace the always-on optional-password field in Settings → Sources add-shared-link with the same flow, in `Immich Slideshow/Slideshow/SourceLibraryView.swift`
- [ ] T033 [US4] XCUITest: both surfaces — non-protected saves with no password field; protected prompts once; wrong password distinct error, nothing persisted, in `Immich SlideshowUITests/SharedLinkPasswordUITests.swift`

**Checkpoint**: One consistent, low-friction add-link behavior across the app.

---

## Phase 7: User Story 5 - Onboarding step descriptions (Priority: P3)

**Goal**: Every onboarding screen shows concise helper text.

**Independent Test**: Each onboarding screen (choice, shared-link setup, connection, album, confirm) shows a short, accurate description.

- [ ] T034 [US5] Add concise helper text to each onboarding screen in `Immich Slideshow/Onboarding/OnboardingChoiceView.swift`, `SharedLinkSetupView.swift`, `ConnectionStepView.swift`, `SourceStepView.swift`, and the confirm step
- [ ] T035 [US5] XCUITest/screenshot: each onboarding screen shows description text, in `Immich SlideshowUITests/OnboardingDescriptionsUITests.swift`

**Checkpoint**: First-time users are guided on every screen.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [ ] T036 [P] Secret-hygiene check: grep that no password/API key reaches UserDefaults, the App Group container, or logs; confirm only the URL crosses the boundary (SC-210-06, Constitution III)
- [ ] T037 [P] Update `docs/spec-overview.md` and cross-reference 200/120 to 210 (move shared-link-only + Share-Sheet items from Roadmap → Active where applicable)
- [ ] T038 Run the full XCUITest suite green via XcodeBuildMCP before merge (project rule)
- [ ] T039 Run `quickstart.md` scenarios A–F; record the Share Sheet human-test outcome in `human-test-findings.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies.
- **Foundational (Phase 2)**: depends on Setup (Album metadata used by labels); BLOCKS US1/US2/US4.
- **US1 (Phase 3)**: after Foundational. MVP.
- **US2 (Phase 4)**: after Foundational; reuses US1's `SharedLinkSetupView` for the unconfigured prefill (T023 → T011).
- **US3 (Phase 5)**: after Setup only (needs Album metadata); independent of the resolve engine.
- **US4 (Phase 6)**: after Foundational; UI wiring over the Phase-2 engine.
- **US5 (Phase 7)**: after the screens it annotates exist (US1 screens; ConnectionStep/SourceStep already exist).
- **Polish (Phase 8)**: after the desired stories are complete.

### Within Each Story

- Red test before implementation (Constitution I). Models/types before view models before views.
- Host logic (Codex-delegable) before SwiftUI wiring (keep-inline).

### Parallel Opportunities

- T001/T002 (Album) in parallel with T004/T005 (gate) — different files.
- Within US2, the pure pieces T015/T017/T019 (tests) and T016/T018/T020 (impls) parallelize before the
  target/UI work (T021–T024) which is sequential and inline.
- US3 (T026–T030) can run in parallel with US1/US2 once Setup is done (separate files).

---

## Implementation Strategy

### MVP First (US1)

1. Phase 1 Setup → 2. Phase 2 Foundational → 3. Phase 3 US1 → **STOP & validate** (shared-link-only
   onboarding reaches the slideshow with no API key). Demo.

### Incremental Delivery

1. Setup + Foundational → foundation ready.
2. US1 (shared-link-only onboarding) → MVP.
3. US2 (Share Sheet) → the "share → watch" easiest path.
4. US3 (searchable picker) → scales the server path.
5. US4 (ask-pw-when-needed) → consistency polish.
6. US5 (descriptions) → guidance polish.
7. Polish → secret grep, docs, full UITest, human-test.

### Notes

- Commit after each task or logical group; keep the Share Extension thin (URL only — Constitution III).
- The Share Extension target + App Group + signing (T021) and the host consumption wiring (T023) are
  keep-inline per `CLAUDE.md`; the pure logic around them is Codex-delegable.
- A real-device Share Sheet pass (T025) and the full XCUITest run (T038) gate the merge.
