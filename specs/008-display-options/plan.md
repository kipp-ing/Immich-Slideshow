# Implementation Plan: Display & Playback Options (ThemeSettings)

**Branch**: `008-display-options` | **Date**: 2026-06-22 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/008-display-options/spec.md`

## Summary

Make the slideshow's display/playback parameters user-configurable, persistent, and live: photo order
(shuffle/sequential), per-photo duration, transition (crossfade/slide/dissolve/none), optional Ken
Burns motion, image fit (Fit/Fill), image quality (Preview/Original), and an optional clock overlay.
The technical approach introduces a small **`ThemeKit`** SPM package (Foundation-only leaf) holding the
settings value types and an `@Observable` `ThemeSettingsStore` behind an injectable protocol, persisted
to `UserDefaults`. `SlideshowKit` depends on `ThemeKit` and reads the live settings for order,
duration, and quality; `SlideshowView` reads them for transition, fit, and the clock overlay. The fixed
`SlideshowConfig.interval` / fixed-interval ticker is replaced by a **live duration source** so changes
re-arm the timer without a restart. `ImmichAPI` gains `original(assetID:)` to back the Original quality
option. The calm overlay-free default (Constitution VII) is preserved: every option defaults to current
behavior or is opt-in.

## Technical Context

**Language/Version**: Swift 6

**Primary Dependencies**: SwiftUI, Observation (`@Observable`), Foundation; existing in-repo packages
`SlideshowKit`, `ImmichClient`, `PowerKit`

**Storage**: `UserDefaults` for non-secret display/playback preferences (no Keychain — no secrets here)

**Testing**: Swift Testing (`@Test`) on the host for package logic; XcodeBuildMCP simulator build +
app-hosted tests / UI tests for SwiftUI and the live brightness/settings screen

**Target Platform**: iPadOS 18+ (iPhone optional)

**Project Type**: Mobile app (SwiftUI) + SPM packages (mobile + library structure)

**Performance Goals**: Slideshow stays smooth (no visible load on advance); a settings change is
reflected within one advance cycle; Ken Burns motion runs at display refresh without jank

**Constraints**: TLS validation never disabled (original fetch reuses the standard URLSession);
brightness/idle-timer behavior unchanged; settings survive app relaunch; no secrets in
UserDefaults/logs

**Scale/Scope**: One new leaf package (`ThemeKit`), ~7 preference fields, edits to `SlideshowKit`
(view model + ticker), `ImmichClient` (one endpoint), and the app target (settings UI + render + clock)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Test-First (NON-NEGOTIABLE)**: PASS — every task is a red Swift Testing test first
  (ThemeSettingsStore persistence/defaults, order/shuffle sequence, duration→ticker, quality→endpoint
  selection, original endpoint URL). UI behaviors verified via app-hosted/UI tests.
- **II. Modular Isolation**: PASS — `ThemeKit` is a Foundation-only leaf with a `ThemeSettingsStore`
  protocol; `SlideshowKit` depends on it via the protocol (injected, no hidden singleton). A fake store
  drives tests with no `UserDefaults`.
- **III. No Secrets in Clear (NON-NEGOTIABLE)**: PASS — preferences are non-secret; UserDefaults is the
  correct store. No API key or credentials are written here or logged.
- **IV. Transport Security**: PASS — `original(assetID:)` reuses the existing `ImmichClient`/URLSession;
  TLS validation untouched.
- **V. Respect Platform Limits**: PASS — no new platform-boundary behavior; brightness/idle-timer
  unchanged.
- **VI. Verifiable Acceptance Criteria**: PASS — spec SC-001..006 are concrete and test-backed.
- **VII. Calm, Bright Default**: PASS — shuffle/15 s/crossfade/no-KenBurns/Fit/Preview/no-clock are the
  defaults; every effect is opt-in or preserves current behavior.

**Result**: No violations. Complexity Tracking not required.

## Project Structure

### Documentation (this feature)

```text
specs/008-display-options/
├── plan.md              # This file
├── research.md          # Phase 0 — design decisions
├── data-model.md        # Phase 1 — ThemeSettings entity + enums
├── quickstart.md        # Phase 1 — how to validate the feature
├── contracts/           # Phase 1 — ThemeSettingsStore + ImmichAPI + ticker contracts
│   ├── ThemeSettingsStore.md
│   ├── ImmichAPI-original.md
│   └── SlideshowEngine-settings.md
├── checklists/
│   └── requirements.md  # Spec quality checklist (done)
└── tasks.md             # Phase 2 — /speckit-tasks (next)
```

### Source Code (repository root)

```text
Packages/
├── ThemeKit/                         # NEW — Foundation-only leaf package
│   ├── Package.swift                 # products: ThemeKit + ThemeKitTestSupport
│   ├── Sources/ThemeKit/
│   │   ├── ThemeSettings.swift       # value type + enums (Order, Transition, Fit, Quality, Clock)
│   │   ├── ThemeSettingsStore.swift  # protocol + concrete @Observable UserDefaultsThemeStore
│   │   └── UserDefaultsThemeStore.swift
│   ├── Sources/ThemeKitTestSupport/
│   │   └── InMemoryThemeStore.swift  # shared fake (importable by SlideshowKit/app tests)
│   └── Tests/ThemeKitTests/
│       ├── ThemeSettingsDefaultsTests.swift
│       └── UserDefaultsThemeStoreTests.swift
│
├── SlideshowKit/                     # EDIT — consume ThemeKit
│   ├── Sources/SlideshowKit/
│   │   ├── SlideshowViewModel.swift  # order sequence, duration source, quality selection
│   │   ├── SlideshowTicker.swift     # live-duration ticker (interval from settings)
│   │   └── SlideshowConfig.swift     # prefetch/cache stay here; interval moves to settings
│   └── Tests/SlideshowKitTests/      # order/shuffle, duration re-arm, quality selection tests
│
└── ImmichClient/                     # EDIT — add original fetch
    ├── Sources/ImmichClient/
    │   ├── ImmichAPI.swift           # + original(assetID:) (default impl falls back to preview)
    │   └── ImmichClient.swift        # GET api/assets/{id}/original
    └── Tests/ImmichClientTests/      # original endpoint URL test

