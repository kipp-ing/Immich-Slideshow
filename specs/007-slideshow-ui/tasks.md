# Tasks: Slideshow UI (native iPadOS 26 chrome, Liquid Glass)

**Input**: Design documents from `/specs/007-slideshow-ui/`

**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓

**Tests**: TDD is mandatory (Constitution I) → logic tests (host) before impl, red first; UI via XCUITest.

**Organization**: Grouped by user story (= shipped slices A–D); each story independently shippable.

**Status**: Documented retroactively — all tasks are **done** [X]. The parentheses reference the
shipping commit. This file backfills the SDD trail for already-shipped code.

## Format: `[ID] [P?] [Story] Description` — commit

- **[P]**: parallelizable (different file). **[Story]**: US1…US4. Paths relative to the repo root.

**Orchestration** (CLAUDE.md): host-testable logic (VM additions in `SlideshowKit`, client endpoints
in `ImmichClient`) suits delegation (`swift test`). **Kept inline by Claude:** the timing/shared state
of the ticker task (pause/resume/jump races), the SwiftUI views + gestures, status-bar wiring, and all
simulator/XCUITest verification.

---

## Phase 1: Setup

- [X] T001 No new packages/schemes — built on 003 (`SlideshowKit`), 001 (`ImmichClient`), 004
  (`PowerKit`). Confirmed the app scheme builds on an iOS 26.x simulator. — `52e4c5e`

**Checkpoint**: Foundation stands; existing packages present.

---

## Phase 2: User Story 1 - Control chrome + gestures (Priority: P1) 🎯 MVP — `52e4c5e`, `df23680`

**Goal**: Reveal-on-tap Liquid Glass chrome (top/bottom) with auto-hide + swipe-to-advance.

**Independent Test**: `--uitest`: no chrome in the default; tap → chrome; idle → gone; swipe → image
changes without chrome; play/pause stops/starts auto-advance.

### Tests for User Story 1 (write first, MUST be red) ⚠️

- [X] T002 [P] [US1] VM tests in `Packages/SlideshowKit/Tests/SlideshowKitTests/SlideshowViewModelTests.swift`:
  `showNextStepsForwardAndResetsTicker`, `showPreviousStepsBackwardAndWraps`,
  `togglePauseStopsTickerAndSurvivesForegroundResume`, `singleImageAlbumRemainsStableOnTick`.
  (FR-004/FR-005/FR-006) — `52e4c5e`
- [X] T003 [P] [US1] XCUITests in `Immich SlideshowUITests/SlideshowChromeUITests.swift`:
  `testChromeHiddenByDefaultAndRevealsOnTap`, `testChromeAutoHidesWhenIdle`,
  `testSwipeAdvancesWithoutRevealingChrome`, `testTransportAndPlayPauseToggle`. — `52e4c5e`

### Implementation for User Story 1

- [X] T004 [US1] VM extension in `…/SlideshowViewModel.swift`: `showNext`/`showPrevious`/`togglePause`,
  `isPaused`, shared `step(by:)`, timer reset (`restartTickerIfPlaying`). — `52e4c5e`
- [X] T005 [US1] `SlideshowChrome.swift` (app target): top bar (exit/info/albums/settings) + transport
  bar (previous/play-pause/next), `glassEffect`/`.buttonStyle(.glass)`, a11y IDs. — `52e4c5e`
- [X] T006 [US1] `SlideshowView.swift`: tap toggle + horizontal `DragGesture`, chrome visibility +
  auto-hide `Task` (~4.5 s), status bar / home indicator follow the chrome. — `52e4c5e`
- [X] T007 [US1] Reset moved to the chrome exit button; redundant long-press removed; UI tests
  stabilized. — `df23680`

**Checkpoint**: US1 — slideshow operable (paging/pause), calm default holds (MVP).

---

## Phase 3: User Story 2 - Album browser sheet (Priority: P2) — `1af7466`

**Goal**: Liquid Glass album browser over the running slideshow; tapping a thumbnail switches source +
jumps to the photo.

**Independent Test**: Chrome → albums → album → thumbnail → fullscreen shows the photo; new album
active if applicable.

### Tests for User Story 2 (write first, MUST be red) ⚠️

- [X] T008 [P] [US2] VM tests in `SlideshowViewModelTests.swift`:
  `jumpGoesToRequestedAssetAndIgnoresUnknown`, `switchAlbumLoadsNewAlbumAndExposesCurrentAlbumID`.
  (FR-008) — `1af7466`
- [X] T009 [P] [US2] Client test in `Packages/ImmichClient/Tests/ImmichClientTests/PreviewTests.swift`:
  `thumbnailSendsGetRequestWithThumbnailSizeQueryAndReturnsRawData`. (FR-009) — `1af7466`
- [X] T010 [P] [US2] XCUITest `Immich SlideshowUITests/AlbumBrowserUITests.swift`:
  `testAlbumBrowserOpensDrillsInAndSelectionReturnsToSlideshow`. — `1af7466`

### Implementation for User Story 2

- [X] T011 [US2] VM: `albumID` mutable, `jump(to:)`, `switchAlbum(_:)` usable from the UI. — `1af7466`
- [X] T012 [US2] `ImmichAPI.thumbnail(assetID:)` + impl in `ImmichClient.swift` (thumbnail size query,
  `x-api-key`). — `1af7466`
