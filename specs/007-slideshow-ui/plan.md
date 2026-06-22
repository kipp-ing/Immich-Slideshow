# Implementation Plan: Slideshow UI (native iPadOS 26 chrome, Liquid Glass)

**Branch**: `007-slideshow-ui` | **Date**: 2026-06-22 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/007-slideshow-ui/spec.md`

**Note**: Documented retroactively. Slices A–D are shipped; this plan describes the chosen structure
as it was implemented and records the architecture/verification decisions for the SDD trail.

## Summary

A lean, extensible Liquid Glass chrome over the existing slideshow (feature 003) that preserves the
calm photo-frame default (Constitution VII). Four independently shippable slices:

- **Slice A (US1)** — Reveal-on-tap chrome (top: exit/info/albums/settings; bottom:
  previous/play-pause/next) with ~4.5 s auto-hide, plus swipe-to-advance. Needs small VM additions
  (`showNext`, `showPrevious`, `jump(to:)`, `togglePause`) and carrying the status bar / home
  indicator with the chrome.
- **Slice B (US2)** — Album browser sheet over the running slideshow. Needs runtime album switching
  (`switchAlbum`, reused from the HA-remote path) and a dedicated `thumbnail` endpoint.
- **Slice C (US3)** — Photo-info overlay (date/location). The only slice with backend work: an
  `assetInfo` endpoint + `AssetInfo` model (from Immich `exifInfo`) in the ImmichClient (feature 001).
- **Slice D (US4)** — Settings shell: brightness live (PowerManager/004), remaining display options as
  a disabled preview until ThemeSettings (#5).

Technical approach: the views live in the app target under `Immich Slideshow/Slideshow/`; the control
logic extensions go into the existing packages `SlideshowKit` (VM) and `ImmichClient` (EXIF/thumbnail).
No new package needed. VM/client logic via host tests (Swift Testing); chrome, browser, info overlay,
and settings via hermetic XCUITest (`--uitest` seams) on the simulator.

## Technical Context

**Language/Version**: Swift 6

**Primary Dependencies**: SwiftUI / Observation (iPadOS 26, Liquid Glass: `glassEffect`,
`GlassEffectContainer`, `.buttonStyle(.glass)`); internally `SlideshowKit` (VM/cache/ticker, 003),
`ImmichClient` (REST, 001), `PowerKit` (brightness, 004), `HAControlKit` (existing coordinator). No
third-party libraries.

**Storage**: None new. The API key stays in the Keychain (001/002); the UI persists nothing. The album
source chosen at runtime is deliberately **not** persisted (see Open items).

**Testing**: Swift Testing (`@Test`) host-side for the VM additions (`SlideshowKit`) and the new
client endpoints (`ImmichClient`, `MockTransport`). XCUITest app-hosted for chrome, album browser, info
overlay, and settings — hermetic `--uitest` build (stub API + in-memory stores), driven via
XcodeBuildMCP (`test_sim`).

**Target Platform**: iPadOS 26 (the project builds the app scheme only on iOS 26.x simulators). The
Liquid Glass APIs are iOS-26-specific.

**Project Type**: Mobile-app feature — views in the app target + logic extensions in existing SPM
packages.

**Performance Goals**: Keep the 0.6 s cross-fade; thumbnails cheap (dedicated smaller endpoint);
prefetch/cache from 003 unchanged (interval 8 s, prefetchDepth 2, cacheLimit 5).

**Constraints**: Calm default — all chrome is opt-in / on tap, auto-hide after ~4.5 s (Constitution
VII). Brightness/idle timer take effect in the foreground only (Constitution V). No secrets in
UI/logs (Constitution III). No hidden singletons — `ImmichAPI`/`PowerManager`/VM injected (Constitution
II). Backward navigation only manual.

**Scale/Scope**: Four views (Chrome, AlbumBrowser, PhotoInfo, Settings) + extension of `SlideshowView`;
four new VM methods + a pause state; two new client endpoints + one model.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Assessment | Status |
|-----------|------------|--------|
| I. Test-First (NON-NEGOTIABLE) | VM additions (`showPrevious`/`showNext`/`jump`/`togglePause`/`switchAlbum`) and client endpoints (`assetInfo`/`thumbnail`) via red host tests before impl; chrome/browser/info/settings via XCUITest on the simulator. | ✅ |
| II. Modular Isolation | UI depends on `ImmichAPI`/`PowerManager`/`SlideshowViewModel` via protocols/injected instances; tests run against a stub API / in-memory stores, no real server. | ✅ |
| III. No Secrets in Plaintext (NON-NEGOTIABLE) | UI shows/logs no keys/credentials; only image + EXIF date/location. Keychain usage unchanged. | ✅ |
| IV. Transport-Layer Security | Untouched — the new endpoints use the same default URLSession / `x-api-key` as 001; no TLS exception. | ✅ (n/a) |
| V. Respect Platform Boundaries | Brightness live foreground only; auto-advance/keep-awake released on background; status bar follows the chrome. | ✅ |
| VI. Verifiable Acceptance Criteria | Spec gives measurable SC-001…SC-007; quickstart.md maps them onto host/UI tests. | ✅ |
| VII. Calm and Bright by Default | Default overlay-free (no chrome/clock/status bar); all extras opt-in / on tap, auto-hide. | ✅ |

**Result: PASS — no violations, no complexity exceptions needed.**

## Project Structure

### Documentation (this feature)

```text
specs/007-slideshow-ui/
├── plan.md  research.md  data-model.md  quickstart.md  contracts/  checklists/  tasks.md
```

### Source Code (repository root)

```text
Packages/
├── SlideshowKit/Sources/SlideshowKit/
│   └── SlideshowViewModel.swift          # + showNext/showPrevious/jump(to:)/togglePause/isPaused (US1); reuses switchAlbum + mutable albumID (from feature 005) for US2
├── SlideshowKit/Tests/SlideshowKitTests/
│   └── SlideshowViewModelTests.swift     # + step/wrap/pause/jump/switchAlbum tests
├── ImmichClient/Sources/ImmichClient/
│   ├── ImmichAPI.swift                    # + assetInfo(assetID:)->AssetInfo, thumbnail(assetID:)->Data
│   ├── ImmichClient.swift                 # impl of the two endpoints (x-api-key, size query)
│   └── Models.swift                       # + AssetInfo, AssetDetail/ExifInfo decoding
└── ImmichClient/Tests/ImmichClientTests/
    ├── AssetInfoTests.swift               # EXIF decode + localDateTime fallback
    └── PreviewTests.swift                 # thumbnail/preview size query

