# Contract: SlideshowKit consumes ThemeSettings

How the slideshow engine reads live settings. `SlideshowViewModel` takes an injected
`ThemeSettingsStore` (or a settings provider) plus the existing `ImmichAPI`, ticker, and cache.

## Order / play sequence

| # | Given | When | Then |
|---|-------|------|------|
| 1 | `order = sequential`, album `[A,B,C]` | advance repeatedly | visits A,B,C,A,B,C… (album order, wrapping) |
| 2 | `order = shuffle` (seeded RNG), album of n | advance through one cycle | every photo shown exactly once before any repeat — SC-004 |
| 3 | `order = shuffle`, a cycle completes | advance again | a fresh permutation begins (new cycle) |
| 4 | order switched mid-show | next advance | sequence rebuilt for the new order; current photo stays the anchor where possible |

## Duration / ticker

| # | Given | When | Then |
|---|-------|------|------|
| 5 | `duration = 15 s` | auto-advance runs (fake clock) | the wait between advances equals the current duration |
| 6 | duration changed while playing | next wait | uses the new duration without restarting the show — SC-001 |
| 7 | user paused (chrome) | duration changes | stays paused; no auto-advance (existing pause semantics preserved) |

## Quality / fetch selection

| # | Given | When | Then |
|---|-------|------|------|
| 8 | `quality = preview` | a photo loads | engine calls `preview(assetID:)` (current behavior) |
| 9 | `quality = original` | a photo loads | engine calls `original(assetID:)` |
| 10 | quality changed | next loaded photo | uses the newly selected endpoint (subsequent fetches; already-cached frames may keep their data) |

## Notes

- `transition`, `fit`, `kenBurns`, and `clock` are **not** read by the engine — they are render-time
  concerns owned by `SlideshowView` (see plan). The engine only needs `order`, `duration`, `quality`.
- The ticker remains behind the `SlideshowTicker` protocol; tests inject a fake that yields immediately
  and assert the requested interval, keeping timing deterministic (Claude-owned timing seam).
