# Implementation Plan: Settings & Onboarding UX Consolidation

**Branch**: `010-settings-onboarding-ux` | **Date**: 2026-06-22 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/010-settings-onboarding-ux/spec.md`

## Summary

Three UI/UX consolidations over existing modules — no new Immich endpoints, no new data source.

1. **Onboarding merge (US1)**: collapse the two pre-album onboarding steps (`.server` + `.apiKey`)
   into one `.connection` step. `OnboardingViewModel` gains a single `submitConnection()` that
   validates reachability **and** authorization in one `albums()` round trip (reusing 009's design and
   the `ImmichError → ConnectionError` mapping, which already yields distinct *unreachable* vs
   *unauthorized* messages), stores the key in the Keychain, and advances to album selection. A new
   combined SwiftUI screen replaces `ServerStepView` + `APIKeyStepView`, adds per-field helper text,
   and shows an **inert** placeholder row for the future shared-album-link entry (spec 011).
2. **Settings fold-in (US2)**: `SlideshowSettingsView` hosts **Connection** and **MQTT/broker** as
   collapsible `DisclosureGroup` sections (collapsed by default). Broker setup is removed from the
   "Reset configuration?" dialog. The broker form's logic is extracted into a host-testable
   `BrokerSetupViewModel` (`@Observable`) so it can be embedded inline and unit-tested; the connection
   editor reuses the existing `ConnectionSettingsViewModel` (009).
3. **Scroll fix (US3)**: reproduce and fix the settings screen so every section is reachable by
   scrolling on iPad in both orientations and with the keyboard up.

**Delegation**: the two `@Observable` logic slices — the merged `OnboardingViewModel` and the new
`BrokerSetupViewModel` — are test-first and delegable to Codex (host unit tests, no simulator). All
SwiftUI (combined onboarding screen, disclosure sections, scroll fix, inert seam) and the app-entry
routing/reset-dialog edits stay **inline** (simulator verification, cross-cutting wiring) per CLAUDE.md.

## Technical Context

**Language/Version**: Swift 6

**Primary Dependencies**: SwiftUI, Observation (`@Observable`), Security (Keychain); internal packages
`OnboardingKit` (onboarding state machine, config/keychain, `ConnectionSettingsViewModel`,
`ConnectionURL`, `ConnectionError`), `ImmichClient` (`ImmichAPI`, `ServerConfig`, `ImmichError`),
`BrokerSetupKit` (`BrokerSettings`, `BrokerSettingsStore`, `KeychainBrokerSettingsStore`).

**Storage**: No new storage. `AppConfiguration` (server URL + album ID) in UserDefaults via
`ConfigStore`; API key + broker password in the Keychain (`KeychainStore`, `KeychainBrokerSettingsStore`).

**Testing**: Swift Testing (`@Test`) host unit tests for the merged `OnboardingViewModel` and the new
`BrokerSetupViewModel` against existing fakes (`InMemoryConfigStore`, `InMemoryKeychainStore`,
`MockTransport`-backed `ImmichAPI`, in-memory `BrokerSettingsStore`). XcUITest for the folded-in
settings flow and combined onboarding screen (driven via existing `--uitest*` launch seams).
XcodeBuildMCP for app-target build, SwiftUI previews, and simulator verification — including the US3
scroll repro, which only a simulator can confirm.

**Target Platform**: iPadOS 18+

**Project Type**: Mobile app (iPad), MVVM with `@Observable`, Swift Package Manager modules + app target

**Performance Goals**: N/A (interaction/layout feature). Qualitative targets are the spec's Success
Criteria (one-screen onboarding; ≤2 taps to MQTT; 100% of sections scroll-reachable).

**Constraints**: API key + broker password Keychain-only, never UserDefaults/logs/plaintext
(Constitution III); TLS validation never disabled (Constitution IV); no new Immich REST endpoints
(FR-018); advanced sections collapsed by default and the shared-link seam inert (Constitution VII).

**Scale/Scope**: ~2 view-model changes (1 merged, 1 extracted) + host tests; 1 new combined onboarding
view (replaces 2); settings screen gains 2 disclosure sections + scroll fix; reset-dialog + app-entry
routing edits; UI-test updates for the new section placement.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Test-First (NON-NEGOTIABLE)**: PASS — the merged `OnboardingViewModel` (`.connection` step,
  `submitConnection()`) and the extracted `BrokerSetupViewModel` are built test-first (red host unit
  tests for: distinct unreachable-vs-unauthorized errors, key saved only on success, album advance;
  broker save/validate/remove/keep-existing-password) before implementation. SwiftUI + routing verified
  via XcUITest/XcodeBuildMCP.
- **II. Modulare Isolation**: PASS — logic depends only on injected `ImmichAPI`, `ConfigStore`,
  `KeychainStore`, `BrokerSettingsStore` protocols; tested with in-memory fakes, no real server/keychain.
- **III. Keine Secrets im Klartext (NON-NEGOTIABLE)**: PASS — API key and broker password stay in the
  Keychain; secure fields + "is set" hints; no key/password logged, shown, or written to UserDefaults.
  Folding the editors into Settings does not change where secrets live (FR-007, FR-013).
- **IV. Sicherheit der Transportschicht**: PASS — connection validation reuses the TLS-validated
  `ImmichClient`; broker stays TLS (8883). No TLS bypass introduced (FR-017).
- **V. Plattformgrenzen respektieren**: PASS — no brightness/idle/display behavior changed; the scroll
  fix works within standard SwiftUI scrolling.
- **VI. Verifizierbare Akzeptanzkriterien**: PASS — spec FRs/SCs map to concrete unit + UI tests (see
  contracts + quickstart).
- **VII. Schlicht und hell als Default**: PASS — advanced sections collapse by default; the shared-link
  seam is inert; onboarding gets simpler, not busier (FR-008, FR-014).

No violations → Complexity Tracking left empty.

## Project Structure

### Documentation (this feature)

```text
specs/010-settings-onboarding-ux/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── OnboardingViewModel.md      # merged .connection step + submitConnection()
│   └── BrokerSetupViewModel.md     # extracted broker form logic
├── checklists/
│   └── requirements.md  # from /speckit-specify
└── tasks.md             # /speckit-tasks output (not created here)
```

### Source Code (repository root)

```text
Packages/OnboardingKit/Sources/OnboardingKit/
├── OnboardingStep.swift          # CHANGE: replace .server + .apiKey with single .connection
├── OnboardingViewModel.swift     # CHANGE: submitServerURL()+submitAPIKey() → submitConnection()
│                                 #   (one albums() call validates reachable+authorized; distinct errors)
├── ConnectionURL.swift           # reused as-is
└── ConnectionError.swift         # reused as-is (unreachable vs unauthorized messages)

