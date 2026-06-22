# Feature Specification: Slideshow UI (native iPadOS 26 chrome, Liquid Glass)

**Feature Branch**: `007-slideshow-ui`

**Created**: 2026-06-19 (design sketch) · specified 2026-06-22

**Status**: Implemented — documented retroactively. Slices A–D shipped on `007-slideshow-ui`
(commits `52e4c5e`, `1af7466`, `a2c36b1`, `b41ed4d`, `df23680`); this spec was backfilled from the
handover sketch (`docs/handover-slideshow-ui.md`, now removed) to complete the SDD trail
(spec → plan → tasks).

**Input**: Native iPadOS 26 UI for the Immich slideshow in the **Liquid Glass** style, close to the
Photos / Immich apps, lean and extensible. The calm, overlay-free photo-frame default (Constitution
VII) stays: everything interactive is opt-in or revealed on tap.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Reveal-on-tap chrome + swipe gestures (Priority: P1) 🎯 MVP

The app opens straight into the running slideshow (photo frame). A tap on the photo reveals
unobtrusive Liquid Glass chrome — a top bar (exit · photo info · albums · settings) and a bottom
transport bar (previous · play/pause · next). Without interaction the chrome auto-hides after a short
idle. A horizontal swipe advances forward/back **without** revealing the chrome.

**Why this priority**: This is the minimal slice that makes the slideshow operable at all (advance,
pause, later reach albums/settings) without breaking the calm default. Every other story depends on
the chrome as its entry point.

**Independent Test**: In the hermetic `--uitest` build, start the slideshow → no chrome visible; tap
→ chrome appears; wait ~4–5 s → chrome hides; swipe left/right → image changes without chrome;
play/pause → auto-advance stops/starts.

**Acceptance Scenarios**:

1. **Given** the slideshow runs in the default, **When** the user does nothing, **Then** neither
   chrome nor the system status bar / home indicator is visible (only the image, fitted and centered).
2. **Given** the slideshow runs, **When** the user taps the image once, **Then** the top and bottom
   Liquid Glass bars appear; another tap hides them again.
3. **Given** the chrome is revealed, **When** the user does not interact for ~4.5 s, **Then** the
   chrome auto-hides; any control interaction resets the countdown.
4. **Given** the slideshow runs, **When** the user swipes horizontally, **Then** the image advances
   forward (left) or back (right) **without** revealing chrome.
5. **Given** the chrome is visible, **When** the user taps play/pause, **Then** auto-advance stops and
   stays paused across background→foreground; manual previous/next still works.

---

### User Story 2 - Album browser over the running slideshow (Priority: P2)

From the chrome the user opens a Liquid Glass album browser as a sheet **over** the still-running
slideshow. An album grid drills into a photo thumbnail grid on tap; tapping a thumbnail starts the
slideshow at that photo and returns to fullscreen. Exactly one album is the active source at a time.

**Why this priority**: Changing the shown collection is the next most valuable capability after basic
operation; builds on the chrome (US1).

**Independent Test**: Chrome → open albums → tap album → tap thumbnail → sheet closes, fullscreen
shows the chosen photo; if it was a different album, that album is now the active source.

**Acceptance Scenarios**:

1. **Given** the slideshow runs, **When** the user picks "Albums" in the chrome, **Then** a sheet with
   the album grid appears while the slideshow keeps playing behind it.
2. **Given** the album grid is open, **When** the user taps an album, **Then** its photo thumbnail
   grid appears (smaller thumbnails, not the full preview).
3. **Given** a thumbnail grid is open, **When** the user taps a photo, **Then** the sheet closes and
   the slideshow plays fullscreen starting at exactly that photo.
4. **Given** the chosen photo lives in a different album than the active one, **When** it is tapped,
   **Then** that album becomes the active source at runtime and the show jumps to the photo.

---

### User Story 3 - Photo-info overlay (date & location) (Priority: P3)

From the chrome the user reveals a Liquid Glass info overlay showing the date/time and location of the
currently shown photo — loaded from Immich EXIF. The overlay updates as the slideshow advances and
stays quiet (renders nothing) when the photo carries no usable info.

