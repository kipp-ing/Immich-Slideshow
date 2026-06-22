# Contracts: Slideshow UI

This feature is mostly presentation; its public surface lives in code, which is the **source of truth**.
Rather than duplicate Swift signatures here (they would silently drift from the code), this file is a
thin index of what 007 added — read the listed sources and their tests for exact signatures and
behavior; the compiler and test suite keep those honest.

## Public surface added by 007

**ImmichClient** — `Packages/ImmichClient/Sources/ImmichClient/`

- `ImmichAPI.thumbnail(assetID:) async throws -> Data` — smaller-than-`preview` image for the browser
  grid (US2, `1af7466`). Sources: `ImmichAPI.swift`, `ImmichClient.swift`. Tests: `PreviewTests.swift`.
- `ImmichAPI.assetInfo(assetID:) async throws -> AssetInfo` + the `AssetInfo` value type
  (`id, takenAt, city, state, country`), decoded from Immich `exifInfo` with a `localDateTime`/
  `fileCreatedAt` date fallback (US3, `a2c36b1`). Sources: `Models.swift`, `ImmichClient.swift`. Tests:
  `AssetInfoTests.swift`. Field/decoding detail: [data-model.md](../data-model.md).

**SlideshowKit** — `Packages/SlideshowKit/Sources/SlideshowKit/SlideshowViewModel.swift`

- **Added by 007** (US1, `52e4c5e`): `showNext()`, `showPrevious()`, `jump(to:)`, `togglePause()`,
  `isPaused`.
- **Reused, not added by 007**: `switchAlbum(_:)` and the mutable `albumID` (feature 005, `3d973ab`,
  for HA remote control); `advance()`, `pause()`, `resume()`, `currentAssetID` (003). The album browser
  is the second consumer of `switchAlbum`.
- Behavioral guarantees (forward-only auto-advance; user pause survives foreground; `jump` is a no-op
  on an unknown asset; exactly one active album): see the **Invariants** in
  [data-model.md](../data-model.md). Tests: `SlideshowViewModelTests.swift`.

**App-target views** — `Immich Slideshow/Slideshow/` (verified via XCUITest, not a package API):
`SlideshowChrome`, `AlbumBrowserView`, `PhotoInfoView`, `SlideshowSettingsView`.

## Accessibility identifiers & launch args (for XCUITest)

| Identifier / arg | Element / effect |
|---|---|
| `slideshow.image` / `slideshow.info.card` | current image / info overlay card |
| `slideshow.chrome.exit/info/albums/settings` | top-bar buttons |
| `slideshow.chrome.previous/playPause/next` | transport buttons |
| `album.row.<id>` / `album.thumbnail.<id>` | album / thumbnail cell |
| `settings.brightness` / `settings.row.<title>` | brightness slider / planned (disabled) row |
| `--uitest` | hermetic build (stub API + in-memory stores); still starts at onboarding step 1 |
| `--uitest-slideshow` | start with onboarding `step = .done` → straight into the slideshow |
| `--uitest-chrome` | chrome revealed **and pinned** (no auto-hide) for stable controls |
| `--uitest-albums` / `--uitest-info` / `--uitest-settings` | present that surface deterministically on launch |

> Source of truth is the Swift sources and tests above — change those first; this index follows.
