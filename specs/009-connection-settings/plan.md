# Implementation Plan: Editable Connection Settings

**Branch**: `009-connection-settings` | **Date**: 2026-06-22 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/009-connection-settings/spec.md`

## Summary

Surface the Immich server URL and API key in the existing in-app Settings screen (built in 008) so
they can be reviewed and changed after onboarding. A new `ConnectionSettingsViewModel` in
`OnboardingKit` validates the candidate connection with a single `albums()` call (which proves
reachability + authorization at once and yields the album list, with `ImmichError` classifying
unreachable/unauthorized/invalid), persists atomically (Keychain first, then config), and never
reveals the key. A new
`ConnectionSettingsView` is reachable both from the settings screen (proactive change) and from the
slideshow's connection-error state (recovery). On a successful save the app rebuilds the running
slideshow's client against the new connection and resumes the selected album — no return to
onboarding. The app-entry/`RootView` reconnect wiring stays inline (cross-cutting/security); the
view-model validation/persist logic is delegable.

## Technical Context

**Language/Version**: Swift 6

**Primary Dependencies**: SwiftUI, Observation (`@Observable`), Security (Keychain); internal packages
`OnboardingKit` (config/keychain/validation), `ImmichClient` (`ImmichAPI`, `ServerConfig`,
`ImmichError`), `SlideshowKit` (running show), `ThemeKit` (settings screen host)

**Storage**: `AppConfiguration` (server URL + selected album ID) in UserDefaults via `ConfigStore`;
API key in the Keychain via `KeychainStore`. No new storage introduced.

**Testing**: Swift Testing (`@Test`) host unit tests for `ConnectionSettingsViewModel` against the
existing `OnboardingKit` fakes (`InMemoryConfigStore`, `InMemoryKeychainStore(failSave:)`, and a
`MockTransport`-backed `ImmichAPI` factory — the single-`albums()` design works with one mock
response); XcodeBuildMCP for the app target, SwiftUI, and simulator validation.

**Target Platform**: iPadOS 18+

**Project Type**: Mobile app (iPad), MVVM with `@Observable`, Swift Package Manager modules + app target

**Performance Goals**: Connection change to working slideshow < 60 s incl. one network round-trip
(SC-001); photos from the new connection within 5 s of a successful save (SC-004)

**Constraints**: API key Keychain-only, never in UserDefaults/logs/UI plaintext (Constitution III);
TLS validation never disabled (Constitution IV); validate before persist; atomic all-or-nothing save

**Scale/Scope**: One server + one API key active at a time. ~1 new view model + shared URL/error
helpers in `OnboardingKit`, 1 new SwiftUI editor view, wiring into the 008 settings screen, the
slideshow error state, and the `RootView` reconnect path.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Test-First (NON-NEGOTIABLE)**: PASS — `ConnectionSettingsViewModel` is built test-first with
  host unit tests (validation rejects malformed/unreachable/unauthorized; atomic persist; no-op on
  cancel) before implementation. SwiftUI view + reconnect wiring verified via XcodeBuildMCP/simulator.
- **II. Modulare Isolation**: PASS — logic depends only on the injected `ImmichAPI`, `ConfigStore`,
  `KeychainStore` protocols; tested with the existing in-memory fakes, no real server/keychain.
- **III. Keine Secrets im Klartext (NON-NEGOTIABLE)**: PASS — key stays in the Keychain; the editor
  uses a masked/secure field and a "key is set" indicator; the key is never logged, never written to
  UserDefaults, never shown in plaintext. (FR-007, SC-003)
- **IV. Sicherheit der Transportschicht**: PASS — validation and the live client reuse the standard
  TLS-validated `ImmichClient`; no TLS bypass introduced. (FR-008)
- **V. Plattformgrenzen respektieren**: PASS — no brightness/idle/display behavior touched.
- **VI. Verifizierbare Akzeptanzkriterien**: PASS — spec FRs/SCs map to concrete tests (see
  contracts + quickstart).
- **VII. Schlicht und hell als Default**: PASS — editing is opt-in; the calm default and existing
  full-reset path are unchanged. (Assumptions)

No violations → Complexity Tracking left empty.

## Project Structure

### Documentation (this feature)

```text
specs/009-connection-settings/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── ConnectionSettingsViewModel.md
├── checklists/
│   └── requirements.md  # from /speckit-specify
└── tasks.md             # /speckit-tasks output (not created here)
```

### Source Code (repository root)

```text
Packages/OnboardingKit/Sources/OnboardingKit/
├── ConnectionSettingsViewModel.swift   # NEW: validate (reachable+authorized) → atomic persist → outcome
├── ConnectionURL.swift                 # NEW: shared URL normalization (extracted from OnboardingViewModel)
├── ConnectionError.swift               # NEW: shared ImmichError→message mapping (extracted)
├── OnboardingViewModel.swift           # refactor to use the extracted helpers (no behavior change)
├── AppConfiguration.swift              # reused as-is
├── ConfigStore.swift                   # reused as-is
└── KeychainStore.swift                 # reused as-is

Packages/OnboardingKit/Tests/OnboardingKitTests/
└── ConnectionSettingsViewModelTests.swift  # NEW: validation/persist/no-op unit tests (Swift Testing)

Immich Slideshow/Slideshow/
├── ConnectionSettingsView.swift        # NEW: masked editor, reachable from settings + error state
├── SlideshowSettingsView.swift         # add a "Verbindung" row that opens the editor (008 screen)
└── SlideshowErrorView.swift            # add a "Fix connection" entry into the editor (recovery)

Immich Slideshow/
└── Immich_SlideshowApp.swift           # RootView: reconnect path — rebuild slideshow client on a
                                        #   successful save, preserve album, stay in `.done` (INLINE)
```

**Structure Decision**: The connection domain already lives in `OnboardingKit` (config, keychain,
validation), so the new view model + extracted URL/error helpers go there and are unit-tested against
the package's existing fakes. The SwiftUI editor lives in the app target alongside the 008 settings
screen and the slideshow error view. The only app-entry change is the `RootView` reconnect path that
rebuilds the slideshow's `ImmichClient` against the new connection without re-onboarding — kept inline
per CLAUDE.md (app-entry/onboarding wiring is cross-cutting/security-critical).

## Complexity Tracking

> No constitution violations — no entries required.
