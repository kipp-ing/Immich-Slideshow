# Quickstart: Validate Display & Playback Options

How to prove the feature works end to end. Logic is validated host-side with Swift Testing; UI/visual
behavior is validated in the simulator via XcodeBuildMCP (per CLAUDE.md, Claude owns the simulator gate).

## Prerequisites

- The packages build: `ThemeKit` (new), `SlideshowKit`, `ImmichClient`.
- A configured app (onboarding complete) or the hermetic `--uitest` build with a stub API + in-memory
  stores.

## Layer 1 — Package logic (host, fast)

Run per package with Swift Testing:

- **ThemeKit**: defaults match data-model; round-trip persistence (`UserDefaultsThemeStore` with a
  test suite name); corrupt/partial values fall back to defaults; duration clamping.
- **SlideshowKit**: sequential vs shuffle sequence (seeded RNG → no repeat within a cycle); duration
  drives the (fake) ticker wait and re-arms live; quality selects `preview` vs `original`.
- **ImmichClient**: `original(assetID:)` builds `GET api/assets/{id}/original` with `x-api-key`; the
  protocol default falls back to `preview`.

Expected: all green via XcodeBuildMCP (`test_sim` for the app-hosted suite; host `swift test` for pure
logic).

## Layer 2 — App / UI (simulator, XcodeBuildMCP)

Drive the hermetic build (reuse the `--uitest` seam; add `--uitest-settings` to open settings):

1. **Defaults / calm start**: launch fresh → slideshow runs, no clock, fitted image, crossfade,
   ~15 s advance (SC-003).
2. **Order**: settings → set Sequential → photos follow album order; set Shuffle → order randomizes,
   no immediate repeats.
3. **Duration**: change the duration → the running show advances on the new interval without restart
   (SC-001).
4. **Transition / Ken Burns**: pick slide/dissolve/none → next advance uses it; toggle Ken Burns →
   slow pan/zoom appears; off → static. Screenshot to confirm.
5. **Fit**: toggle Fill → a portrait photo fills the screen with no bars; Fit → letterboxed.
6. **Quality**: switch to Original → full-res image loads (visibly sharper on the large display).
7. **Clock**: enable → time shows in the chosen corner; toggle date; disable → gone.
8. **Persistence**: change several options, relaunch → choices survive (SC-002).

## Done / acceptance mapping

- US1 → steps 2, 3, 8 · US2 → step 4 · US3 → steps 5, 6 · US4 → step 7.
- SC-001 step 3 · SC-002 step 8 · SC-003 step 1 · SC-004 Layer-1 shuffle test · SC-005 step 6 ·
  SC-006 Layer-1 persistence inspection.
