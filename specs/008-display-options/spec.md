# Feature Specification: Display & Playback Options (ThemeSettings)

**Feature Branch**: `008-display-options`

**Created**: 2026-06-22

**Status**: Draft

**Input**: Implements the **ThemeSettings module (#5)** from `CLAUDE.md` and the feature-interview
decisions recorded 2026-06-22 in `specs/003-slideshow` (User Story 4 & 5; FR-014..FR-018) and
`specs/007-slideshow-ui` (User Story 5 & 6; FR-017, FR-019, FR-022). Those specs remain the canonical
record of the decisions; this feature is the focused implementation vehicle for the first buildable
milestone. Make the slideshow's display/playback parameters user-configurable and persistent, and
wire the currently-disabled rows in the settings screen to live behavior.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Adjust order and timing, persisted and applied live (Priority: P1) 🎯 MVP

The user opens settings and changes how the slideshow plays: the **order** (shuffle or sequential)
and the per-photo **duration**. The change takes effect on the already-running slideshow immediately,
and it is remembered across app restarts. Shuffle is the default — the frame no longer replays the
same album order every loop or restarts on the same photo every time.

**Why this priority**: Order and duration are the highest day-to-day-value knobs for an ambient frame,
and they require the settings store + live-apply plumbing that every other story in this feature reuses.
This is the minimal slice that makes the dead settings rows real.

**Independent Test**: Open settings, set order = shuffle and a duration → the running slideshow advances
on the new interval and visits photos in a randomized, no-repeat-within-a-cycle order; relaunch the app
→ the choices persist. Set order = sequential → photos play in album order.

**Acceptance Scenarios**:

1. **Given** the default install, **When** the slideshow first runs, **Then** order = shuffle and
   duration = 15 s without the user configuring anything.
2. **Given** the settings screen, **When** the user changes the duration, **Then** the running
   slideshow's auto-advance uses the new duration without a restart.
3. **Given** order = shuffle, **When** the slideshow runs a full cycle, **Then** every photo is shown
   once before any repeats, and the next cycle uses a fresh shuffle.
4. **Given** order = sequential, **When** the slideshow runs, **Then** photos appear in album order.
5. **Given** any changed option, **When** the app is relaunched, **Then** the previously chosen values
   are still in effect (persisted).

---

### User Story 2 - Choose transition and Ken Burns motion (Priority: P2)

The user selects how the slideshow moves between photos: the **transition** (crossfade, slide, dissolve,
or none) and an optional **Ken Burns** slow pan/zoom on the displayed photo. Both default to the calm
current behavior (crossfade, Ken Burns off).

**Why this priority**: Transitions and motion are the signature "living frame" feel, but the slideshow
already works without them; builds on the store from US1.

**Independent Test**: Select each transition and toggle Ken Burns → the running slideshow applies the
chosen transition on the next advance, and the motion runs (or doesn't) per the toggle; the choices
persist.

**Acceptance Scenarios**:

1. **Given** the default install, **When** the slideshow advances, **Then** a crossfade is used and no
   Ken Burns motion is applied (calm default preserved).
2. **Given** a selected transition, **When** the slideshow advances, **Then** that transition is used.
3. **Given** Ken Burns is enabled, **When** a photo is shown, **Then** a slow pan/zoom is applied for
   the duration of that photo; disabling it returns to a static image.

---

### User Story 3 - Choose image fit and quality (Priority: P2)

The user controls how each photo fills the screen — **Fit** (whole photo, letterboxed) or **Fill**
(cropped to fill, no bars) — and the fetched image **quality** — **Preview** (light, ~1440 px) or
**Original** (full resolution, sharpest on large displays). Defaults stay Fit and Preview.

**Why this priority**: Improves how photos look on a large iPad (especially portrait photos and
high-DPI displays), but the slideshow is usable at the defaults; builds on the store from US1.

**Independent Test**: Set fit = Fill → a photo whose aspect differs from the screen is cropped to fill
with no bars; set quality = Original → the slideshow fetches the full-resolution image instead of the
preview; both choices persist.

**Acceptance Scenarios**:

1. **Given** the default install, **When** a photo is shown, **Then** it is fitted (letterboxed) and
   the preview-size image is used.
2. **Given** fit = Fill, **When** a photo's aspect differs from the screen, **Then** it is cropped to
   fill with no letterbox bars.
3. **Given** quality = Original, **When** a photo loads, **Then** the full-resolution original is
   fetched and displayed; quality = Preview uses the preview-size image.

---

### User Story 4 - Optional clock overlay (Priority: P3)

The user can enable an unobtrusive clock over the slideshow. It is **off by default** (calm default).
When on, it shows the time — and optionally the date — in a configurable corner, persistently.

**Why this priority**: A common photo-frame nicety; opt-in so the default stays calm. Builds on the
store from US1.

**Independent Test**: Enable the clock and pick a corner → a time overlay appears there; toggle the
date → the date appears; disable → no overlay; choices persist.

**Acceptance Scenarios**:

1. **Given** the default install, **When** the slideshow runs, **Then** no clock is shown.
2. **Given** the clock is enabled with a chosen corner, **When** the slideshow runs, **Then** the
   current time (and the date, if enabled) shows in that corner.
3. **Given** the clock is disabled, **When** the slideshow runs, **Then** the overlay is gone.

---

### Edge Cases

- **Duration changed while a photo is mid-display**: the new duration applies from the next advance;
  the current photo is not cut short or frozen.
- **Order switched shuffle↔sequential mid-show**: the change takes effect without restarting the show
  or losing the current photo; the next advance follows the new order.
- **Ken Burns + Fit**: Ken Burns is meaningful with Fill framing; with Fit it must still behave
  gracefully (no jarring jump or revealed background) — see Assumptions.
- **Original quality fails or is slow**: a failed/too-slow original load is handled like any load
  failure (skip/keep current per existing slideshow behavior); it must not blank or freeze the frame.
- **Single-image album**: order and transitions stay stable on the one image (no crash, no flicker).
- **Corrupt/missing stored settings**: unreadable or partial stored values fall back to the documented
  defaults rather than failing to start.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide a persistent settings store for display/playback preferences,
  behind an injectable protocol (no hidden singleton), persisted to non-secret storage (UserDefaults).
  No secrets are stored here.
- **FR-002**: The store MUST apply these defaults on first run: order = shuffle, duration = 15 s,
  transition = crossfade, Ken Burns = off, fit = Fit, quality = Preview, clock = off.
- **FR-003**: Settings changes MUST take effect on the already-running slideshow without requiring a
  restart, and MUST persist across app launches.
- **FR-004**: The system MUST support a configurable photo **order** — shuffle (default) or sequential
  (album order). Shuffle MUST show every photo once per cycle before repeating, then reshuffle.
- **FR-005**: The system MUST support a configurable per-photo **duration** (default 15 s) within a
  sensible range; out-of-range values MUST be clamped rather than rejected.
- **FR-006**: The system MUST support a selectable **transition** — crossfade (default), slide,
  dissolve, or none.
- **FR-007**: The system MUST support an optional **Ken Burns** slow pan/zoom toggle (default off).
- **FR-008**: The system MUST support a configurable image **fit** — Fit/letterbox (default) or
  Fill/crop.
- **FR-009**: The system MUST support a configurable image **quality** — Preview (default) or Original
  (full resolution). Fetching the original full-resolution image MUST be available behind the existing
  image-source interface, alongside the existing preview fetch.
- **FR-010**: The system MUST offer an optional **clock overlay** — off by default — with a
  configurable corner and an optional date line.
- **FR-011**: The settings screen MUST replace its currently-disabled placeholder rows (duration,
  transition, Ken Burns, order, fit, quality) with live controls bound to the store; the existing live
  brightness control MUST keep working.
- **FR-012**: The default experience MUST stay calm and overlay-free (Constitution VII): every option
  above either defaults to the current behavior or is explicitly opt-in.
- **FR-013**: Invalid, partial, or unreadable stored settings MUST fall back to the documented defaults
  without preventing the slideshow from starting.

### Key Entities *(include if feature involves data)*

- **ThemeSettings**: the user's display/playback preferences — order, duration, transition, Ken Burns
  on/off, fit, quality, clock (on/off, corner, show-date). Non-secret; persisted across launches;
  read by the slideshow engine and the settings UI; supplies documented defaults when unset.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A change made in settings (order, duration, transition, Ken Burns, fit, quality, clock)
  is reflected by the running slideshow within one advance cycle, with no app restart.
- **SC-002**: 100% of the settings above survive an app relaunch (the slideshow resumes with the
  user's choices, not the defaults).
- **SC-003**: On a fresh install with no interaction, the slideshow runs with the calm defaults
  (shuffle, 15 s, crossfade, no Ken Burns, Fit, Preview, no clock) — verifiable as the documented
  defaults.
- **SC-004**: Over a full shuffle cycle, no photo repeats before every other photo has been shown.
- **SC-005**: With quality = Original, the slideshow displays the full-resolution image; with
  Preview, the preview-size image — confirmable per displayed photo.
- **SC-006**: None of the settings are stored as secrets or written to logs (settings persistence
  contains no API key or credentials).

## Assumptions

- **Source of truth**: the decisions are already recorded in `specs/003-slideshow` and
  `specs/007-slideshow-ui`; this spec restates the buildable subset and does not re-open them.
- **ThemeSettings location**: the store is a small module (its own SPM package or a clearly isolated
  unit) consumed by `SlideshowKit` and the app's settings UI via dependency injection.
- **Ken Burns with Fit**: when Ken Burns is on while fit = Fit, the motion is applied within the fitted
  frame (or the engine treats Ken Burns as implying fill-style framing) so no empty background is
  revealed; the exact approach is a plan/design decision, but it must not look broken.
- **Duration range**: a practical UI range (for example a few seconds up to several minutes) with the
  15 s default; precise bounds are a plan detail.
- **Original image source**: the Immich server can serve the original asset; the original fetch is
  added behind the existing image-source protocol without disabling TLS.
- **Single active album**: this milestone keeps the current single-album source; multi-source/Memories
  are a separate milestone (`specs/007` US8).

## Out of Scope (this milestone — deferred, already specified elsewhere)

- **Resilience**: disk-persistent cache, auto-retry with backoff, periodic source refresh, and the
  cache-size + Clear-cache settings row (`specs/003` US6, FR-019..021). The cache row stays deferred
  with that milestone.
- **Presence-driven sleep/wake** and Home-Assistant motion integration (`specs/004` US4; `specs/005` US4).
- **Multi-source albums, Memories, and the shared-link "super simple mode"** (`specs/001` US4;
  `specs/002` US4; `specs/007` US8).
- **Localization (English + German)** (`specs/007` US7).
- **Video / Live Photo playback** (stays images-only).
