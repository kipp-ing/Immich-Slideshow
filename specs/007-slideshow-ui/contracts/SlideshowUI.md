# Contracts: Slideshow UI

Public interfaces this feature slice adds. Signatures match the shipped state (Swift 6). Extends the
existing packages `SlideshowKit` (003) and `ImmichClient` (001); the views live in the app target.

## ImmichClient — new endpoints (US2/US3)

```swift
public protocol ImmichAPI: Sendable {
    // … existing: serverVersion, albums, assets, preview …
    func assetInfo(assetID: String) async throws -> AssetInfo   // US3
    func thumbnail(assetID: String) async throws -> Data        // US2
}

public struct AssetInfo: Sendable, Equatable {
    public let id: String
    public let takenAt: Date?
    public let city: String?
    public let state: String?
    public let country: String?
    public init(id: String, takenAt: Date?, city: String?, state: String?, country: String?)
}
```

- `assetInfo`: `GET` of the asset detail with `x-api-key`; decodes `exifInfo` → `AssetInfo`. Date from
  `exifInfo.dateTimeOriginal`, fallback `localDateTime`/`fileCreatedAt`. Location from
  `exifInfo.city/state/country`.
- `thumbnail`: like `preview`, but with a smaller size query (thumbnail vs. full). `x-api-key`.

### Behavioral contract (testable, host)

| Trigger | Guaranteed effect |
|---------|-------------------|
| `assetInfo` with `exifInfo` present | `AssetInfo` with `takenAt` from `dateTimeOriginal`, `city/state/country` set |
| `assetInfo` without `exifInfo` | `takenAt` from `localDateTime`/`fileCreatedAt`, location fields `nil` |
| `assetInfo` request | sends `GET` with `x-api-key` header |
| `thumbnail` request | sends `GET` with `x-api-key` and thumbnail size query; returns raw data |
| `preview` request | sends `GET` with preview size query (distinct from thumbnail) |

## SlideshowKit — SlideshowViewModel (control extension, US1/US2)

```swift
@MainActor @Observable
public final class SlideshowViewModel {
    public private(set) var phase: SlideshowPhase
    public private(set) var currentAssetID: String?
    public private(set) var currentImageData: Data?
    public private(set) var isPaused: Bool          // NEW — user pause
    public private(set) var albumID: String         // NEW — mutable (was let)

    public func start() async
    public func advance() async                       // auto-advance (ticker), forward
    public func showNext() async                      // NEW — manual forward; timer reset
    public func showPrevious() async                  // NEW — manual backward; timer reset
    public func jump(to assetID: String) async        // NEW — jump within the active album; no-op if unknown
    public func togglePause()                         // NEW — user pause on/off
    public func switchAlbum(_ albumID: String) async  // NEW for UI — runtime album switch (+ reload)
    public func pause(); public func resume()         // foreground gating (separate from isPaused)
    public func retry() async
}
```

### Behavioral contract (testable, host)

| Trigger | Guaranteed effect |
|---------|-------------------|
| `showNext()` | next image (mod n); auto-advance timer is reset |
| `showPrevious()` | previous image (mod n, wrap); the only backward movement |
| `togglePause()` (running) | `isPaused=true`, ticker stops; survives background→foreground |
| `togglePause()` (paused) | `isPaused=false`, ticker re-armed (if an image is running) |
| `resume()` while `isPaused==true` | does **not** re-arm (user pause holds) |
| `jump(to: known)` | loads/shows the asset; `phase=.playing`; timer reset |
| `jump(to: unknown)` | no-op |
| `switchAlbum(x)` | `albumID==x`; loads the new album from the start; `currentAlbumID` reflects x |
| `advance()` (single image) | stays stable on the same image |

## App target — view interfaces (US1–US4)

Pure SwiftUI presentation (verified via XCUITest, not as a package API):

```swift
struct SlideshowChrome: View {            // US1 — top/bottom Liquid Glass bars
    let viewModel: SlideshowViewModel
    var onExit, onInfo, onAlbums, onSettings, onInteraction: () -> Void
}
struct AlbumBrowserView: View {           // US2 — album/thumbnail grid as a sheet
    let api: any ImmichAPI
    let currentAlbumID: String?
    var onSelect: (_ albumID: String, _ assetID: String) -> Void
}
struct PhotoInfoView: View {              // US3 — date/location from AssetInfo; quiet when empty
    let api: any ImmichAPI
    let assetID: String
}
struct SlideshowSettingsView: View {      // US4 — brightness live + planned options (disabled)
    let powerManager: PowerManager
}
```

### Accessibility identifiers (for XCUITest)

| Identifier | Element |
|-----------|---------|
| `slideshow.chrome.exit/info/albums/settings` | top bar |
| `slideshow.chrome.previous/playPause/next` | transport bar |
| `slideshow.info.card` | info overlay card |
| `album.row.<id>` / `album.thumbnail.<id>` | album/thumbnail cell |
| `settings.brightness` / `settings.row.<title>` | brightness slider / planned option |
| `--uitest-chrome/-albums/-info/-settings` | launch args that present the respective UI deterministically |
