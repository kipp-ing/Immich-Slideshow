# Contract: ThemeSettingsStore (ThemeKit)

The injectable seam for reading/writing display preferences. Defined in `ThemeKit`. Concrete
`UserDefaultsThemeStore` for the app; `InMemoryThemeStore` fake for tests (Constitution II).

## Protocol + concrete store shape (conceptual)

```
// Plain protocol = the injectable seam (engine + tests depend on this).
@MainActor
protocol ThemeSettingsStore: AnyObject {
    var settings: ThemeSettings { get set }   // get reads; set persists
}

// The app injects a concrete @Observable class so SwiftUI observes it live.
@MainActor @Observable
final class UserDefaultsThemeStore: ThemeSettingsStore { /* persists to UserDefaults */ }
```

- `@Observable` applies to the **concrete class**, not the protocol (the macro is class-only, and
  SwiftUI observes concrete `@Observable` types). Views hold the concrete `UserDefaultsThemeStore`;
  the engine and tests depend on the `ThemeSettingsStore` protocol (D2).
- A single instance is shared between `SlideshowViewModel`, `SlideshowView`, and
  `SlideshowSettingsView` (injected at app construction).
- The test fake `InMemoryThemeStore` conforms to the protocol and ships in the **`ThemeKitTestSupport`**
  product so `SlideshowKitTests` / app-hosted tests can import it.

## Behavioral contract

| # | Given | When | Then |
|---|-------|------|------|
| 1 | a fresh store (no persisted values) | read `settings` | all defaults per data-model (shuffle, 15 s, crossfade, no Ken Burns, Fit, Preview, clock off) |
| 2 | any field changed via the store | the app relaunches (new store over same defaults) | the changed value is read back (persisted) — FR-003/SC-002 |
| 3 | a persisted field holds an unknown/corrupt value | read `settings` | that field falls back to its default; other fields are unaffected — FR-013 |
| 4 | a duration outside `durationRange` is written | read back | the value is clamped into range — FR-005 |
| 5 | nothing stored is a secret | inspect persistence | only non-secret prefs; no API key/credentials — SC-006 |

## Test doubles

- `InMemoryThemeStore`: backing dictionary, no `UserDefaults`; used by `SlideshowKit` and app-hosted
  tests to drive order/duration/quality deterministically.