- [X] T013 [US2] `AlbumBrowserView.swift` (app target): album grid → `AlbumThumbnailGrid` →
  `ThumbnailCell`; `onSelect(albumID, assetID)`; Liquid Glass cards; loading/empty/error states.
  — `1af7466`
- [X] T014 [US2] `SlideshowView.swift`: wire the albums sheet — on mismatch `switchAlbum`, then
  `jump`. — `1af7466`

**Checkpoint**: US1 + US2 — control and album switching.

---

## Phase 4: User Story 3 - Photo-info overlay (Priority: P3) — `a2c36b1`

**Goal**: Date/location of the current photo from EXIF; quiet when nothing is present.

**Independent Test**: Chrome → info → overlay shows date + location (where EXIF exists); nothing for a
photo without EXIF.

### Tests for User Story 3 (write first, MUST be red) ⚠️

- [X] T015 [P] [US3] Client tests in `Packages/ImmichClient/Tests/ImmichClientTests/AssetInfoTests.swift`:
  `assetInfoSendsGetRequestWithAPIKeyHeaderAndReturnsDecodedInfo`,
  `assetInfoWithoutExifFallsBackToLocalDateTimeAndNilLocation`. (FR-010/FR-011) — `a2c36b1`
- [X] T016 [P] [US3] XCUITest `Immich SlideshowUITests/PhotoInfoUITests.swift`:
  `testInfoButtonTogglesDateAndLocationOverlay`. — `a2c36b1`

### Implementation for User Story 3

- [X] T017 [US3] `AssetInfo` + `AssetDetail`/`ExifInfo` decoding in `ImmichClient/…/Models.swift`.
  — `a2c36b1`
- [X] T018 [US3] `ImmichAPI.assetInfo(assetID:)` + impl (date fallback `localDateTime`/
  `fileCreatedAt`). — `a2c36b1`
- [X] T019 [US3] `PhotoInfoView.swift` (app target): lazy `.task(id: assetID)`, date/location lines,
  renders nothing when empty; Liquid Glass card; wired as an overlay in `SlideshowView`. — `a2c36b1`

**Checkpoint**: US1–US3 — control, albums, photo info.

---

## Phase 5: User Story 4 - Settings shell (Priority: P4) — `b41ed4d`

**Goal**: Settings sheet with live brightness (004); planned options as a disabled preview.

**Independent Test**: Chrome → settings → brightness slider works live; planned options visible but
disabled.

### Tests for User Story 4 (write first, MUST be red) ⚠️

- [X] T020 [P] [US4] XCUITest `Immich SlideshowUITests/SettingsUITests.swift`:
  `testSettingsShowsBrightnessAndPlannedOptionsAndDismisses`. — `b41ed4d`

### Implementation for User Story 4

- [X] T021 [US4] `SlideshowSettingsView.swift` (app target): brightness `Slider` → `PowerManager.
  setBrightness` (live), initial value from the active window scene; disabled placeholder rows
  (duration/transition/Ken Burns/order/image fit/clock) with a hint pointing to ThemeSettings.
  — `b41ed4d`
- [X] T022 [US4] `SlideshowView.swift`: wire the settings sheet from the chrome. — `b41ed4d`

**Checkpoint**: US1–US4 — complete chrome, ThemeSettings-ready.

---

## Phase 6: Polish & Cross-Cutting Concerns — `df23680`

- [X] T023 [P] UI test stabilization (timing/shared state): removed redundant long-press, pinned the
  chrome `--uitest` seams (no auto-hide in tests). — `df23680`
- [X] T024 Full simulator run (`test_sim`, scheme "Immich Slideshow") green; host suites
  (`SlideshowKit`, `ImmichClient`) green via `swift test`.
- [X] T025 Default review (Constitution VII): overlay-free default confirmed — no chrome/clock/status
  bar without a user action (SC-001/SC-007).

---

## Dependencies & Execution Order

- Setup → US1 (P1, MVP) → US2 (P2) → US3 (P3) → US4 (P4) → Polish.
- US1: T002/T003 (red) → T004 (VM) → T005 (chrome) → T006 (gestures/auto-hide) → T007 (reset/stabilize).
- US2: T008–T010 (red) → T011 (VM) → T012 (thumbnail) → T013 (browser) → T014 (wiring). Builds on US1.
- US3: T015/T016 (red) → T017 (model) → T018 (endpoint) → T019 (overlay). The only data/backend slice.
- US4: T020 (red) → T021 (settings) → T022 (wiring). Depends on PowerKit (004); the rest waits on #5.

### Parallel Opportunities

- Per-story test tasks are [P] (different files). The four slices are independently shippable; in
  practice shipped sequentially in priority order.

## Implementation Strategy

Incremental, each slice independently shippable, none breaks the calm default: US1 (MVP: operable) →
US2 (albums) → US3 (info) → US4 (settings shell). Next: specify the ThemeSettings module (#5) that
activates the disabled options from US4.

## Notes

- VM/client logic is host-fast (`swift test`); views via XCUITest on the simulator (no MCP tap tools —
  cf. `docs/testing.md`).
- Album choice is runtime-only (not persisted) — deliberately out of scope (see `data-model.md`).
- No secrets in UI/logs (Constitution III); brightness/idle foreground only (Constitution V).
