# Handover — Slideshow UI (iOS 26, native, photo-frame)

> **Status: shipped on branch `007-slideshow-ui` (Slices A–D).** This started as a
> design-only handover (2026-06-19) and has since been implemented. It now documents
> what was built, what each slice delivered, and the one item deliberately deferred.
> Updated: 2026-06-22.
>
> **Process note:** the UI work landed on branch `007-slideshow-ui` *without* a formal
> `specs/007-*` folder. The design record is this handover plus the existing
> `003-slideshow` (slideshow engine) and `004-power-manager` (brightness) specs; the
> ImmichClient EXIF/thumbnail additions extend `001-immich-client`. A retroactive
> spec-kit feature can still be backfilled if we want the SDD trail complete.

## Goal

Native **iPadOS 26** UI for the Immich slideshow app, **full Liquid Glass**, lean and
extendable, feeling close to the Photos app and the Immich app. Keep the calm,
overlay-free default of the existing slideshow (Konstitution VII) — all chrome is opt-in /
reveal-on-demand.

## Baseline before this work (as of `ca0b4ca`, branch 003-slideshow)

- **SlideshowKit** (`Packages/SlideshowKit`): `SlideshowViewModel` (`@MainActor @Observable`),
  `SlideshowTicker`/`RealTicker`, LRU `ImageCache`, `SlideshowConfig` (interval 8s,
  prefetchDepth 2, cacheLimit 5 — hard-pinned), `SlideshowPhase` (loading/playing/empty/failed).
  - VM moved **forward only**: `start()`, `advance()`, `pause()/resume()`, `retry()`. No
    `previous()`, no `jump(to:)`. `albumID` was **fixed at construction**.
- **SlideshowView**: black fullscreen, one image `scaledToFit`, 0.6s cross-fade, **only**
  interaction a long-press → "Reset configuration?" dialog.
- **Onboarding** (3 steps) + `OnboardingKit`. **ImmichClient**: `albums()`, `assets(albumID:)`,
  `preview(assetID:)`. `Asset` model = **only `{ id, type }`** (no date/location/EXIF).
- App entry `Immich_SlideshowApp` → `RootView` routes onboarding ↔ slideshow on `step == .done`.

## Design decisions (locked, now implemented)

**Model:** Slideshow-first / photo frame. App opens straight into the running slideshow.
Tap reveals Liquid Glass chrome; Albums + Settings reached from there.

**Default state stays calm:** chrome hidden, no clock, no info overlay, image **fit (letterbox)**
by default. Everything below is opt-in or reveal-on-demand.

**Revealed chrome — top + bottom split, auto-hides after ~4.5s idle:**
- Top glass bar: exit · photo info · albums · settings
- Bottom glass bar: previous · play/pause · next
- **Swipe** left/right on the photo advances next/prev *without* revealing chrome.

**Photo-info overlay (top bar):** date/time · location. (No filename, no album name.)

**Image fit:** fit (letterbox), centered. (Fill pairs with future Ken Burns.)

**Albums browser:** Liquid Glass **sheet over the running slideshow** (show keeps playing
behind). Album grid → tap album → its photo thumbnail grid → **tap a thumbnail starts the
slideshow there** and returns to fullscreen. **One album** is the active source at a time.

**Settings screen:** brightness live now; display duration · transition + Ken Burns ·
shuffle/order · clock overlay shown as a disabled wishlist until ThemeSettings lands.

## Delivered slices

- **Slice A — Chrome + gestures** (`52e4c5e`). Reveal-on-tap top/bottom Liquid Glass bars
  with ~4.5s auto-hide, swipe-to-advance. VM gained `showNext()`, `showPrevious()`,
  `jump(to:)`, `togglePause()` (manual steps reset the auto-advance timer; backward motion
  lives only here). The status bar / home indicator now follow the chrome, so the calm
  default is truly overlay-free. Long-press was later dropped (`df23680`) — reset moved to
  the chrome's exit button, keeping tap-to-reveal unambiguous.
- **Slice B — Album browser sheet** (`1af7466`). `AlbumBrowserView` (album grid → thumbnail
  grid → tap to start). Needed **runtime album switching** (`SlideshowViewModel.switchAlbum`,
  reusing the HA-remote semantics) and a dedicated **`thumbnail(assetID:)`** endpoint on
  `ImmichClient` so the grid stays cheap.
- **Slice C — Photo-info overlay** (`a2c36b1`). `PhotoInfoView` shows date/time + location,
  fetched lazily via the new **`assetInfo(assetID:)`** endpoint and `AssetInfo` model
  (`takenAt`, `city`, `state`, `country`) decoded from Immich `exifInfo`. Renders nothing
  when a photo carries no usable info, preserving the calm default. This was the only slice
  touching the API/data model.
- **Slice D — Settings shell** (`b41ed4d`). `SlideshowSettingsView` reached from the chrome.
  **Brightness is live** (backed by PowerManager / 004); duration/transition/Ken Burns/order/
  clock are disabled placeholder rows that light up when **ThemeSettings (#5)** lands.

## Resolved open questions

- **Where the UI work landed:** branch `007-slideshow-ui`, no formal spec folder (see process
  note above). 006 was taken by broker-setup before this work started.
- **Sequencing vs. PowerManager (004):** built the settings/brightness UI now as a shell;
  brightness is already wired to 004, the rest waits on ThemeSettings (#5).
- **Info-overlay appetite:** taken on now — the ImmichClient EXIF extension shipped in Slice C
  rather than being deferred.
- **Architecture:** views live in the app target under `Immich Slideshow/Slideshow/`; the VM
  and data-model changes went into the existing `SlideshowKit` / `ImmichClient` packages
  (no new package was needed).

## Still open / future work

- **ThemeSettings (#5)** is still unspecced; the Settings placeholder rows stay inert until
  it lands. Duration/transition/Ken Burns/shuffle/clock-overlay all depend on it.
- **Backfill a retroactive spec** for the UI if we want the SDD trail complete.
- **Album choice is runtime-only (deferred).** Switching album from the browser calls
  `switchAlbum`/`jump` at runtime but is **not persisted to config**, matching the existing
  `switchAlbum` semantics — a relaunch returns to the onboarded album, not the last-picked
  one. Left as-is for now; if we want a relaunch to remember the last-picked album, persist
  the chosen `albumID` to the config store on select and read it back at startup.

## Process notes

- SDD project: normally **no feature code without spec → plan → tasks.** This handover plus the
  003/004/001 specs are the standing design record for the shipped UI.
- Constitution: TDD first; calm default; no secrets in code/UserDefaults/logs; no TLS bypass;
  touch only in-scope files; stage with explicit paths.