Immich Slideshow/                     # EDIT — app target
├── Immich_SlideshowApp.swift         # construct + inject ThemeSettingsStore
└── Slideshow/
    ├── SlideshowView.swift           # fit (scaledToFit/Fill), transition, Ken Burns, clock overlay
    ├── SlideshowSettingsView.swift   # replace placeholder rows with live controls bound to store
    └── ClockOverlayView.swift        # NEW — opt-in clock (off by default)
```

**Structure Decision**: Mobile-app + SPM-packages layout (matches the existing repo). The new isolated
`ThemeKit` leaf package holds the settings model + store so both the engine (`SlideshowKit`) and the UI
(app target) depend on one source of truth via a protocol, satisfying Constitution II. `SlideshowConfig`
keeps prefetch/cache; the per-photo interval moves to `ThemeSettings` (live).

## Key Integration Points (current code → change)

- `Immich_SlideshowApp.swift:95` constructs `SlideshowViewModel(... ticker: RealTicker(interval:
  SlideshowConfig.default.interval))` — inject a shared `ThemeSettingsStore` and a live-duration ticker
  instead of a fixed interval. The same store instance is passed to `SlideshowView`.
- `SlideshowViewModel` (`imageAssets`, `currentIndex`, `loadImageData`) — add an order/play-sequence
  abstraction and select `preview` vs `original` from `settings.quality`.
- `SlideshowView.swift:261` renders `.scaledToFit()` — branch on `settings.fit` (Fit → `scaledToFit`,
  Fill → `scaledToFill` + clip); apply the chosen transition; add the opt-in Ken Burns modifier and the
  clock overlay.
- `SlideshowSettingsView.swift:42-53` placeholder rows — replace with live controls bound to the store
  (the existing brightness section stays).
- `ImmichClient.swift:50` — add `original(assetID:)` alongside `preview`.

## Complexity Tracking

No constitution violations; no entries required.
