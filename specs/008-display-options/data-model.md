# Data Model: Display & Playback Options (ThemeSettings)

All types live in the new `ThemeKit` package, are `Sendable`/`Equatable`, and persist by stable string
rawValues. No secrets. These are conceptual shapes for planning; exact Swift signatures are produced
test-first in tasks.

## Entity: ThemeSettings

The user's display/playback preferences — the single source of truth read by the engine and the UI.

| Field        | Type            | Default            | Notes |
|--------------|-----------------|--------------------|-------|
| `order`      | `PlayOrder`     | `.shuffle`         | shuffle = no repeat within a cycle; sequential = album order |
| `duration`   | `Duration`      | `.seconds(15)`     | clamped to `durationRange` |
| `transition` | `Transition`    | `.crossfade`       | crossfade / slide / dissolve / none |
| `kenBurns`   | `Bool`          | `false`            | opt-in slow pan/zoom |
| `fit`        | `ImageFit`      | `.fit`             | fit (letterbox) / fill (crop) |
| `quality`    | `ImageQuality`  | `.preview`         | preview (~1440 px) / original (full-res) |
| `clock`      | `ClockSettings` | `.off`             | overlay, off by default |

- **Defaults** correspond to spec FR-002 and the calm default (Constitution VII).
- **`durationRange`** (committed): **3 s … 600 s**. Out-of-range values are clamped, not rejected
  (FR-005). The settings UI may surface a subset as presets (e.g. 5 s, 10 s, 15 s, 30 s, 1 m, 5 m).
- **Validation/fallback**: any unreadable/partial persisted field falls back to its default (FR-013);
  fields are independent (one bad value does not reset the others).

## Enum: PlayOrder

- `shuffle` (default), `sequential`. RawValue: `"shuffle"`, `"sequential"`.

## Enum: Transition

- `crossfade` (default), `slide`, `dissolve`, `none`. RawValue: lowercase names.

## Enum: ImageFit

- `fit` (default), `fill`. RawValue: `"fit"`, `"fill"`.

## Enum: ImageQuality

- `preview` (default), `original`. RawValue: `"preview"`, `"original"`.

## Value: ClockSettings

| Field      | Type          | Default            | Notes |
|------------|---------------|--------------------|-------|
| `isOn`     | `Bool`        | `false`            | overlay off by default |
| `corner`   | `ClockCorner` | `.bottomTrailing`  | which corner |
| `showDate` | `Bool`        | `false`            | optional date line |

- **`ClockCorner`**: `topLeading`, `topTrailing`, `bottomLeading`, `bottomTrailing`.
- `.off` convenience = `isOn: false` with defaults.

## Derived behavior (not stored): Play sequence

Owned by `SlideshowViewModel`, derived from `order` + the loaded asset list:

- **sequential** → indices `0..<n` in order, wrapping.
- **shuffle** → a random permutation of `0..<n`; on exhausting it, a fresh permutation (a new cycle).
  Tested with an injected seed/RNG for determinism (SC-004).
- Switching `order` rebuilds the sequence; the currently shown photo stays the cursor anchor where
  possible (Edge Case: order switch mid-show).

## Persistence keys (UserDefaults, non-secret)

`theme.order`, `theme.durationSeconds`, `theme.transition`, `theme.kenBurns`, `theme.fit`,
`theme.quality`, `theme.clock.isOn`, `theme.clock.corner`, `theme.clock.showDate`.

## Relationships

- `SlideshowViewModel` reads `order`, `duration`, `quality` (and rebuilds the play sequence / re-arms
  the ticker / selects the fetch endpoint).
- `SlideshowView` reads `transition`, `fit`, `kenBurns`, `clock` for rendering.
- `SlideshowSettingsView` reads/writes the whole `ThemeSettings` via the store.
- `SlideshowConfig` keeps `prefetchDepth` and `cacheLimit`; `interval` is superseded by
  `ThemeSettings.duration`.
