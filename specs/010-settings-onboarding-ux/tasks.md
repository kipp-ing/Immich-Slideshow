---

description: "Task list for feature 010 — Settings & Onboarding UX Consolidation"
---

# Tasks: Settings & Onboarding UX Consolidation

**Input**: Design documents from `/specs/010-settings-onboarding-ux/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/OnboardingViewModel.md,
contracts/BrokerSetupViewModel.md, quickstart.md

**Tests**: Included and written first — TDD is NON-NEGOTIABLE (Constitution I). Host unit tests
(Swift Testing) cover the view-model logic; SwiftUI, the folded-in sections, and the scroll fix are
verified via XcodeBuildMCP (simulator + XcUITest).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an incomplete task)
- **[Story]**: US1 / US2 / US3 (Setup & Polish have no story label)

## Path Conventions

- Logic: `Packages/OnboardingKit/…`, `Packages/BrokerSetupKit/…` (sources + `Tests/`)
- App/UI: `Immich Slideshow/Onboarding/`, `Immich Slideshow/Slideshow/`
- UI tests: `Immich SlideshowUITests/`; host model tests: `Immich SlideshowTests/`

---

## Phase 1: Setup (baseline)

**Purpose**: Establish a green baseline so the failing tests introduced below are demonstrably ours
(red-before-green), per Constitution I.

- [x] T001 Confirm baseline green before any change: `swift test --package-path Packages/OnboardingKit`, `swift test --package-path Packages/BrokerSetupKit`, and an app-target build via XcodeBuildMCP.

**Checkpoint**: Known-green starting point.

---

## Phase 2: User Story 1 — One-screen connection during onboarding (Priority: P1) 🎯 MVP

**Goal**: Collapse the `.server` + `.apiKey` steps into one `.connection` step: a single screen
collects server URL + API key with helper text and one **Continue** that validates reachability AND
authorization in one action (distinct unreachable-vs-unauthorized errors), stores the key in the
Keychain, and advances to album selection. A disabled placeholder reserves the future shared-link seam.

**Independent Test**: From a clean install, enter a valid server + key on one screen, tap Continue once
→ land on album selection (key in Keychain); a wrong key keeps the screen open with a clear error and
preserved input (quickstart US1).

### Tests (write first — must FAIL)

- [x] T002 [P] [US1] Rewrite `Packages/OnboardingKit/Tests/OnboardingKitTests/OnboardingViewModelTests.swift` for the merged `.connection` machine per `contracts/OnboardingViewModel.md`: `rejectsNonHTTPSURL` (stays `.connection`, no network), `advancesToAlbumWhenReachableAndAuthorized` (→ `.album`, key saved, `albums` populated), `staysWhenServerUnreachable` (`.unreachable`, key **not** saved), `staysWhenUnauthorized` (`.unauthorized`, message **≠** the unreachable message → SC-006, key **not** saved), `staysWhenKeychainSaveFails`, `staysWhenAlbumListEmpty`, `resetReturnsToConnection`. **Delegable.**

### Implementation

- [x] T003 [US1] Replace `.server` + `.apiKey` with a single `.connection` case in `Packages/OnboardingKit/Sources/OnboardingKit/OnboardingStep.swift`. **Delegable.**
- [x] T004 [US1] In `Packages/OnboardingKit/Sources/OnboardingKit/OnboardingViewModel.swift`, replace `submitServerURL()` + `submitAPIKey()` with one `submitConnection()` (normalize URL → single `albums()` call with the entered key → `ConnectionError.message(for:)` on `ImmichError` → save key to Keychain only on success → empty-list guard → advance to `.album`), and point `reset()` at `.connection`. Make T002 green. **Delegable.**
- [x] T005 [US1] Verify `OnboardingKit` host tests green: `swift test --package-path Packages/OnboardingKit`. **Delegable.**
- [x] T006 [US1] Create `Immich Slideshow/Onboarding/ConnectionStepView.swift`: server URL field + secure API-key field on one screen, concise per-field helper text (what the server address is; where to create an API key in Immich), a single primary **Continue** (accessibility id `onboarding.connection.continue`) disabled until both fields are non-empty, inline error, and a **disabled** shared-link placeholder row reserved for spec 011 (FR-008). **INLINE (SwiftUI/simulator).**
- [x] T007 [US1] Update `Immich Slideshow/Onboarding/OnboardingFlowView.swift` to switch on `.connection`, and delete `Immich Slideshow/Onboarding/ServerStepView.swift` and `Immich Slideshow/Onboarding/APIKeyStepView.swift` (folded into T006). **INLINE (onboarding/app-entry wiring).**
- [x] T008 [US1] Fix host model test `Immich SlideshowTests/OnboardingResetTests.swift` (line ~52) to expect `viewModel.step == .connection` after reset (was `.server`). **Delegable.**
- [x] T009 [US1] Rewrite the onboarding UI flow in `Immich SlideshowUITests/Immich_SlideshowUITests.swift`: enter server + key on the one combined screen and tap `onboarding.connection.continue` once (replacing the `onboarding.server.continue` → `onboarding.apiKey.connect` two-button sequence at lines ~32/46), then select the album. **INLINE (XcUITest/simulator).**
- [x] T010 [US1] Simulator/XcUITest validation via XcodeBuildMCP (quickstart US1): one screen with helper text; Continue disabled until both fields filled; valid pair → album step; wrong key → distinct error + preserved input; shared-link placeholder visible but disabled. **INLINE.**

**Checkpoint**: US1 independently functional — onboarding is one validated screen before album selection.

---

## Phase 3: User Story 2 — Connection + MQTT folded into Settings (Priority: P2)

**Goal**: Surface Connection and MQTT/broker as collapsed-by-default `DisclosureGroup` sections inside
`SlideshowSettingsView`; remove broker setup from the "Reset configuration?" dialog. Connection reuses
the 009 `ConnectionSettingsViewModel`; MQTT is backed by a newly extracted, host-testable
`BrokerSetupViewModel`.

**Independent Test**: From a running slideshow open Settings → expand MQTT → change host → save persists
without the reset dialog; expand Connection → change URL/key → validated before persist, applied live,
key never shown; the reset dialog no longer offers broker setup (quickstart US2).

### Tests (write first — must FAIL)

- [x] T011 [P] [US2] New failing unit tests `Packages/BrokerSetupKit/Tests/BrokerSetupKitTests/BrokerSetupViewModelTests.swift` per `contracts/BrokerSetupViewModel.md`: `loadPrefillsWithoutSecret`, `saveNewBrokerPersists`, `saveEmptyPasswordKeepsExisting`, `saveInvalidPortReportsError`, `saveEmptyHostReportsError`, `removeClearsStore` (against an in-memory `BrokerSettingsStore`). **Delegable.**

### Implementation

- [x] T012 [US2] Create `Packages/BrokerSetupKit/Sources/BrokerSetupKit/BrokerSetupViewModel.swift` (`@Observable`): move `host`/`port`/`username`/`password`/`passwordIsSet` + `load()`/`save() -> Bool`/`remove()` and the `BrokerValidationError → message` mapping out of `BrokerSetupView`, injecting `BrokerSettingsStore`; empty-password-keeps-stored-secret preserved (FR-013). Make T011 green; re-run `swift test --package-path Packages/BrokerSetupKit`. **Delegable.**
- [x] T013 [US2] Refactor `Immich Slideshow/Slideshow/BrokerSetupView.swift` into a thin view over `BrokerSetupViewModel` whose field content can render inline inside a settings section (keep the `--uitest` in-memory store seam). **INLINE (SwiftUI).**
- [x] T014 [US2] In `Immich Slideshow/Slideshow/SlideshowSettingsView.swift`, add a **Connection** section (collapsed `DisclosureGroup`, backed by the injected `ConnectionSettingsViewModel`, replacing the current row-that-opens-a-sheet) and an **MQTT** section (collapsed `DisclosureGroup`, backed by `BrokerSetupViewModel`); both default collapsed (FR-014). Wire the broker store + connection seams from the app layer. **INLINE (SwiftUI/simulator).**
- [x] T015 [US2] In `Immich Slideshow/Slideshow/SlideshowView.swift`, remove the "Broker einrichten" button from the "Reset configuration?" confirmation dialog (line ~117) and the `showBrokerSetup` sheet; the dialog is reset + cancel only (FR-011). **INLINE.**
- [x] T016 [US2] Update `Immich SlideshowUITests/BrokerSetupUITests.swift` (and the `--uitest-broker` launch seam) to reach the broker fields by opening Settings and expanding the MQTT section instead of the reset-dialog sheet; keep `--uitest-broker-existing` seeding. Update any reset-dialog broker assertion in `Immich SlideshowUITests/SettingsDisplayOptionsUITests.swift`. **INLINE (XcUITest/simulator).**
- [x] T017 [US2] Add a Settings UI assertion in `Immich SlideshowUITests/SettingsUITests.swift` that Connection and MQTT appear as collapsible sections (collapsed by default; expandable). **INLINE.**
- [x] T018 [US2] Simulator/XcUITest validation via XcodeBuildMCP (quickstart US2): sections collapsed by default; MQTT edit→save persists without the reset dialog; Connection edit validated/applied live with the key never shown; reset dialog offers no broker setup; **and** collapsing then re-expanding a section preserves typed-but-unsaved input (spec Edge Case, G2). **INLINE.**

**Checkpoint**: US1 + US2 functional and independently testable; MQTT is discoverable from Settings.

---

## Phase 4: User Story 3 — Every settings section is reachable (Priority: P3)

**Goal**: `SlideshowSettingsView` scrolls so every section — including the folded-in Connection and
MQTT — is reachable in both orientations and with the keyboard presented.

**Independent Test**: On iPad, scroll Settings to the bottom-most section in portrait and landscape and
with a lower text field focused; confirm it is fully reachable (quickstart US3).

- [x] T019 [US3] Reproduce the scroll defect on the simulator via XcodeBuildMCP with all sections present and record the root cause (sheet detent / fixed frame / `ScrollView` nesting / `DisclosureGroup`-in-`Form` layout). **INLINE (simulator).**
- [x] T020 [US3] Fix `Immich Slideshow/Slideshow/SlideshowSettingsView.swift` so every section is reachable by scrolling regardless of content height, in portrait and landscape, at reduced split-view/Slide Over widths, and with the keyboard up (FR-015/FR-016). **INLINE (SwiftUI/simulator).**
- [x] T021 [US3] Add/extend an XcUITest in `Immich SlideshowUITests/SettingsUITests.swift` that scrolls to and asserts hittability of the bottom-most section (portrait + landscape, including a reduced split-view width — G1). **INLINE (XcUITest).**
- [x] T022 [US3] Simulator validation via XcodeBuildMCP (quickstart US3): bottom section reachable in both orientations, at a reduced split-view width, and with the keyboard presented (FR-016, G1). **INLINE.**

**Checkpoint**: All three stories independently functional.

---

## Phase 5: Polish & Cross-Cutting Concerns

- [x] T023 [P] Security spot-check the diff (Constitution III + IV): the API key and the broker password reach only `keychain.save` / `BrokerSettingsStore.save`; neither is logged, written to UserDefaults, nor interpolated into a view label (FR-007, FR-013); **and** no TLS bypass is introduced — no `URLSessionDelegate` server-trust override / `serverTrust` handling added; networking reuses the existing TLS-validated client (FR-017, G3).
- [x] T024 [P] Confirm no new Immich REST path is introduced (FR-018): onboarding still uses only `albums()`; the broker path is unchanged.
- [x] T025 Full gate via XcodeBuildMCP: build the app target, `swift test` for `OnboardingKit` + `BrokerSetupKit`, and run the **full XcUITest suite** (`test_sim`) before merge (per project memory: screenshots miss UI-test regressions). Record quickstart results.
- [x] T026 Cross-model review via `/codex:review` and address findings.

---

## Dependencies & Execution Order

- **Phase 1 (Setup)** establishes the green baseline.
- **US1 (Phase 2)** depends only on Setup. Order: T002 (tests) → T003/T004 (step + view model) → T005
  (green) → T006/T007 (combined screen + routing) → T008 (reset test) → T009 (UI flow) → T010 (sim).
- **US2 (Phase 3)** depends only on Setup and is independent of US1. Order: T011 (tests) → T012 (view
  model) → T013 (thin view) → T014 (settings sections) → T015 (reset-dialog cleanup) → T016/T017 (UI
  tests) → T018 (sim).
- **US3 (Phase 4)** depends on US2 — both edit `SlideshowSettingsView.swift`, and the folded-in sections
  make scrolling matter. Order: T019 (repro) → T020 (fix) → T021 (UI test) → T022 (sim).
- **Polish (Phase 5)** runs after the desired stories.

### Parallel opportunities

- US1 logic (OnboardingKit) and US2 logic (BrokerSetupKit) are in **different packages** → T002–T005
  and T011–T012 can proceed in parallel by different agents.
- T002 and T011 (the two failing test files) are independent → parallel.
- T014, T015, T019–T022 all touch `SlideshowSettingsView.swift` / `SlideshowView.swift` → **sequential**,
  not parallel.
- Polish T023 and T024 are read-only checks → parallel.

## Implementation Strategy

- **MVP = US1 (Phase 1 + Phase 2)**: the one-screen onboarding. Shippable on its own.
- **US2** folds Connection + MQTT into Settings and fixes the buried-MQTT discoverability bug.
- **US3** is the scroll fix layered on the now-taller Settings screen.
- **Delegation**: the two `@Observable` logic slices + their host tests (T002–T005, T008, T011–T012) are
  delegable to Codex with the security constraints in the briefing. **All SwiftUI, routing, reset-dialog,
  and XcUITest tasks stay inline** (simulator verification / app-entry wiring) per CLAUDE.md. Claude owns
  the security spot-check (T023) and the XcodeBuildMCP gate (T010, T018, T022, T025).
