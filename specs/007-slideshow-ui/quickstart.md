# Quickstart & Validation: Slideshow UI

Host tests cover the VM control logic and the new client endpoints; the simulator (XCUITest) verifies
chrome, album browser, info overlay, and settings hermetically.

## Prerequisites

- Feature 003 (Slideshow) present — `SlideshowViewModel`, cache, ticker, phases.
- Feature 001 (ImmichClient) present — extended with `assetInfo`/`thumbnail`.
- Feature 004 (PowerManager) present — provides the live brightness.
- The app scheme builds on an iOS 26.x simulator (pinned simulatorId, `preferXcodebuild`).

## Logic tests (host, fast)

```text
swift test  (in Packages/SlideshowKit and Packages/ImmichClient)
```

- VM additions against `MockTransport` / a fake ticker; client endpoints against `MockTransport`
  (no real server).

## UI tests (hermetic, simulator via XcodeBuildMCP)

```text
test_sim  (scheme "Immich Slideshow", iPad Pro 11" M5)
```

- Launch arguments present the respective UI deterministically: `--uitest-chrome` (chrome visible,
  no auto-hide), `--uitest-albums`, `--uitest-info`, `--uitest-settings`. Stub API + in-memory stores.

## Acceptance mapping (spec → validation)

| Criterion | Validation |
|-----------|------------|
| **SC-001** overlay-free default | XCUITest `testChromeHiddenByDefaultAndRevealsOnTap`: no chrome/status bar before the tap. |
| **SC-002** tap on / idle off | XCUITest `testChromeHiddenByDefault…` (tap) + `testChromeAutoHidesWhenIdle` (auto-hide). |
| **SC-003** swipe without chrome | XCUITest `testSwipeAdvancesWithoutRevealingChrome`; VM `showNext/showPrevious` tests. |
| **SC-004** album switch + jump | XCUITest `testAlbumBrowserOpensDrillsInAndSelectionReturnsToSlideshow`; VM `switchAlbum`/`jump` tests. |
| **SC-005** info shows/stays quiet | XCUITest `testInfoButtonTogglesDateAndLocationOverlay`; client `AssetInfoTests` (with/without EXIF). |
| **SC-006** brightness live | XCUITest `testSettingsShowsBrightnessAndPlannedOptionsAndDismisses` (slider present/effective). |
| **SC-007** default stays calm | as SC-001 + review: no extra visible without a user action. |

## Simulator verification (manual, optional)

1. Launch the app → only the image, fitted/centered; no status bar.
2. Tap → chrome appears; do nothing → after ~4.5 s it hides. Swipe → image changes without chrome.
3. Chrome → albums → album → photo → fullscreen from that photo (a different album becomes active).
4. Chrome → info → date/location of the photo; a photo without EXIF shows no overlay.
5. Chrome → settings → move the brightness slider → brightness changes live.

## Out of Scope (do not verify here)

- ThemeSettings module (#5): duration/transition/Ken Burns/order/clock/configurable image fit.
- Persistence of the runtime-chosen album source (a restart returns to the onboarded album).
