---

description: "Task list for feature 009 — Editable Connection Settings"
---

# Tasks: Editable Connection Settings

**Input**: Design documents from `/specs/009-connection-settings/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/ConnectionSettingsViewModel.md, quickstart.md

**Tests**: Included and written first — TDD is NON-NEGOTIABLE (Constitution I). Host unit tests
(Swift Testing) cover the view-model logic; SwiftUI + live reconnect are verified via XcodeBuildMCP.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an incomplete task)
- **[Story]**: US1 / US2 (Setup & Polish have no story label)

## Path Conventions

- Logic: `Packages/OnboardingKit/Sources/OnboardingKit/`, tests in `Packages/OnboardingKit/Tests/OnboardingKitTests/`
- App/UI: `Immich Slideshow/Slideshow/` and `Immich Slideshow/Immich_SlideshowApp.swift`

---

## Phase 1: Setup — shared helpers (blocking prerequisites)

**Purpose**: Extract the URL normalization and error mapping out of `OnboardingViewModel` so both the
onboarding flow and the new connection editor share one definition of "valid". Behavior-preserving
refactors, guarded by the existing onboarding tests (refactor-at-green).

- [ ] T001 Extract `normalizedURL()` into `ConnectionURL.normalize(_:) -> URL?` in `Packages/OnboardingKit/Sources/OnboardingKit/ConnectionURL.swift`, and refactor `Packages/OnboardingKit/Sources/OnboardingKit/OnboardingViewModel.swift` to call it (no behavior change).
- [ ] T002 Extract `message(for:)` into `ConnectionError.message(for: ImmichError) -> String` in `Packages/OnboardingKit/Sources/OnboardingKit/ConnectionError.swift`, and refactor `OnboardingViewModel.swift` to call it (no behavior change).
- [ ] T003 Verify `OnboardingKit` host tests stay green after extraction: `swift test --package-path Packages/OnboardingKit`.

**Checkpoint**: Shared helpers exist; onboarding behavior unchanged.

---

## Phase 2: User Story 1 — Change the connection from Settings, validated before it takes effect (Priority: P1) 🎯 MVP

**Goal**: From the Settings screen, view the current server URL + a "key is set" indicator, edit the
URL and/or replace the key, and save — validated (reachable + authorized) before it takes effect, with
the prior connection preserved on failure, and applied to the running slideshow without re-onboarding.

**Independent Test**: With a working slideshow, open Settings → Verbindung; a wrong key is rejected as
"unauthorized" and the show keeps running; the correct key saves, the show reloads against it, and the
value survives a relaunch (quickstart steps 2–4, 6).

### Tests (write first — must FAIL)

- [ ] T004 [P] [US1] Failing unit tests for `ConnectionSettingsViewModel.save()` in `Packages/OnboardingKit/Tests/OnboardingKitTests/ConnectionSettingsViewModelTests.swift`, covering the contract table scenarios 1–7, 9, 10: prefill (URL filled, stored key never read into input, `keyIsSet` reflects keychain); malformed→`.malformed` with no network; unreachable→`.unreachable`; wrong key→`.unauthorized`; valid→`.success` with Keychain-written-before-config; Keychain throw→`.keychainFailure` with config not written; URL-only (empty key)→validates with the existing key and persists URL keeping the key; failure sets `errorMessage` and leaves prior config/key intact; `isBusy` guards a second concurrent `save()`.

### Implementation

- [ ] T005 [US1] Define `ConnectionValidationOutcome` in `Packages/OnboardingKit/Sources/OnboardingKit/ConnectionValidationOutcome.swift` with the cases from data-model.md (`.malformed`, `.unreachable`, `.unauthorized`, `.invalidResponse`, `.keychainFailure`, `.albumMissing(albums:)`, `.success`).
- [ ] T006 [US1] Implement `ConnectionSettingsViewModel` in `Packages/OnboardingKit/Sources/OnboardingKit/ConnectionSettingsViewModel.swift`: inject `(ServerConfig)->ImmichAPI`, `ConfigStore`, `KeychainStore`; prefill URL from `config.load()`, set `keyIsSet` from `keychain.read() != nil` (never read the key into the input); `save()` normalizes via `ConnectionURL`, validates with a single `albums()` call (reachable + authorized in one round-trip, D2) using the entered key or — if empty — the stored key, then persists Keychain-first then config (atomic, D3); classify errors via `ConnectionError`; guard re-entrancy with `isBusy`. Make T004 green.
- [ ] T007 [US1] Verify `OnboardingKit` host tests green: `swift test --package-path Packages/OnboardingKit`.
- [ ] T008 [US1] Create `ConnectionSettingsView` in `Immich Slideshow/Slideshow/ConnectionSettingsView.swift`: editable URL field, masked/secure key field (`SecureField`), "key is set" indicator, Save/Cancel, busy spinner + inline error; bound to `ConnectionSettingsViewModel`. The stored key is never displayed (FR-007).
- [ ] T009 [US1] Add a "Verbindung" row to `Immich Slideshow/Slideshow/SlideshowSettingsView.swift` that presents `ConnectionSettingsView`, wiring the config/keychain/`ImmichAPI` factory seams from the app layer.
- [ ] T010 [US1] Wire the live reconnect in `Immich Slideshow/Immich_SlideshowApp.swift` (`RootView`): on a `.success` save, rebuild the slideshow's `ImmichClient` from the updated stores and reload the selected album, staying in `.done` (no return to onboarding). **INLINE (app-entry/security — not delegated).**
- [ ] T011 [US1] Simulator validation via XcodeBuildMCP (quickstart steps 2–4, 6): Verbindung row shows URL + key-set with no plaintext key; wrong/malformed input rejected with the show intact; a valid change applies live; cancel is a no-op.

**Checkpoint**: US1 independently functional — the connection is editable, validated, and applied live.

---

## Phase 3: User Story 2 — Recover a broken connection in place, without re-onboarding (Priority: P2)

**Goal**: When the slideshow is in a connection-error state, fix the URL/key in the same editor and
resume the selected album; if the new connection lacks that album, re-select it (no onboarding).

**Independent Test**: Drive the show into the connection-error state, open the editor from it, enter a
valid key, save → the show resumes the previous album with no onboarding; an album-missing connection
opens the album browser (quickstart step 5).

### Tests (write first — must FAIL)

- [ ] T012 [US2] Failing unit test for the `.albumMissing` branch in `Packages/OnboardingKit/Tests/OnboardingKitTests/ConnectionSettingsViewModelTests.swift`: a valid connection whose `albums()` list does not contain the stored selected album ID persists the validated connection and returns `.albumMissing(albums:)` (contract scenario 8).

### Implementation

- [ ] T013 [US2] Implement the `.albumMissing` branch in `ConnectionSettingsViewModel.save()` (compare `config.load()?.selectedAlbumID` against the validated `albums()` list). Make T012 green; re-run `swift test --package-path Packages/OnboardingKit`.
- [ ] T014 [US2] Add a "Fix connection" entry from the error state in `Immich Slideshow/Slideshow/SlideshowErrorView.swift` (and present it from `Immich Slideshow/Slideshow/SlideshowView.swift`) that opens `ConnectionSettingsView`.
- [ ] T015 [US2] Extend the `RootView` reconnect (T010) in `Immich Slideshow/Immich_SlideshowApp.swift` to resume from the error state and, on `.albumMissing`, present the album browser for re-selection instead of onboarding. **INLINE (app-entry/security — not delegated).**
- [ ] T016 [US2] Simulator validation via XcodeBuildMCP (quickstart step 5): error-state → fix key → resume the selected album without onboarding; album-missing connection → album browser appears.

**Checkpoint**: US1 + US2 functional and independently testable.

---

## Phase 4: Polish & Cross-Cutting Concerns

- [ ] T017 [P] Security spot-check the diff (quickstart "Security spot-check"): the API key string reaches only `keychain.save`; it is never logged, set in UserDefaults, or interpolated into a view label (Constitution III, FR-007, SC-003).
- [ ] T018 [P] Confirm no new Immich path is introduced — only `albums()` is used (already in `ImmichAPI`, verified against live OpenAPI in 001/002); no contract/endpoint changes needed (FR-008).
- [ ] T019 Cross-model review via `/codex:review` and address findings.
- [ ] T020 Full gate via XcodeBuildMCP: build the app target + `swift test` for `OnboardingKit`, and record quickstart results.

---

## Dependencies & Execution Order

- **Phase 1 (Setup)** blocks everything (the helpers are reused by the new view model).
- **US1 (Phase 2)** depends on Phase 1. T004 (tests) → T005/T006 (model + view model) → T007 (green) →
  T008/T009 (UI) → T010 (reconnect wiring) → T011 (sim).
- **US2 (Phase 3)** depends on US1 (reuses the editor, view model, and reconnect path). T012 → T013 →
  T014 → T015 → T016.
- **Polish (Phase 4)** runs after US1 + US2.

### Parallel opportunities

- T001 and T002 both edit `OnboardingViewModel.swift` → sequential, not parallel.
- T004 is the only US1 test file task and can start as soon as Phase 1 is green.
- T017 and T018 are independent read-only checks → parallelizable.

## Implementation Strategy

- **MVP = US1 (Phase 1 + Phase 2)**: editing + validation + atomic persist + live apply. Shippable on
  its own.
- **US2** is the recovery increment layered on the same editor.
- **Delegation**: T001–T009, T012–T013 (host-testable logic + SwiftUI editor) are delegable to Codex
  with the security constraints in the briefing. **T010 and T015 (RootView reconnect / app-entry) stay
  inline.** Claude owns the security review (T017) and the XcodeBuildMCP gate (T011, T016, T020).
