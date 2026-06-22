# Phase 1 Data Model: Slideshow UI

This feature is mostly presentation; it introduces one display model (`AssetInfo`) and extends the
control state of the existing `SlideshowViewModel`. No new persistent storage.

## Display model

### AssetInfo (`Sendable`, `Equatable`) — in `ImmichClient`

| Field | Type | Meaning | Source (Immich) |
|-------|------|---------|-----------------|
| `id` | `String` | asset identifier | `AssetResponse.id` |
| `takenAt` | `Date?` | capture date/time | `exifInfo.dateTimeOriginal`, fallback `localDateTime`/`fileCreatedAt` |
| `city` | `String?` | location (city) | `exifInfo.city` |
| `state` | `String?` | region | `exifInfo.state` |
| `country` | `String?` | country | `exifInfo.country` |

- Display logic (in `PhotoInfoView`): date text from `takenAt` (long + short time); location text from
  `[city, country]` (non-empty, comma-joined). If **both** are empty, the overlay renders nothing
  (FR-010/FR-011).
- Decoding helper type (internal): `AssetDetail { id, localDateTime?, fileCreatedAt?, exifInfo? }` with
  `ExifInfo { dateTimeOriginal?, city?, state?, country? }`. `assetInfo(assetID:)` maps onto it.

## Control state: SlideshowViewModel (extension of feature 003)

New/changed public surface (details in `contracts/SlideshowUI.md`):

| Element | Kind | Purpose |
|---------|------|---------|
| `albumID` | `private(set) var` | active source; switchable at runtime via `switchAlbum`. The `var` and `switchAlbum` predate 007 (added in feature 005 for HA remote); 007 makes the browser a second consumer (US2) |
| `isPaused` | `private(set) var` | user pause (chrome play/pause), separate from foreground gating — **added by 007** (US1) |
| `currentAssetID` | `private(set) var` | which photo is shown (album-browser marker, info overlay) |
| `showNext()` | `func async` | manual forward step; resets the auto-advance timer (US1) |
| `showPrevious()` | `func async` | manual backward step (the only backward movement) (US1) |
| `jump(to:)` | `func async` | jump to an asset in the active album; no-op if unknown (US2) |
| `togglePause()` | `func` | user pause on/off; pauses/restarts the ticker (US1) |
| `switchAlbum(_:)` | `func async` | switch the active source and reload — **reused** from feature 005 (HA remote), not added by 007; the browser is its second consumer (US2) |

## Selection handoff (US2)

- The album browser hands an `(albumID, assetID)` selection back to the slideshow. Behavior: if
  `albumID` differs from the active one → `switchAlbum(albumID)`, then always `jump(to: assetID)`.

## State transitions (control)

```text
   playing ──tap──▶ chrome visible ──~4.5 s idle──▶ chrome hidden
   playing ──swipe L/R──▶ showNext()/showPrevious()  (chrome stays hidden)
   playing ──play/pause──▶ isPaused=true (ticker off; survives background→foreground)
                      └──▶ isPaused=false (ticker on, if an image is running)
   playing ──album-browser tap──▶ [switchAlbum?] → jump(to:) → playing (new source/position)
```

## Invariants

- Auto-advance runs forward only; backward only via `showPrevious()` (swipe/chrome) (FR-006).
- A user pause (`isPaused`) survives background→foreground; the foreground `resume()` only re-arms the
  ticker when not user-paused (FR-005).
- `jump(to:)` to an asset not present in the active album is a no-op (no crash/phase change).
- Exactly one album is the active source (`albumID`); `switchAlbum` is the only switch point (FR-008).
- `AssetInfo` with neither date nor location yields an empty info overlay (FR-010).
- The UI holds/shows no secrets (Constitution III).

## Open items (out of scope, documented)

- **Album choice is runtime-only**: `switchAlbum`/`jump` take effect at runtime but are **not**
  persisted to config (same semantics as the existing `switchAlbum` path). A restart returns to the
  onboarded album, not the last-picked one. To make a restart remember the chosen album, the selected
  `albumID` would need to be written to the ConfigStore on select and read back at startup.