Packages/OnboardingKit/Tests/OnboardingKitTests/
└── OnboardingViewModelTests.swift  # CHANGE: rewrite step tests for the merged .connection machine

Packages/BrokerSetupKit/Sources/BrokerSetupKit/
└── BrokerSetupViewModel.swift    # NEW: @Observable — host/port/username/password/passwordIsSet,
                                  #   load()/save()/remove(), validation-message mapping (delegable)

Packages/BrokerSetupKit/Tests/BrokerSetupKitTests/
└── BrokerSetupViewModelTests.swift  # NEW: save/validate/remove/keep-existing-password unit tests

Immich Slideshow/Onboarding/
├── ConnectionStepView.swift      # NEW: combined server+key screen, helper text, inert shared-link seam
├── OnboardingFlowView.swift      # CHANGE: switch on .connection (was .server/.apiKey)
├── ServerStepView.swift          # REMOVE (folded into ConnectionStepView)
└── APIKeyStepView.swift          # REMOVE (folded into ConnectionStepView)

Immich Slideshow/Slideshow/
├── SlideshowSettingsView.swift   # CHANGE: Connection + MQTT DisclosureGroup sections; scroll fix (INLINE)
├── BrokerSetupView.swift         # CHANGE: thin view over BrokerSetupViewModel; usable as section content
└── SlideshowView.swift           # CHANGE: drop "Broker einrichten" from reset dialog + its sheet (INLINE)

Immich SlideshowUITests/
├── SettingsUITests.swift             # CHANGE: assert folded-in Connection/MQTT sections + scroll
└── SettingsDisplayOptionsUITests.swift  # CHANGE if section identifiers move
```

**Structure Decision**: The two testable logic slices stay in their owning packages — the merged step
machine in `OnboardingKit` (next to `ConnectionSettingsViewModel`/`ConnectionURL`/`ConnectionError`,
which the merge reuses) and the extracted `BrokerSetupViewModel` in `BrokerSetupKit` (next to
`BrokerSettings`/`BrokerSettingsStore`). Both are unit-tested against existing in-memory fakes. All
SwiftUI lives in the app target: the new combined onboarding screen replaces the two step views, and
`SlideshowSettingsView` grows the two disclosure sections and the scroll fix. App-entry routing edits
(the `.connection` case) and the reset-dialog change in `SlideshowView` are kept inline per CLAUDE.md
(onboarding/app-entry wiring is cross-cutting; SwiftUI needs simulator verification).

## Complexity Tracking

> No constitution violations — no entries required.
