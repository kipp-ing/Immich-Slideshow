# Tasks: Slideshow UI (native iPadOS 26 chrome, Liquid Glass)

**Input**: Design documents from `/specs/007-slideshow-ui/`

**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓

**Status**: As-built changelog (retroactive). The implementation shipped before this spec, so this is
**not** a forward TDD task plan — it records what each slice delivered, grouped by user story, with the
shipping commit and an explicit **added vs. reused** split. TDD (red → green) was followed within each
slice at build time; it is not re-asserted here as if the work were still ahead.

## Format

- Grouped by user story (= shipped slice). `[X]` = shipped. Each slice lists what it **added** and what
  it **reused** (so the commit attribution is honest). Paths relative to the repo root.

**Orchestration** (CLAUDE.md): the host-testable logic (VM additions in `SlideshowKit`, client
endpoints in `ImmichClient`) is the delegable part (`swift test`); the SwiftUI views + gestures, the
ticker timing/shared state, status-bar wiring, and all simulator/XCUITest verification stayed inline.

---

## US1 — Control chrome + gestures (P1, MVP) — `52e4c5e` (stabilized in `df23680`)

Reveal-on-tap top/bottom Liquid Glass bars with ~4.5 s auto-hide, swipe-to-advance, transport.

**Added (VM, `SlideshowKit/…/SlideshowViewModel.swift`):** `showNext()`, `showPrevious()`,
`jump(to:)`, `togglePause()`, `isPaused`, shared `step(by:)` + auto-advance timer reset.

- [X] VM tests (`SlideshowViewModelTests.swift`): `showNextStepsForwardAndResetsTicker`,
  `showPreviousStepsBackwardAndWraps`, `togglePauseStopsTickerAndSurvivesForegroundResume`,
  `jumpGoesToRequestedAssetAndIgnoresUnknown`, `singleImageAlbumRemainsStableOnTick`. — `52e4c5e`
- [X] `SlideshowChrome.swift` (app target) — top + transport bars, `glassEffect`/`.buttonStyle(.glass)`,
  a11y IDs. — `52e4c5e`
- [X] `SlideshowView.swift` — tap-toggle + horizontal `DragGesture`, chrome visibility + auto-hide
  `Task`, status bar / home indicator follow the chrome. — `52e4c5e`
- [X] XCUITests (`SlideshowChromeUITests.swift`): `testChromeHiddenByDefaultAndRevealsOnTap`,
  `testChromeAutoHidesWhenIdle`, `testSwipeAdvancesWithoutRevealingChrome`,
  `testTransportAndPlayPauseToggle`. — `52e4c5e`
- [X] Reset moved to the chrome exit button; redundant long-press removed; UI tests stabilized.
  — `df23680`

**Reused:** none — this slice introduced the control surface (`jump` lands here even though its first
consumer beyond swipe/transport is US2's browser).

---

## US2 — Album browser sheet (P2) — `1af7466`

Liquid Glass album browser over the running slideshow; tap a thumbnail to switch source + jump.

**Added:** `ImmichAPI.thumbnail(assetID:)` + impl (smaller-than-preview size query, `x-api-key`);
`AlbumBrowserView.swift` (album grid → `AlbumThumbnailGrid` → `ThumbnailCell`; loading/empty/error);
`SlideshowView` albums-sheet wiring (on album mismatch `switchAlbum`, then always `jump`).

- [X] Client test `thumbnailSendsGetRequestWithThumbnailSizeQueryAndReturnsRawData`
  (`ImmichClientTests/PreviewTests.swift`). — `1af7466`
- [X] XCUITest `testAlbumBrowserOpensDrillsInAndSelectionReturnsToSlideshow`
  (`AlbumBrowserUITests.swift`). — `1af7466`

**Reused (NOT added here):** `jump(to:)` — from US1 (`52e4c5e`); `switchAlbum(_:)` and the mutable
`albumID` — from **feature 005** (`3d973ab`), where they were added for HA remote control. The browser
is simply the second consumer of `switchAlbum`. Their VM tests
(`jumpGoesToRequestedAssetAndIgnoresUnknown` in `52e4c5e`, `switchAlbumLoadsNewAlbumAndExposesCurrentAlbumID`
in `3d973ab`) predate this slice.

---

## US3 — Photo-info overlay (P3) — `a2c36b1`

Date/location of the current photo from EXIF; renders nothing when absent.

**Added:** `AssetInfo` + `AssetDetail`/`ExifInfo` decoding (`Models.swift`);
`ImmichAPI.assetInfo(assetID:)` + impl (date fallback `localDateTime`/`fileCreatedAt`);
`PhotoInfoView.swift` (lazy `.task(id: assetID)`, date/location lines, quiet when empty), wired as a
`SlideshowView` overlay.

- [X] Client tests `assetInfoSendsGetRequestWithAPIKeyHeaderAndReturnsDecodedInfo`,
  `assetInfoWithoutExifFallsBackToLocalDateTimeAndNilLocation` (`AssetInfoTests.swift`). — `a2c36b1`
- [X] XCUITest `testInfoButtonTogglesDateAndLocationOverlay` (`PhotoInfoUITests.swift`). — `a2c36b1`

**Reused:** `currentAssetID` (existing VM state, 003/005) drives the overlay reload on advance.

---

## US4 — Settings shell (P4) — `b41ed4d`

Settings sheet with live brightness (PowerManager/004); planned options as a disabled preview.

**Added:** `SlideshowSettingsView.swift` — brightness `Slider` → `PowerManager.setBrightness` (live),
initial value from the active window scene; disabled placeholder rows (duration/transition/Ken Burns/
order/image fit/clock) with a hint pointing to ThemeSettings; `SlideshowView` settings-sheet wiring.

- [X] XCUITest `testSettingsShowsBrightnessAndPlannedOptionsAndDismisses` (`SettingsUITests.swift`) —
  asserts the slider is **present and adjustable** and a planned row is previewed. It cannot read
  `UIScreen.brightness`, so the **live brightness change is not asserted** — it rests on the
  `PowerManager.setBrightness` wiring (see SC-006 in quickstart.md). — `b41ed4d`

**Reused:** `PowerManager` (feature 004) for the live brightness.

---

## Polish — `df23680`

- [X] UI-test stabilization (ticker timing / shared state): removed the redundant long-press, pinned
  the chrome `--uitest` seams (no auto-hide in tests).
- [X] Full simulator run (`test_sim`, scheme "Immich Slideshow") green; host suites (`SlideshowKit`,
  `ImmichClient`) green via `swift test`.
- [X] Default review (Constitution VII): overlay-free default confirmed (SC-001/SC-007).

---

## Build order (as shipped)

US1 (`52e4c5e`, control surface incl. `jump`) → US2 (`1af7466`, browser + `thumbnail`; reuses `jump`
from A and `switchAlbum`/mutable `albumID` from 005) → US3 (`a2c36b1`, EXIF + overlay) → US4
(`b41ed4d`, settings) → Polish (`df23680`).

Next: specify the ThemeSettings module (#5) that activates the disabled options from US4; optionally
persist the runtime-chosen album (the open item in data-model.md).
