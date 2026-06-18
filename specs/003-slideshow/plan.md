# Implementation Plan: SlideshowView (Vollbild-Diashow)

**Branch**: `003-slideshow` | **Date**: 2026-06-18 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/003-slideshow/spec.md`

## Summary

Nach abgeschlossenem Onboarding zeigt die App die Bilder des gewählten Albums als Endlos-Diashow: ein
Bild im Vollbild, automatischer Timer-Vorlauf mit Fade, Prefetch der nächsten 1–2 Bilder und ein
größenbegrenzter Bild-Cache. Technischer Ansatz: ein neues lokales SPM-Paket `SlideshowKit` enthält
die host-testbare Logik — ein `@Observable @MainActor SlideshowViewModel` (Ladephase, aktuelles Bild,
Reihenfolge, Schleife, Skip-on-Error), ein injizierbarer `SlideshowTicker` (deterministische
Timer-Tests ohne echte Zeit), ein größenbegrenzter `ImageCache` (LRU über `Data` je Asset-ID) und ein
`SlideshowConfig`-Wertmodell (Anzeigedauer, Prefetch-Tiefe, Cache-Limit als feste v1-Defaults). Die
Bilddaten kommen über das bestehende `ImmichAPI` (`assets(albumID:)` + `preview(assetID:)`); der
Cache hält rohe Preview-`Data`, das Dekodieren zu `Image` passiert in der SwiftUI-Schicht — so bleibt
das Paket UIKit-frei und host-testbar. Die `SlideshowView` und die App-Verdrahtung (authentifizierter
`ImmichClient` aus `AppConfiguration` + Keychain-Key; Anzeige statt des `ContentView`-Platzhalters;
Foreground-only Timer über `scenePhase`) liegen im App-Target. Logik per Host-Tests (Swift Testing,
`MockTransport` + Test-`Ticker`); Vollbild-Rendering, Fade und Hintergrund-Pause werden auf dem
iPad-Simulator über XcodeBuildMCP verifiziert (inkl. hermetischer XCUITest über die `--uitest`-Naht).

## Technical Context

**Language/Version**: Swift 6

**Primary Dependencies**: SwiftUI, Observation (`@Observable`), Foundation; intern das bestehende
Paket `ImmichClient` (Netzwerk + `ImmichError`-Mapping) und transitiv `OnboardingKit`
(`AppConfiguration`). Keine Drittbibliotheken. UIKit-Bezug (`UIImage`-Dekodierung) bleibt im
App-Target, nicht im Paket.

**Storage**: Kein neuer persistenter Speicher. Quelle ist die Immich-REST-API (Album-Assets +
Preview-Thumbnail). Flüchtiger, größenbegrenzter In-Memory-Bild-Cache (`Data` je Asset-ID, LRU).
Server-URL/Album-ID stammen aus `ConfigStore` (UserDefaults), der API-Key aus dem Keychain — beide
über das Onboarding (Feature 002) bereits vorhanden.

**Testing**: Swift Testing (`@Test`). Paketlogik als Host-Tests (`swift test`): `MockTransport` aus
`ImmichClientTestSupport` für Asset-/Preview-Antworten, ein Test-`SlideshowTicker` treibt
Bildwechsel deterministisch ohne echte Zeit. Vollbild/Fade/Scene-Pause als app-gehostete Tests +
hermetischer XCUITest (`--uitest`) auf dem iPad-Simulator über XcodeBuildMCP (`test_sim`).

**Target Platform**: iPadOS 18+ (SwiftUI). `SlideshowKit`-Logik plattformneutral (iOS + macOS-Host)
testbar; UIKit-abhängiges Dekodieren/Rendering nur im App-Target/Simulator.

**Project Type**: Mobile-App-Feature — lokales SPM-Paket `SlideshowKit` + `SlideshowView`/Wiring im
App-Target „Immich Slideshow".

**Performance Goals**: Bildwechsel ohne sichtbares Ladeflackern (SC-003) durch Prefetch der nächsten
1–2 Bilder. Speicher im Dauerbetrieb stabil durch festes Cache-Count-Limit (SC-004). Flüssiges Fade;
60 fps-Ziel für den Übergang. Nicht latenzkritisch im Netz, aber Prefetch verdeckt Netzlatenz.

**Constraints**: Keine TLS-Ausnahme (Konstitution IV) — Standard-`ImmichClient` über HTTPS. API-Key
nie in Logs/Klartext (Konstitution III); der Slideshow-Client erhält ihn injiziert, loggt ihn nie.
Keine versteckten Singletons; `ImmichAPI`, `SlideshowTicker`, `ImageCache` injiziert (Konstitution
II). Timer/Helligkeit nur im Vordergrund; Hintergrund pausiert (Konstitution V, FR-012). Ruhiger,
heller Default ohne Overlays/Effekte (Konstitution VII, FR-013). Helligkeit/Idle-Timer sind **nicht**
Teil dieses Features (PowerManager, #4).

**Scale/Scope**: Ein Album, ein Nutzer. Album bis zu mehreren Tausend Assets (nur Standbilder, Videos
übersprungen). Ein Vollbild-View + ViewModel + Cache/Ticker; ~2 Zustands-Views (leer/Fehler).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Prinzip | Bewertung | Status |
|---------|-----------|--------|
| I. Test-First (NON-NEGOTIABLE) | TDD: rote Tests für ViewModel (Reihenfolge, Schleife, Skip-on-Error, Leer/Fehler), Ticker-getriebenen Wechsel und Cache-Eviction **vor** Implementierung; Vollbild/Fade auf dem Simulator verifiziert. | ✅ |
| II. Modulare Isolation | `ImmichAPI`, `SlideshowTicker`, `ImageCache` als injizierte Protokolle/Typen; `SlideshowViewModel` ohne Singletons; Zeit über den Ticker injiziert (deterministisch testbar). | ✅ |
| III. Keine Secrets im Klartext (NON-NEGOTIABLE) | Kein neues Secret. API-Key kommt aus dem Keychain in den injizierten Client; erscheint nie in Logs/UserDefaults/Cache. | ✅ |
| IV. Sicherheit der Transportschicht | Standard-`ImmichClient` (HTTPS, gültiges Zert); keine TLS-Ausnahme; nur Wiederverwendung bestehender Endpunkte. | ✅ |
| V. Plattformgrenzen respektieren | Timer-Vorlauf nur im Vordergrund; `scenePhase`-Wechsel pausiert/setzt fort. Kein Display-Aus, keine Hintergrund-Annahmen (FR-012). | ✅ |
| VI. Verifizierbare Akzeptanzkriterien | Spec liefert messbare SC-001…SC-006; quickstart.md mappt sie auf Host-/Sim-Tests. | ✅ |
| VII. Schlicht und hell als Default | Vollbild zeigt nur das Bild + sanftes Fade; keine Overlays/Ken-Burns/Uhr (FR-013, deferred an ThemeSettings). | ✅ |

**Ergebnis: PASS — keine Verletzungen, keine Komplexitäts-Ausnahmen nötig.**

## Project Structure

### Documentation (this feature)

```text
specs/003-slideshow/
├── plan.md              # This file
├── research.md          # Phase 0 output (Ticker-Seam, Cache, Prefetch, Fade, scenePhase)
├── data-model.md        # Phase 1 output (Entitäten + Zustandsübergänge)
├── quickstart.md        # Phase 1 output (SC-Mapping auf Tests)
├── contracts/           # Phase 1 output (SlideshowViewModel / SlideshowTicker / ImageCache)
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
Packages/
├── ImmichClient/                        # bestehend; unverändert (assets() + preview() reichen)
└── SlideshowKit/                        # NEU
    ├── Package.swift                    # Swift 6, iOS 18 + macOS-Host; depends ImmichClient
    ├── Sources/SlideshowKit/
    │   ├── SlideshowConfig.swift        # Anzeigedauer, Prefetch-Tiefe, Cache-Limit (feste v1-Defaults)
    │   ├── SlideshowPhase.swift         # enum: loading / playing / empty / failed
    │   ├── SlideshowTicker.swift        # Protokoll + RealTicker (Task.sleep); Test-Ticker in Tests
    │   ├── ImageCache.swift             # größenbegrenzter LRU-Cache über Data je Asset-ID
    │   └── SlideshowViewModel.swift     # @Observable @MainActor; Reihenfolge, Schleife, Prefetch, Skip-on-Error
    └── Tests/SlideshowKitTests/
        ├── Fakes.swift                  # ManualTicker; (MockTransport aus ImmichClientTestSupport)
        ├── ImageCacheTests.swift        # Eviction/Count-Limit (SC-004)
        ├── SlideshowViewModelTests.swift# US1 Reihenfolge/Schleife; US2 Prefetch; US3 Skip/Leer/Fehler
        └── SlideshowTickerTests.swift   # ManualTicker treibt Wechsel deterministisch

