# Phase 0 Research: Slideshow UI

No NEEDS-CLARIFICATION open. Decisions follow the established patterns (003-slideshow,
004-power-manager, 001-immich-client) and the handover sketch.

## 1. Control chrome: reveal on tap, auto-hide

- **Decision**: The chrome is hidden by default. A tap reveals it; a `Task`-based idle timer (~4.5 s)
  hides it again; any control interaction (`onInteraction`) resets the timer. The status bar and home
  indicator follow visibility (`.statusBarHidden`, `.persistentSystemOverlays`).
- **Rationale**: Constitution VII — the default shows only the image; controls are available on tap
  and never pushed. Carrying the system bars fixes the otherwise always-visible iPad clock/battery.
- **Alternatives considered**: Always-visible chrome (rejected — breaks the calm default); long-press
  as the entry point (rejected, see item 5).

## 2. Swipe gestures alongside tap

- **Decision**: Tap toggles the chrome; a horizontal `DragGesture` (minimumDistance 40,
  horizontal-dominant) advances forward/back **without** revealing the chrome.
- **Rationale**: Two clearly separate gestures — fast paging without a UI change (FR-004) and a
  deliberate reveal of the controls (FR-002). The separation keeps tap-to-reveal unambiguous.
- **Alternatives considered**: Swipe also reveals chrome (rejected — conflates the gestures).

## 3. VM additions for control (SlideshowKit)

- **Decision**: The forward-only `SlideshowViewModel` from 003 gains `showNext()`, `showPrevious()`,
  `jump(to:)`, and `togglePause()`. Manual steps reset the auto-advance timer; a user pause
  (`isPaused`) survives the foreground resume, while the foreground-gating `pause()`/`resume()` stays
  separate from it.
- **Rationale**: Controls need backward/jump movement and a user pause decoupled from the lifecycle.
  Timing / shared state (the ticker task) is delicate → deliberately kept inline and covered by host
  tests (Constitution I/II).
- **Alternatives considered**: Rebuild the VM on every jump (rejected — loses cache/state, expensive);
  backward movement in auto-advance (rejected — FR-006, the run stays forward).

## 4. Runtime album switch instead of VM rebuild (US2)

- **Decision**: `albumID` becomes mutable in the VM; `switchAlbum(_:)` (already present for the HA
  remote control) loads the new album, then `jump(to:)` jumps to the tapped photo. Exactly one album
  is active.
- **Rationale**: Reuses the existing remote semantics (one source of truth for "switch album"); no
  second path. Keeps the browser thin.
- **Alternatives considered**: Multiple parallel sources (rejected — out of scope, one album at a
  time).

## 5. Reset entry point: chrome exit instead of long-press

- **Decision**: The reset/configuration dialog hangs off the chrome's exit button; the former
  long-press recognizer on the image was removed (`df23680`).
- **Rationale**: With tap-to-reveal, an extra long-press would make gesture recognition ambiguous; the
  exit button is the natural, visible place.
- **Alternatives considered**: Keep long-press (rejected — redundant and gesture-ambiguous).

## 6. Thumbnails: dedicated smaller endpoint (US2)

- **Decision**: `thumbnail(assetID:)` complements `preview(assetID:)` and requests a smaller image
  size via the Immich size query; the browser grid uses thumbnails, fullscreen uses the preview.
- **Rationale**: FR-009 — a grid with many images should not load the full preview per cell.
- **Alternatives considered**: Reuse the preview in the grid (rejected — too expensive/too large).

## 7. EXIF data model for the info overlay (US3)

- **Decision**: A new `assetInfo(assetID:)` endpoint returns an `AssetInfo` (`takenAt`, `city`,
  `state`, `country`), decoded from Immich `exifInfo.dateTimeOriginal`/`city`/`state`/`country` with a
  fallback to `localDateTime`/`fileCreatedAt` for the date. The overlay loads lazily via
  `.task(id: assetID)` and renders nothing when both date **and** location are absent.
- **Rationale**: The only slice that touches the data path (`Asset` was just `{id,type}`). FR-010/
  FR-011 — only date/location, quiet when empty.
- **Alternatives considered**: Pass through the full Immich `AssetResponse` (rejected — too broad; a
  narrow display model is enough and stays testable).

## 8. Settings as a shell now (US4)

- **Decision**: The settings screen wires up only brightness (PowerManager/004) live; the remaining
  options are disabled placeholder rows with default values and a hint that they activate with the
  ThemeSettings module.
- **Rationale**: Delivers a real control and an extensible frame immediately, without waiting on the
  not-yet-specified ThemeSettings module (#5) (FR-012/FR-013).
- **Alternatives considered**: Wait for ThemeSettings (rejected — delays every UI value); functionless
  but operable controls (rejected — fakes an effect).

## 9. Liquid Glass look (iPadOS 26)

- **Decision**: `glassEffect`, `GlassEffectContainer`, and `.buttonStyle(.glass)` for bars, cards, and
  overlays. The app scheme builds only on iOS 26.x simulators.
- **Rationale**: Native iPadOS 26 look close to the Photos / Immich apps, without custom material
  reimplementations.
- **Alternatives considered**: `.ultraThinMaterial` reimplementation (rejected — not the real Liquid
  Glass look).

## 10. Verification

- **Decision**: VM additions and client endpoints host-tested (`swift test`, `MockTransport`/
  in-memory). Chrome, browser, info overlay, settings via hermetic XCUITest with `--uitest-*` launch
  arguments that present the chrome/sheets deterministically and without auto-hide.
- **Rationale**: There are no MCP tap tools for this project; the repeatable, committed UI
  verification is XCUITest (cf. `docs/testing.md`). Logic stays host-fast.