**Why this priority**: Pure added context; not needed for basic use, and the only slice that extends
the data model / ImmichClient.

**Independent Test**: Chrome → reveal info → overlay shows date + location for the current photo
(where EXIF exists); for a photo without EXIF no overlay content appears.

**Acceptance Scenarios**:

1. **Given** the slideshow shows a photo with EXIF date/location, **When** the user picks "Info" in the
   chrome, **Then** an overlay with date/time and location (city/country) appears.
2. **Given** the info overlay is visible, **When** the slideshow advances to the next photo, **Then**
   the overlay reloads the info for the new photo.
3. **Given** a photo carries no usable EXIF info, **When** the info overlay is active, **Then** it
   shows no content (no empty card, no placeholder) — the calm default holds.
4. **Given** the info overlay shows something, **When** its content is inspected, **Then** it contains
   only date/time and location — no filename and no album name.

---

### User Story 4 - Settings shell with live brightness (Priority: P4)

From the chrome the user reaches a settings screen. Brightness is live immediately (via the
PowerManager from feature 004). The remaining planned display options (duration, transition, Ken
Burns, order, image fit, clock overlay) are shown as a disabled preview and "light up" once the
ThemeSettings module (#5) exists.

**Why this priority**: Delivers one real control (brightness) and an extensible frame immediately,
without waiting on the not-yet-specified ThemeSettings module.

**Independent Test**: Chrome → settings → move the brightness slider → screen brightness changes live;
the planned options are visible but disabled.

**Acceptance Scenarios**:

1. **Given** the slideshow runs, **When** the user picks "Settings" in the chrome, **Then** a sheet
   with an active brightness slider and a list of planned display options appears.
2. **Given** the settings screen is open, **When** the user moves the brightness slider, **Then**
   screen brightness changes immediately (foreground only, Constitution V).
3. **Given** the settings screen is open, **When** the user inspects the planned options, **Then** they
   are recognizable as disabled placeholders with default values (not yet operable).

---

### User Story 5 - Settings drive real display options (Priority: P2)

> Added 2026-06-22 from the feature interview. Wires the placeholder rows from US4/FR-013 to live,
> persisted options; the engine behavior is specified in spec 003.

The settings screen's previously-disabled rows become live and persisted: **duration**, **transition**,
**Ken Burns**, **order** (shuffle/sequential), and **image fit** (Fit/Fill), plus an **image quality**
(Preview/Original) control and a **cache** section showing the size limit with a **Clear cache** button.
Changes take effect on the running slideshow.

**Why this priority**: These are the knobs the settings screen already advertises; making them real is
the core of the display-options milestone. Builds on US4.

**Independent Test**: In the hermetic `--uitest` build, open settings → change duration/transition/
order/fit/quality → values persist and the running slideshow reflects them; tap Clear cache → the
cache is emptied.

**Acceptance Scenarios**:

1. **Given** the settings screen, **When** the user changes any display option, **Then** it persists
   and the running slideshow applies it.
2. **Given** the cache section, **When** the user taps Clear cache, **Then** the on-disk cache is
   emptied and the action confirms.

---

### User Story 6 - Optional clock overlay (Priority: P3)

An unobtrusive clock can be enabled in settings. It is **off by default** (calm default). When on, it
shows the time (optionally the date) in a configurable corner, persistently over the slideshow.

**Why this priority**: A common photo-frame nicety; opt-in so the default stays calm.

**Independent Test**: Enable the clock → a time overlay appears in the chosen corner; toggle date →
the date appears; disable → no overlay.

**Acceptance Scenarios**:

1. **Given** the clock is off (default), **When** the slideshow runs, **Then** no clock is shown.
2. **Given** the clock is enabled, **When** the slideshow runs, **Then** the time (and optional date)
   shows in the configured corner.

---

### User Story 7 - Localized UI (English + German) (Priority: P3)

All UI strings move into a String Catalog and the app ships **English and German**, following the
device language. (Today the UI is hardcoded German.)

**Why this priority**: Product-readiness and consistency with the English-docs rule; not blocking but
expected for release.

**Independent Test**: Run with device language English → UI is English; German → UI is German; no
hardcoded user-facing strings remain in views.

**Acceptance Scenarios**:

1. **Given** an English device, **When** the app runs, **Then** all visible strings are English.
2. **Given** a German device, **When** the app runs, **Then** all visible strings are German.

---

### User Story 8 - Multi-source selection (Priority: P2)

The browser lets the user pick **multiple albums** (pooled into one rotation) and **Memories** as the
source, not just a single album. A **shared-link** entry ("paste a link + password", super-simple mode)
is present but **stubbed** (see spec 002); building it is deferred.

**Why this priority**: Frames usually mix collections; multi-album + Memories is the next-most-valuable
source capability. Builds on US2 (album browser).

**Independent Test**: In the browser, select two albums → the rotation draws from both; select Memories
→ memory photos play; the shared-link entry is visible but disabled/stubbed.

**Acceptance Scenarios**:

1. **Given** the browser, **When** the user selects multiple albums, **Then** the slideshow pools
   photos from all of them.
2. **Given** the browser, **When** the user selects Memories, **Then** the slideshow plays the
   Memories source.
3. **Given** the browser, **When** the user views connection options, **Then** a stubbed shared-link
   entry is present (deferred).

---

### Edge Cases

- **Empty album / load failure on switch**: the album browser shows a calm hint ("No albums" / "No
  photos" / "could not be loaded") instead of a blank surface.
- **Photo without EXIF**: the info overlay renders nothing (no empty card).
- **App backgrounded**: auto-advance pauses and the keep-awake / brightness grip is released
  (Constitution V); on return it resumes — unless the user paused via play/pause, in which case it
  stays paused.
- **Jump to unknown asset**: if the active album does not contain the requested photo, the jump is a
  no-op (no crash, no phase change).
- **Single-image album**: previous/next/tick stay stable on the same image.
- **Backward navigation**: only via the chrome "previous" or a right swipe; auto-advance runs forward
  only.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The default MUST be calm — the app opens straight into the running slideshow; with no
  user action no chrome, no clock, no info overlay, and no system status bar / home indicator are
  visible (Constitution VII).
- **FR-002**: A tap on the image MUST reveal the chrome (top bar: exit, photo info, albums, settings;
  bottom transport bar: previous, play/pause, next); another tap hides it.
- **FR-003**: Revealed chrome MUST auto-hide after ~4.5 s without interaction; any control interaction
  resets the countdown.
- **FR-004**: A horizontal swipe MUST advance the image forward (left) or back (right) **without**
  revealing the chrome.
- **FR-005**: The transport controls MUST offer manual previous/next and a play/pause that stops
  auto-advance; a user pause MUST stay paused across background→foreground while manual previous/next
  keeps working.
- **FR-006**: Auto-advance runs forward only; backward movement happens only via the chrome "previous"
  or a swipe.
- **FR-007**: From the chrome the user MUST be able to open an album browser as a sheet **over** the
  still-running slideshow (album grid → a photo thumbnail grid for an album).
- **FR-008**: A tap on a thumbnail MUST continue the slideshow from that photo and return to
  fullscreen; if the photo is in a different album, the app MUST switch to that album as the **only**
  active source at runtime and then jump to the photo.
- **FR-009**: Thumbnail rendering MUST use a dedicated smaller image endpoint (not the full preview)
  so the grid stays cheap.
- **FR-010**: From the chrome an info overlay MUST be revealable that shows date/time and location of
  the current photo from Immich EXIF, updates on photo change, and shows nothing when no usable info
  exists.
- **FR-011**: The info overlay MUST show only date/time and location — no filename, no album name.
- **FR-012**: From the chrome a settings screen MUST be reachable with a **live** brightness slider
  (via PowerManager / 004); brightness takes effect in the foreground only.
- **FR-013**: The planned display options (duration, transition, Ken Burns, order, image fit, clock
  overlay) MUST appear as a disabled preview until the ThemeSettings module (#5) activates them.
- **FR-014**: The reset action (clear server/API key/album, return to setup) MUST be reachable from the
  chrome (via the exit button), no longer via a long-press.
- **FR-015**: The image MUST be displayed fitted (letterbox) and centered in the default.
- **FR-016**: The UI MUST NOT display or log secrets (no API key, no credentials); existing Keychain
  usage stays untouched (Constitution III).

#### Display options, clock, localization & sources (added 2026-06-22)

- **FR-017**: The settings options (duration, transition, Ken Burns, order, fit, image quality) MUST
  persist and take effect on the running slideshow. (Activates the placeholder rows from FR-013.)
- **FR-018**: Settings MUST expose the disk-cache size limit and a **Clear cache** action (engine
  behavior per spec 003 FR-019).
- **FR-019**: The UI MUST offer an optional **clock overlay** — off by default, with configurable
  position and an optional date.
- **FR-020**: All user-facing strings MUST be localizable via a String Catalog; the app MUST ship
  **English and German** and follow the device language. (Replaces hardcoded German.)
- **FR-021**: The source picker MUST support selecting **multiple albums** and **Memories**; a
  **shared-link** entry MUST be present but MAY be stubbed/disabled (deferred — see spec 002).
- **FR-022**: The default image fit stays **Fit** (letterbox), with **Fill** selectable in settings.
  (Refines FR-015.)

### Key Entities *(include if feature involves data)*

- **AssetInfo**: the displayable context of a photo for the info overlay — capture date/time and
  location (city/region/country), derived from Immich EXIF. If a photo carries none of these, the
  overlay is empty (no content).
- **Slideshow control state**: the currently shown photo, whether the user paused, and which album is
  the active source — the information chrome, swipe, album browser, and info overlay share.
- **Album/thumbnail selection**: the album+photo combination chosen in the browser, handed back to the
  slideshow (album switch + jump).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In the default state only the image is visible — no chrome, no clock, no system status
  bar — until the user taps.
- **SC-002**: A tap reveals the chrome; after ~4.5 s without interaction it hides again.
- **SC-003**: A left/right swipe advances the image forward/back without chrome appearing.
- **SC-004**: Picking a different album and photo in the album browser → the slideshow continues from
  that photo in the now-active album.
- **SC-005**: The info overlay shows date + location where EXIF exists, and nothing where it is absent.
- **SC-006**: The settings screen offers a brightness control; adjusting it changes screen brightness
  live (foreground only). *Verification boundary: an automated UI test covers the control's presence
  and adjustability; the live brightness change rests on the PowerManager wiring and is confirmed
  manually (see quickstart.md) — XCUITest cannot read `UIScreen.brightness`.*
- **SC-007**: None of the extras (chrome, info, clock, album browser) is visible without an explicit
  user action — the calm default is preserved (Constitution VII).

## Assumptions

- The starting point is the existing slideshow (feature 003): `SlideshowViewModel`, image cache,
  ticker, and phases exist; this spec adds chrome / browser / info / settings UI.
- Brightness comes from the PowerManager (feature 004); the remaining display options wait on the
  not-yet-specified ThemeSettings module (#5).
- EXIF data (date/location) is provided by the existing Immich server over its REST API; the
  ImmichClient (feature 001) is extended with the corresponding fetch.
- iPadOS 26 provides the Liquid Glass look (`glassEffect`, `GlassEffectContainer`,
  `.buttonStyle(.glass)`).
- Pure presentation/interaction logic is verified via UI tests (XCUITest, hermetic `--uitest` build);
  the VM/client logic via host tests (Swift Testing).

### Out of Scope

- The ThemeSettings module (#5) itself — transitions, Ken Burns, order/shuffle, clock overlay,
  configurable image fit. Here only the disabled preview.
- Persisting the album source chosen at runtime (a restart returns to the onboarded album; see
  `data-model.md` → "Open items").
- Multi-album selection, search/filter in the browser, favorites.
- Editing/deleting photos; anything beyond pure display.