Immich Slideshow/                        # App-Target
├── Immich_SlideshowApp.swift            # bei .done jetzt SlideshowView statt Platzhalter; baut auth. ImmichClient aus AppConfiguration+Keychain; reicht onReset durch
├── ContentView.swift                    # Platzhalter entfällt am .done-Pfad; der Reset-Pfad (onReset → viewModel.reset()) wandert in SlideshowView
└── Slideshow/                           # SwiftUI (auf dem Simulator verifiziert)
    ├── SlideshowView.swift              # Vollbild, Fade-Übergang, scenePhase-Pause, Data→Image-Dekodierung
    ├── SlideshowEmptyView.swift         # schlichter Leer-Hinweis (US3)
    └── SlideshowErrorView.swift         # Fehlerhinweis + „Erneut versuchen" (US3)

Immich SlideshowTests/                   # app-gehostete Tests (Simulator)
└── SlideshowRenderingTests.swift        # Vollbild-Rendering / Data→Image / Fade-Smoke (optional)
```

**Structure Decision**: Testbare Logik in `Packages/SlideshowKit` (Foundation/Observation, schnell
host-testbar, „Modulare Isolation") — analog zu `OnboardingKit`. Der Bild-Cache hält rohe Preview-
`Data` statt dekodierter `UIImage`, damit das Paket UIKit-frei und auf dem Host testbar bleibt
(SPM-Test-Target-Limitierung: Paket-Tests laufen auf dem Host); das Dekodieren zu `Image` und das
Vollbild-Rendering liegen im App-Target und werden auf dem Simulator verifiziert. Die Zeit wird über
`SlideshowTicker` injiziert, damit Bildwechsel ohne echte Wartezeit deterministisch getestet werden
(Timer-Test-Design bleibt inline bei Claude, CLAUDE.md). Das App-Target bindet `SlideshowKit` (und
transitiv `ImmichClient`) ein. Begründung gegen Default-`src/`: Swift/SPM-Konventionen und bestehende
Projektstruktur (`ImmichClient`, `OnboardingKit`).

## Complexity Tracking

> Keine Constitution-Verletzungen — Abschnitt leer.