Immich Slideshow/                          # app target
├── Slideshow/
│   ├── SlideshowView.swift                # tap/swipe gestures, chrome visibility + auto-hide, sheets (US1)
│   ├── SlideshowChrome.swift              # NEW — top/bottom Liquid Glass bars (US1)
│   ├── AlbumBrowserView.swift             # NEW — album/thumbnail grid as a sheet (US2)
│   ├── PhotoInfoView.swift               # NEW — date/location overlay from AssetInfo (US3)
│   └── SlideshowSettingsView.swift        # NEW — brightness live + planned options (US4)

Immich SlideshowUITests/
├── SlideshowChromeUITests.swift           # NEW (US1) — reveal/auto-hide/swipe/transport
├── AlbumBrowserUITests.swift              # NEW (US2)
├── PhotoInfoUITests.swift                 # NEW (US3)
└── SettingsUITests.swift                  # NEW (US4)
```

**Structure Decision**: No new package boundary. The control logic belongs to slideshow behavior and
lands in `SlideshowKit` (VM); the data fetch (EXIF/thumbnail) belongs to the REST client and lands in
`ImmichClient`. The views themselves are app-target SwiftUI (they need iOS 26 Liquid Glass and the
simulator to verify), consistent with the existing `SlideshowView`. This keeps the testable logic
host-side (`swift test`) and confines simulator need to pure presentation.

## Complexity Tracking

> No constitution violations — section intentionally empty.
