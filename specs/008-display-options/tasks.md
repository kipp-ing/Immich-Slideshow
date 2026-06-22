---

description: "Task list for Display & Playback Options (ThemeSettings)"
---

# Tasks: Display & Playback Options (ThemeSettings)

**Input**: Design documents from `/specs/008-display-options/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: REQUIRED — the constitution mandates Test-First (red → green → refactor). Each implementation
task is preceded by a failing Swift Testing test. Package logic runs host-side (`swift test`); UI/visual
behavior is verified in the simulator via XcodeBuildMCP.

**Organization**: Grouped by user story. US1 is the MVP and includes the foundational live-settings
plumbing the other stories reuse.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an incomplete task)
- **[Story]**: US1–US4 for story phases; Setup/Foundational/Polish carry no story label
- Exact file paths are included in each task

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Stand up the new `ThemeKit` package and wire it into the build graph.

- [ ] T001 Create the `ThemeKit` SPM package skeleton: `Packages/ThemeKit/Package.swift` with **two products** — `ThemeKit` (main) and `ThemeKitTestSupport` (for shared fakes, mirroring `ImmichClientTestSupport`) — plus `Sources/ThemeKit/`, `Sources/ThemeKitTestSupport/`, and `Tests/ThemeKitTests/`. Add the package to the Xcode project so the app target links `ThemeKit` (synchronized group — no manual pbxproj surgery; see memory note).
- [ ] T002 [P] Declare `ThemeKit` as a dependency of `SlideshowKit` in `Packages/SlideshowKit/Package.swift` (target dependency only; no code use yet).
- [ ] T003 Confirm the workspace still builds via XcodeBuildMCP (`build_sim`) with the empty `ThemeKit` added — baseline green before any logic.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The `ThemeSettings` model + store + injection seam that every user story consumes.

**⚠️ CRITICAL**: No user story work begins until this phase is complete.

### Tests (write first — must FAIL)

- [ ] T004 [P] Failing test: `ThemeSettings` defaults match data-model (shuffle, 15 s, crossfade, no Ken Burns, Fit, Preview, clock off) in `Packages/ThemeKit/Tests/ThemeKitTests/ThemeSettingsDefaultsTests.swift`.
- [ ] T005 [P] Failing test: `UserDefaultsThemeStore` round-trips every field (isolated suite name), falls back to defaults on missing/corrupt values per field (FR-013), and clamps out-of-range duration to the committed **3 s … 600 s** range (FR-005) in `Packages/ThemeKit/Tests/ThemeKitTests/UserDefaultsThemeStoreTests.swift`.

### Implementation

- [ ] T006 [P] Implement `ThemeSettings` value type + enums (`PlayOrder`, `Transition`, `ImageFit`, `ImageQuality`, `ClockSettings`, `ClockCorner`), `Sendable`/`Equatable`, stable string rawValues, in `Packages/ThemeKit/Sources/ThemeKit/ThemeSettings.swift`.
- [ ] T007 Implement the `ThemeSettingsStore` protocol + `@Observable` store surface in `Packages/ThemeKit/Sources/ThemeKit/ThemeSettingsStore.swift` (see `contracts/ThemeSettingsStore.md`).
- [ ] T008 Implement `UserDefaultsThemeStore` (namespaced keys per data-model, per-field fallback, duration clamp, no secrets) in `Packages/ThemeKit/Sources/ThemeKit/UserDefaultsThemeStore.swift`.
- [ ] T009 [P] Implement `InMemoryThemeStore` fake in `Packages/ThemeKit/Sources/ThemeKitTestSupport/InMemoryThemeStore.swift` (its own product, **not** the test target) so `SlideshowKitTests` and the app-hosted tests can import it. SlideshowKit's test target adds `ThemeKitTestSupport` as a dependency.
- [ ] T010 Run T004/T005 to green via host `swift test` (ThemeKit).
- [ ] T011 Inject one shared `ThemeSettingsStore` at app construction in `Immich Slideshow/Immich_SlideshowApp.swift` and thread it (signature only, no behavior change yet) into `SlideshowViewModel`, `SlideshowView`, and `SlideshowSettingsView`. Build green via XcodeBuildMCP.

**Checkpoint**: ThemeSettings exists, persists, and is injected everywhere it's needed.

---

## Phase 3: User Story 1 - Adjust order and timing, live + persisted (Priority: P1) 🎯 MVP

**Goal**: Order (shuffle/sequential) and per-photo duration are configurable, apply to the running show
without restart, and persist.

**Independent Test**: Set order/duration in settings → running show reflects them within one advance;
relaunch → choices persist (quickstart steps 2, 3, 8).

### Tests (write first — must FAIL)

- [ ] T012 [P] [US1] Failing test: sequential play sequence visits album order and wraps, in `Packages/SlideshowKit/Tests/SlideshowKitTests/PlayOrderTests.swift`.
- [ ] T013 [P] [US1] Failing test: shuffle (seeded RNG) shows every photo once per cycle, reshuffles next cycle (SC-004), same file.
- [ ] T014 [P] [US1] Failing test: live-duration ticker waits the store's current duration and re-arms when duration changes mid-show, using a fake clock (timing seam), in `Packages/SlideshowKit/Tests/SlideshowKitTests/DurationTickerTests.swift`.

### Implementation

- [ ] T015 [US1] Add a play-sequence abstraction to `SlideshowViewModel` (reads `settings.order`; rebuilds on change; keeps the current photo as cursor anchor) in `Packages/SlideshowKit/Sources/SlideshowKit/SlideshowViewModel.swift`.
- [ ] T016 [US1] Replace the fixed-interval ticker with a live-duration ticker reading `settings.duration`; remove reliance on `SlideshowConfig.interval` (keep `prefetchDepth`/`cacheLimit`) in `Packages/SlideshowKit/Sources/SlideshowKit/SlideshowTicker.swift` and `SlideshowConfig.swift`. **Timing-sensitive (review R1)**: read `settings.duration` **on the MainActor at the top of each loop cycle** (do NOT read `@MainActor` store state from a detached task) and `clock.sleep(for:)` that value — so a duration change auto-applies on the next cycle with no explicit re-arm. Tests drive it with a fake clock that records the requested interval.
- [ ] T017 [US1] Update app construction in `Immich Slideshow/Immich_SlideshowApp.swift` to build the view model with the store-driven ticker (drop `RealTicker(interval: SlideshowConfig.default.interval)`).
- [ ] T018 [US1] Make T012–T014 green (host `swift test`).
- [ ] T019 [US1] Replace the "Reihenfolge" and "Anzeigedauer" placeholder rows in `Immich Slideshow/Slideshow/SlideshowSettingsView.swift` with live controls bound to the store. Verify in the simulator (XcodeBuildMCP), incl. relaunch persistence.

**Checkpoint**: MVP — order + duration are real, live, and persisted.

---

## Phase 4: User Story 2 - Transition and Ken Burns motion (Priority: P2)

**Goal**: Selectable transition (crossfade/slide/dissolve/none) and opt-in Ken Burns; defaults preserve
the calm crossfade with no motion.

**Independent Test**: Pick each transition → next advance uses it; toggle Ken Burns → slow pan/zoom
appears, off → static (quickstart step 4).

### Tests (write first — must FAIL)

- [ ] T020 [P] [US2] Failing test: a pure mapping from `Transition` → an animation descriptor (factored out so it's host-testable) in `Packages/SlideshowKit/Tests/SlideshowKitTests/TransitionMappingTests.swift`. (Visual correctness is simulator-verified, not asserted here.)

### Implementation

- [ ] T021 [US2] Apply `settings.transition` to the image-swap in `Immich Slideshow/Slideshow/SlideshowView.swift` (crossfade default; slide; dissolve; none). **Review R5**: refactor the existing id-based crossfade so the transition is chosen at runtime and "none" disables animation entirely (no double fade).
- [ ] T022 [US2] Add an opt-in Ken Burns modifier (slow scale+translate over the photo's duration) honoring `settings.fit` (small base scale under Fit so no gap shows); default off; in `SlideshowView.swift` (or a small `KenBurnsModifier.swift` in the app target). **Review R4**: drive the motion duration from the live per-photo duration and reset it cleanly on manual next/prev and on pause.
- [ ] T023 [US2] Replace the "Übergang" and "Ken Burns" placeholder rows in `SlideshowSettingsView.swift` with live controls bound to the store.
- [ ] T024 [US2] Simulator validation via XcodeBuildMCP: each transition + Ken Burns on/off, with screenshots (quickstart step 4).

**Checkpoint**: US1 + US2 both work; calm default intact.

---

## Phase 5: User Story 3 - Image fit and quality (Priority: P2)

**Goal**: Fit (letterbox) vs Fill (crop), and Preview vs Original quality; defaults Fit + Preview.

**Independent Test**: Fill crops a portrait photo to fill with no bars; Original loads full-res
(quickstart steps 5, 6).

### Tests (write first — must FAIL)

- [ ] T025 [P] [US3] Failing test: `ImmichClient.original(assetID:)` issues `GET api/assets/{id}/original` with the `x-api-key` header, in `Packages/ImmichClient/Tests/ImmichClientTests/OriginalEndpointTests.swift`.
- [ ] T026 [P] [US3] Failing test: `SlideshowViewModel` calls `original` vs `preview` per `settings.quality` (mock `ImmichAPI` records which was called), in `Packages/SlideshowKit/Tests/SlideshowKitTests/QualitySelectionTests.swift`.

### Implementation

- [ ] T027 [US3] Add `original(assetID:)` to `ImmichAPI` with a default fallback to `preview`, and implement it in `ImmichClient` (verify the path against the live OpenAPI `/api/server/version` first) in `Packages/ImmichClient/Sources/ImmichClient/ImmichAPI.swift` and `ImmichClient.swift`.
- [ ] T028 [US3] Branch the fetch in `SlideshowViewModel.loadImageData` on `settings.quality` in `Packages/SlideshowKit/Sources/SlideshowKit/SlideshowViewModel.swift`. **Review R3**: include the quality in the `ImageCache` key (e.g. `assetID + quality`) so switching Preview↔Original doesn't serve stale cached bytes; update `Packages/SlideshowKit/Sources/SlideshowKit/ImageCache.swift` and its test accordingly.
- [ ] T029 [US3] Make T025/T026 green (host `swift test`).
- [ ] T030 [US3] Branch the render in `SlideshowView.swift` on `settings.fit` (`scaledToFit` vs `scaledToFill` + `.clipped()`).
- [ ] T031 [US3] Replace the "Bildanpassung" placeholder row and add a "Qualität" row in `SlideshowSettingsView.swift`, bound to the store.
- [ ] T032 [US3] Simulator validation via XcodeBuildMCP: Fit vs Fill on a portrait photo, and Preview vs Original sharpness (quickstart steps 5, 6).

**Checkpoint**: US1–US3 all independently functional.

---

## Phase 6: User Story 4 - Optional clock overlay (Priority: P3)

**Goal**: An opt-in clock (off by default) showing time, optional date, in a configurable corner.

**Independent Test**: Enable → time shows in chosen corner; toggle date; disable → gone (quickstart
step 7).

### Tests (write first — must FAIL)

- [ ] T033 [P] [US4] Failing test: clock defaults to off and round-trips `corner`/`showDate` (extends ThemeKit store tests) in `Packages/ThemeKit/Tests/ThemeKitTests/ClockSettingsTests.swift`.

### Implementation

- [ ] T034 [US4] Create `ClockOverlayView` (TimelineView periodic, corner from settings, optional date) in `Immich Slideshow/Slideshow/ClockOverlayView.swift`, gated on `settings.clock.isOn` (default off).
- [ ] T035 [US4] Add the clock overlay above the image and below the reveal-on-tap chrome in `SlideshowView.swift`.
- [ ] T036 [US4] Replace the "Uhr-Overlay" placeholder row with live controls (on/off, corner, show date) in `SlideshowSettingsView.swift`.
- [ ] T037 [US4] Simulator validation via XcodeBuildMCP: clock on/off, date toggle, corner change (quickstart step 7).

**Checkpoint**: All four stories functional and independently testable.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [ ] T038 [P] Run full `quickstart.md` validation (Layer 1 host tests + Layer 2 simulator) via XcodeBuildMCP; confirm SC-001..SC-006.
- [ ] T039 [P] Verify the calm defaults are unchanged on a fresh install (SC-003) and that nothing in `UserDefaults`/logs is a secret (SC-006).
- [ ] T040 Sweep for leftover `SlideshowConfig.interval` references and dead placeholder code in the app target and SlideshowKit.
- [ ] T041 [P] Update `docs/engineering-notes.md` with the `ThemeKit` settings seam and the live-duration ticker gotcha (timing seam).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: start immediately.
- **Foundational (Phase 2)**: after Setup — **blocks all user stories** (the store + injection seam).
- **User Stories (Phase 3–6)**: after Foundational. US1 also delivers the live play-sequence + ticker
  the others assume; do US1 first. US2/US3/US4 are then independent of each other.
- **Polish (Phase 7)**: after the desired stories are done.

### User Story Dependencies

- **US1 (P1)**: depends only on Foundational. MVP.
- **US2 (P2)**: depends on Foundational + the live-settings read in `SlideshowView` (added in US1). View-only.
- **US3 (P2)**: depends on Foundational; adds the `original` fetch + fit branch. Independent of US2.
- **US4 (P3)**: depends on Foundational; clock fields already in ThemeKit. Independent of US2/US3.

### Within Each Story

- Tests written and failing before implementation (constitution).
- Model/store before consumers; engine logic before UI; logic green (host) before simulator validation.

### Parallel Opportunities

- T002 with T001 follow-up; T004/T005 in parallel; T006/T009 in parallel.
- Within US1: T012/T013/T014 (tests) in parallel.
- After Foundational, with capacity: US2, US3, US4 can proceed in parallel (different files); only US1
  must land first.

---

## Implementation Strategy

### MVP First (User Story 1)

1. Phase 1 Setup → 2 Foundational → 3 US1.
2. **STOP and VALIDATE**: order + duration live and persisted on the simulator.
3. This alone makes the dead settings rows real and is demoable.

### Incremental Delivery

US1 (MVP) → US2 (transitions/Ken Burns) → US3 (fit/quality) → US4 (clock), each tested and demoable
independently, each preserving the calm default.

---

## Out of Scope (do not implement here — separate milestones, already specified)

- Resilience: disk cache, auto-retry/backoff, periodic refresh, cache-size + Clear-cache row
  (`specs/003` US6).
- Presence-driven sleep/wake + HA motion (`specs/004` US4; `specs/005` US4).
- Multi-source albums / Memories / shared-link mode (`specs/001` US4; `specs/002` US4; `specs/007` US8).
- Localization EN+DE (`specs/007` US7).
- Video / Live Photo playback.

---

## Notes

- [P] = different files, no dependency on an incomplete task.
- Each story is independently completable and testable; verify tests fail before implementing.
- The live-duration ticker (T016) is the one timing-sensitive seam — implement with the fake clock and
  watch for races with the detached ticker task; keep this inline per CLAUDE.md (don't delegate timer
  test design).
- Commit after each task or logical group; stage explicit paths only.
