# Research: Display & Playback Options (ThemeSettings)

Phase 0 design decisions. No open `NEEDS CLARIFICATION` — the product decisions were resolved in the
2026-06-22 interview; the items below are technical-approach choices.

## D1 — Where ThemeSettings lives

- **Decision**: New Foundation-only SPM leaf package **`ThemeKit`** holding the settings value types and
  store. `SlideshowKit` depends on `ThemeKit`; the app target depends on both.
- **Rationale**: Constitution II (modular isolation). Both the engine and the app UI need one source of
  truth; a leaf package keeps it injectable and host-testable with no `UserDefaults` and no hidden
  singleton.
- **Alternatives**: (a) Fold into `SlideshowKit` — rejected: the settings UI and clock live in the app
  target and would then import the whole engine; the value types deserve their own seam. (b) Put it in
  the app target only — rejected: `SlideshowKit` could not read order/duration/quality without a back
  channel.

## D2 — Live application of changes (no restart)

- **Decision**: `ThemeSettingsStore` is `@Observable` and injected as a single shared instance into both
  `SlideshowViewModel` and `SlideshowView`. Reads happen at the point of use: the view model reads
  `order`/`duration`/`quality` when it builds the next step; the view reads `transition`/`fit`/`clock`
  when it renders.
- **Rationale**: `@Observable` gives SwiftUI live updates for the view; the view model reads the current
  value each cycle, so a change is honored on the next advance (SC-001) without tearing down the show.
- **Alternatives**: Passing an immutable snapshot at construction — rejected: would require a restart to
  apply changes, violating FR-003/SC-001.

## D3 — Duration → ticker re-arm

- **Decision**: Replace the fixed-interval ticker with a **live-duration ticker**. The
  `SlideshowTicker` protocol stays (for test injection), but the real implementation sleeps for the
  store's *current* `duration` each cycle (a `@Sendable () -> Duration` provider, or reading the store).
  The view model's ticker loop already re-arms on manual next/prev; duration changes simply take effect
  on the next wait.
- **Rationale**: Keeps the timer logic testable (a fake ticker yields immediately) while letting the
  interval change live. This is the timing-sensitive seam the constitution/CLAUDE.md flag as
  Claude-owned test design — covered by a deterministic test with a fake clock.
- **Alternatives**: Recreating `RealTicker` on every change — rejected: races with the running detached
  ticker task; a live provider avoids reconstructing the loop. `SlideshowConfig.interval` is removed in
  favor of `ThemeSettings.duration`; `prefetchDepth`/`cacheLimit` stay in `SlideshowConfig`.

## D4 — Order: shuffle (no repeat within a cycle) vs sequential

- **Decision**: The view model owns a **play sequence** of asset indices. Sequential = album order.
  Shuffle = a randomized permutation of all indices; advancing walks the permutation to its end, then
  reshuffles (a fresh permutation, optionally avoiding the just-shown last as the next first). Switching
  order mid-show rebuilds the sequence and keeps the current photo as the cursor anchor where possible.
- **Rationale**: Satisfies FR-004/SC-004 (every photo once per cycle, reshuffle each cycle) and is
  deterministically testable with an injected RNG/seed.
- **Alternatives**: Random pick each step (with repeats) — rejected: violates "once per cycle". A
  Fisher–Yates permutation is simple and testable.

## D5 — Image quality: Preview vs Original

- **Decision**: Add `original(assetID:) async throws -> Data` to `ImmichAPI`. `ImmichClient` calls
  `GET api/assets/{id}/original`. The view model picks `original` vs `preview` from `settings.quality`.
  The protocol gets a default `original` that falls back to `preview` so existing mocks/stubs keep
  compiling.
- **Rationale**: Keeps the network seam (Constitution II/IV); the default impl avoids touching every
  test double. The exact path is verified against the running Immich OpenAPI (`/api/server/version`)
  before wiring — Immich serves the full asset at `assets/{id}/original`.
- **Alternatives**: A larger `thumbnail?size=` value — rejected: Immich's preview is already the largest
  thumbnail size; only `original` gives full resolution.
- **Open verification (cheap, at implementation time)**: confirm `assets/{id}/original` against the
  live server's OpenAPI; if the running version differs, adjust the path in `ImmichClient` only.

## D6 — Transitions & Ken Burns

- **Decision**: Crossfade stays the default. Slide/dissolve/none are SwiftUI transitions/animations on
  the image-swap. Ken Burns is an opt-in modifier that slowly scales+translates the current image over
  that photo's duration. With `fit = Fit`, Ken Burns applies a small base scale so no letterbox gap is
  revealed; with `fit = Fill` it pans within the already-cropped frame.
- **Rationale**: Pure SwiftUI, no new dependency; defaults preserve the calm crossfade (Constitution
  VII). Visual correctness is verified in the simulator/preview (UI test + screenshot), not host logic.
- **Alternatives**: A third-party transition library — rejected: avoid dependencies; SwiftUI suffices.

## D7 — Image fit: Fit vs Fill

- **Decision**: Branch the render: `Fit` → `.scaledToFit()` (current); `Fill` → `.scaledToFill()` +
  `.clipped()`, fullscreen. Default Fit.
- **Rationale**: One-line behavioral switch; matches FR-008. Verified visually in the simulator.

## D8 — Clock overlay

- **Decision**: New `ClockOverlayView` in the app target, gated on `settings.clock.isOn` (default off).
  Uses `TimelineView(.periodic)` for a once-a-minute time tick; optional date line; corner from
  `settings.clock.corner`. Rendered above the image, below the reveal-on-tap chrome.
- **Rationale**: Opt-in, calm default (Constitution VII); `TimelineView` avoids a manual timer.
- **Alternatives**: A `Timer`-driven `@State` — rejected: `TimelineView` is the idiomatic, leak-free
  SwiftUI approach.

## D9 — Persistence shape

- **Decision**: Store each field under a namespaced `UserDefaults` key (e.g. `theme.order`,
  `theme.durationSeconds`, …) via `UserDefaultsThemeStore`. Unknown/partial/corrupt values fall back to
  the documented defaults (FR-013). Enums persist by stable string rawValue.
- **Rationale**: Forward-compatible, debuggable, and each field degrades independently. No `Codable`
  blob that fails wholesale on one bad field.
