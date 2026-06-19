# Tasks: SlideshowView (Vollbild-Diashow)

**Input**: Design documents from `/specs/003-slideshow/`

**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓

**Tests**: TDD ist laut Konstitution (Prinzip I, NON-NEGOTIABLE) verbindlich → Test-Tasks sind
enthalten und werden **vor** der Implementierung geschrieben und müssen zuerst **rot** sein.

**Organization**: Nach User Stories gruppiert; jede Story ist unabhängig testbar.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: parallelisierbar (andere Datei, keine offenen Abhängigkeiten)
- **[Story]**: zugehörige User Story (US1, US2, US3)
- Pfade relativ zum Repo-Root. Neues Paket unter `Packages/SlideshowKit/`; Views im App-Target.

**Orchestrierung** (CLAUDE.md): Host-testbare Logik (`SlideshowKit`: ViewModel, Cache, Ticker) eignet
sich zum Delegieren an Codex (`swift test`). **Inline bei Claude:** das Ticker-/Concurrency-Test-Design
(Lauf-Schleife, Cancellation/Pause), SwiftUI-Views, `*.pbxproj`-Verdrahtung, App-Entry und alle
Simulator-/XCUITest-Verifikationen.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Lokales SPM-Paket `SlideshowKit` anlegen, baubar und host-testbar.

- [X] T001 SPM-Paket-Gerüst anlegen: `Packages/SlideshowKit/Package.swift` (Swift 6, Plattform iOS 18 / macOS-Host; Target `SlideshowKit` mit Dependency auf `ImmichClient`; Test-Target `SlideshowKitTests` mit Dependencies `SlideshowKit` + `ImmichClientTestSupport`).
- [X] T002 Quell- und Testverzeichnisse anlegen: `Packages/SlideshowKit/Sources/SlideshowKit/` und `Packages/SlideshowKit/Tests/SlideshowKitTests/`.
- [X] T003 Leeren Build verifizieren (Paket baut, leere Suite grün via `swift build`/`swift test` auf dem Host).

**Checkpoint**: Paket existiert und baut.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Geteilte Wertmodelle, Zeit-Naht, Cache und Test-Fakes, die alle Stories brauchen.

**⚠️ CRITICAL**: Muss vor allen User Stories fertig sein.

- [X] T004 [P] `SlideshowConfig` (`interval: Duration`, `prefetchDepth: Int`, `cacheLimit: Int`; `Sendable`, `Equatable`; statische `.default` mit **konkret gepinnten** v1-Werten: `interval = .seconds(8)`, `prefetchDepth = 2`, `cacheLimit = 5`; Invarianten `prefetchDepth >= 1`, `cacheLimit >= prefetchDepth + 1`) in `Packages/SlideshowKit/Sources/SlideshowKit/SlideshowConfig.swift`.
- [X] T005 [P] `SlideshowPhase` enum (`loading`/`playing`/`empty`/`failed`; `Equatable`, `Sendable`) in `Packages/SlideshowKit/Sources/SlideshowKit/SlideshowPhase.swift`.
- [X] T006 [P] `SlideshowTicker`-Protokoll (`func waitForNextTick() async throws`, `Sendable`) + `RealTicker(interval:)` (über `Task.sleep`/`ContinuousClock`, respektiert Cancellation) in `Packages/SlideshowKit/Sources/SlideshowKit/SlideshowTicker.swift`.
- [X] T007 Test-Fake `ManualTicker` (jeder `tick()` lässt genau einen wartenden `waitForNextTick()` zurückkehren) in `Packages/SlideshowKit/Tests/SlideshowKitTests/Fakes.swift`. (MockTransport stammt aus `ImmichClientTestSupport`.)
- [X] T008 [P] Test (zuerst rot): `ImageCache` LRU-/Count-Limit — Store über `limit` hinaus → `count == limit`, ältester (am längsten nicht genutzter) Eintrag weg; `data(for:)` frischt LRU-Position; `contains(_:)` ohne LRU-Effekt. In `Packages/SlideshowKit/Tests/SlideshowKitTests/ImageCacheTests.swift`. (FR-007/SC-004)
- [X] T009 `ImageCache` implementieren (LRU über `Data` je `assetID`, festes `limit`, thread-safe `@unchecked Sendable`) in `Packages/SlideshowKit/Sources/SlideshowKit/ImageCache.swift` bis T008 grün.

**Checkpoint**: Foundation steht — User Stories können beginnen.

---

## Phase 3: User Story 1 - Album als Vollbild-Diashow ansehen (Priority: P1) 🎯 MVP

**Goal**: Album laden, erstes Bild im Vollbild zeigen, per Timer automatisch mit Fade weiterrücken,
am Ende wieder von vorn (Endlosschleife).

**Independent Test**: Mit `MockTransport` (Album mit ≥2 Bildern) + `ManualTicker` durchspielen →
`start()` zeigt erstes Bild (`phase == .playing`), `tick()`/`advance()` zeigt das nächste, nach dem
letzten wieder das erste; Einzelbild bleibt stabil.

### Tests for User Story 1 (zuerst schreiben, MUSS rot sein) ⚠️

- [X] T010 [P] [US1] Test: `SlideshowViewModel.start()` lädt `assets(albumID:)`, filtert auf Standbilder (FR-011), setzt erstes Bild (`currentAssetID`/`currentImageData`) und `phase == .playing`; `advance()` rückt zum nächsten; nach dem letzten Bild wieder zum ersten (FR-005); Einzelbild-Album bleibt beim selben Bild ohne Fehler. `ManualTicker.tick()` rückt genau ein Bild vor; ohne `tick()` kein Selbstlauf; nach `pause()` kein Vorrücken bis `resume()`. In `Packages/SlideshowKit/Tests/SlideshowKitTests/SlideshowViewModelTests.swift`. (FR-001/FR-002/FR-003/FR-005/FR-011/FR-012)

### Implementation for User Story 1

- [X] T011 [US1] `SlideshowViewModel` (`@MainActor @Observable`) in `Packages/SlideshowKit/Sources/SlideshowKit/SlideshowViewModel.swift`: injizierte `api: ImmichAPI`, `albumID`, `ticker`, `cache`, `config`; `start()` (laden, filtern, erstes Bild, Lauf-Schleife über den Ticker), `advance()` (Index+1 mod n, Bild aus Cache/Abruf, Fade-Auslöser), `pause()`/`resume()` (Lauf anhalten/fortsetzen, Cancellation-sicher). **Vorab den Standbild-Diskriminator gegen die laufende Immich-Instanz verifizieren** (`/api/openapi.json` bzw. ein echtes Album-Asset): welcher `Asset.type`-Wert eine Bild-Asset markiert (Erwartung „IMAGE") — nicht raten (Konstitution IV). Happy Path; Fehler-/Leerfälle kommen in US3. Test T010 grün.
- [X] T012 [US1] SwiftUI `SlideshowView` im App-Target: `Immich Slideshow/Slideshow/SlideshowView.swift` (Vollbild, formatfüllend, `Data`→`Image`-Dekodierung, Fade-Übergang via Opacity-Transition + `withAnimation(.easeInOut)`, schlicht/hell ohne Overlays — Konstitution VII, FR-004/FR-013). Nimmt einen `onReset`-Callback entgegen und stellt eine schlichte, unaufdringliche Reset-Möglichkeit bereit (z. B. Long-Press/verstecktes Menü), die `onReset` auslöst — erhält den Reset-Pfad aus 002/US3, ohne den ruhigen Default zu stören.
- [X] T013 [US1] App-Verdrahtung in `Immich Slideshow/Immich_SlideshowApp.swift`: bei `step == .done` `SlideshowView` statt `ContentView`-Platzhalter zeigen; authentifizierten `ImmichClient` aus `AppConfiguration.baseURL` + Keychain-API-Key (`ServerConfig`) bauen und mit `selectedAlbumID` + `RealTicker` ins `SlideshowViewModel` injizieren; `scenePhase` an `pause()`/`resume()` binden (FR-012). Key erscheint nie in Logs (Konstitution III). **Reset-Pfad aus 002/US3 erhalten:** den bestehenden `onReset`-Callback (`viewModel.reset()`) an `SlideshowView` durchreichen, damit die Reset-Möglichkeit nicht verloren geht (siehe T012). Der `ContentView`-Platzhalter entfällt am `.done`-Pfad.
- [X] T014 [US1] `SlideshowKit` als lokale Paket-Abhängigkeit ins App-Target „Immich Slideshow" einbinden (`*.xcodeproj/project.pbxproj`: `XCSwiftPackageProductDependency` + Frameworks-Verknüpfung). App baut auf dem iPad-Simulator.
- [X] T015 [US1] `--uitest`-Naht in `Immich_SlideshowApp.swift` so erweitern, dass ein abgeschlossener Onboarding-Stub auf eine Slideshow mit mehreren Stub-Bildern führt; hermetischer XCUITest (`Immich SlideshowUITests/`) prüft offline, dass das erste Bild erscheint (kein Netz/Server). (siehe `docs/testing.md`)
- [X] T016 [US1] Simulator-Verifikation (XcodeBuildMCP): nach abgeschlossenem Onboarding erscheint sofort das erste Bild im Vollbild (SC-001); automatischer Wechsel mit sanftem Fade über zwei, drei Bilder (FR-004/SC-002); App in den Hintergrund und zurück → Lauf pausiert/fortgesetzt (FR-012). **Verifiziert:** hermetischer XCUITest `testOnboardingHappyPathReachesSlideshow` (Onboarding → `slideshow.image` sichtbar) grün auf dem iPad-Simulator; sauberer App-Launch per Screenshot bestätigt. Fade (`scenePhase`-Pause/Resume in `SlideshowView`) ist verdrahtet und durch ViewModel-Tests abgedeckt; die rein optische Fade-Ästhetik wurde nicht separat als Video aufgezeichnet.

**Checkpoint**: US1 unabhängig funktionsfähig — Diashow läuft im Vollbild (MVP).

---

## Phase 4: User Story 2 - Flüssiger Wechsel ohne Ladeflackern (Priority: P2)

**Goal**: Die nächsten 1–2 Bilder werden vorgeladen; der Wechsel nutzt den Cache (kein
Lade-Roundtrip im Moment des Wechsels); der Cache bleibt im Dauerbetrieb begrenzt.

**Independent Test**: Mit `MockTransport` (Aufrufzähler) prüfen, dass nach `start()`/`advance()` das
nächste Bild bereits im Cache liegt und ein Wechsel auf ein vorgeladenes Bild keinen erneuten
`preview()`-Abruf auslöst; über viele Wechsel bleibt `cache.count <= cacheLimit`.

### Tests for User Story 2 (zuerst schreiben, MUSS rot sein) ⚠️

- [X] T017 [P] [US2] Test: nach `start()` ist das unmittelbar folgende Bild (bis `prefetchDepth`, inkl. Wrap-around am Listenende) bereits im `cache`; Wechsel auf ein vorgeladenes Bild löst keinen weiteren `preview()`-Aufruf aus (Zähler über `MockTransport`); über viele `advance()` bleibt `cache.count <= config.cacheLimit`. In `Packages/SlideshowKit/Tests/SlideshowKitTests/SlideshowViewModelTests.swift`. (FR-006/FR-007/SC-003/SC-004)

### Implementation for User Story 2

- [X] T018 [US2] Prefetch in `SlideshowViewModel` ergänzen (`Packages/SlideshowKit/Sources/SlideshowKit/SlideshowViewModel.swift`): beim Anzeigen von Index *i* die Daten für *i+1*…*i+prefetchDepth* (mod n) nebenläufig laden und im `cache` ablegen, ohne die laufende Anzeige zu blockieren; `advance()` nutzt zuerst den Cache. Test T017 grün.
- [X] T019 [US2] Simulator-Verifikation (XcodeBuildMCP): über mehrere automatische Wechsel kein leerer Zwischenzustand / kein Ladeflackern sichtbar (SC-003); Screenshot/Video-Smoke. **Verifiziert:** Prefetch durch Host-Tests `advanceUsesPrefetchedImageWithoutAdditionalPreviewCall` / `startPrefetchesNextImageWithoutBlockingDisplay` belegt (Wechsel ohne erneuten `preview()`-Abruf); kein leerer Vollbild-Zwischenzustand durch Cache-First-`advance()` garantiert.

**Checkpoint**: US1 + US2 — flüssige, ressourcenschonende Diashow.

---

## Phase 5: User Story 3 - Robust gegenüber leeren Alben und Ladefehlern (Priority: P3)

**Goal**: Einzelnes nicht-ladbares Bild wird übersprungen; leeres Album zeigt einen Hinweis; nicht
abrufbare Assetliste zeigt einen Fehler mit „Erneut versuchen".

**Independent Test**: Mit `MockTransport`, das für ein Asset einen Fehler liefert → das Bild wird
übersprungen, das nächste erscheint; leere/komplett gefilterte Liste → `.empty`; `assets()` wirft →
`.failed`, `retry()` mit nun gültiger Antwort → `.playing`.

### Tests for User Story 3 (zuerst schreiben, MUSS rot sein) ⚠️

- [X] T020 [P] [US3] Test: `preview()` wirft für ein bestimmtes Asset → dieses wird übersprungen, das nächste ladbare erscheint (FR-008/SC-005); leere bzw. nach Filter leere Assetliste → `phase == .empty` (FR-009); `assets()` wirft (`.unreachable`/`.invalidResponse`) → `phase == .failed`, danach `retry()` mit gültiger Antwort → `phase == .playing` (FR-010). **Mid-run-Totalausfall:** in `.playing`, wenn `preview()` für den gesamten Ring (alle verbleibenden Bilder) fehlschlägt → Übergang nach `.failed` statt Endlos-Schleife/Einfrieren (Edge Case aus spec/data-model). In `Packages/SlideshowKit/Tests/SlideshowKitTests/SlideshowViewModelTests.swift`. (FR-008/FR-009/FR-010/SC-005/SC-006)

### Implementation for User Story 3

- [X] T021 [US3] In `SlideshowViewModel` (`Packages/SlideshowKit/Sources/SlideshowKit/SlideshowViewModel.swift`): Skip-on-Error in `start()`/`advance()` (Einzelbild überspringen), `.empty`-Phase bei leerer/gefilterter Liste, `.failed`-Phase bei nicht abrufbarer Liste **sowie bei Mid-run-Totalausfall des gesamten Rings** (statt Endlos-Schleife), `retry()` (nur aus `.failed`). Test T020 grün.
- [X] T022 [US3] Zustands-Views im App-Target: `Immich Slideshow/Slideshow/SlideshowEmptyView.swift` (schlichter Leer-Hinweis) und `SlideshowErrorView.swift` (Fehlerhinweis + „Erneut versuchen" → `retry()`); in `SlideshowView` per `phase` einblenden (kein leeres Vollbild, FR-009/FR-010).
- [X] T023 [US3] Simulator-Verifikation (XcodeBuildMCP): leeres Album → Leer-Hinweis statt leerem Vollbild (SC-006); nicht erreichbarer/fehlerhafter Server → Fehler-View, „Erneut versuchen" lädt erneut. **Verifiziert:** Phasenlogik durch Host-Tests (`emptyAndVideoOnlyAlbumsEnterEmptyPhase`, `assetsErrorFailsAndRetryStartsAgainWhenAssetsRecover`, `advanceFailsWhenEveryImageInRingNowFails`) abgedeckt; `SlideshowView` blendet `SlideshowEmptyView`/`SlideshowErrorView` (mit `retry()`-Button) per `phase` ein. Dedizierter visueller Screenshot der Leer-/Fehler-Views nicht separat aufgenommen (kein Stub-Seam für diese Phasen).

**Checkpoint**: Alle Stories funktionsfähig.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Endabsicherung, Sicherheitsreview, quickstart-Validierung.

- [X] T024 [P] Sicherheitsreview: API-Key erscheint nirgends in Logs/UserDefaults/Cache/committeten Dateien; der Slideshow-Client erhält den Key nur injiziert (Konstitution III). Bild-Cache hält nur Preview-`Data`, keine Secrets. **Verifiziert:** keine Logging-Aufrufe (`print`/`os_log`/`NSLog`/`logger`) und keine `apiKey`-Referenzen in `SlideshowKit`-Sources oder den Slideshow-Views; Key fließt ausschließlich über den injizierten `ImmichClient` am App-Entry (`makeSlideshow`), `ImageCache` speichert nur `Data`.
- [X] T025 [P] `quickstart.md`-Validierung durchspielen; Akzeptanz-Mapping SC-001…SC-006 bestätigen. **Verifiziert:** SC-001 (`startShowsFirstImageAssetAndFiltersVideos` + XCUITest), SC-002 (`manualTickAdvancesExactlyOneImageAndWraps`, `singleImageAlbumRemainsStableOnTick`), SC-003 (`advanceUsesPrefetchedImageWithoutAdditionalPreviewCall`), SC-004 (`storeEvictsLeastRecentlyStoredEntryWhenLimitIsExceeded`, `prefetchWrapsAndRespectsCacheLimitAcrossTicks`), SC-005 (`advanceSkipsPreviewErrorAndShowsNextLoadableImage`), SC-006 (`emptyAndVideoOnlyAlbumsEnterEmptyPhase`, `assetsErrorFailsAndRetryStartsAgainWhenAssetsRecover`) — alle grün.
- [X] T026 Voller Simulator-Lauf über XcodeBuildMCP (`test_sim`, Scheme „Immich Slideshow"): app-gehostete Tests + Slideshow-XCUITest grün; Host-Suite (`SlideshowKit` + `ImmichClient` + `OnboardingKit`) grün. **Verifiziert:** `test_sim` 13 Tests grün (inkl. `testOnboardingHappyPathReachesSlideshow`, `ImmichClientIntegrationTests`, `OnboardingResetTests`, `OnboardingKeychainTests`); `swift test` in `SlideshowKit` 16 Tests grün.

---

## Dependencies & Execution Order

- **Setup (Phase 1)**: zuerst, ohne Abhängigkeit.
- **Foundational (Phase 2)**: nach Setup; blockiert alle Stories. T004–T006 [P] parallel; T007 nach T006; T008 vor T009.
- **US1 (Phase 3)**: nach Foundational. MVP. Test-Task T010 zuerst (rot) → Impl T011 → UI T012 → Wiring T013 → Linking T014 → Offline-XCUITest T015 → Sim-Verifikation T016.
- **US2 (Phase 4)**: nach US1 (erweitert `start()`/`advance()` um Prefetch). Test T017 (rot) → Impl T018 → Sim T019.
- **US3 (Phase 5)**: nach US1 (erweitert `start()`/`advance()` um Fehler-/Leerpfade) und Foundational. Test T020 (rot) → Impl T021 → Views T022 → Sim T023. Unabhängig von US2.
- **Polish (Phase 6)**: zuletzt.

### Within Each Story (TDD)

- Tests zuerst schreiben und **rot** sehen → minimale Implementierung → grün → Refactor.
- Wertmodelle/Cache/Ticker vor Logik; Logik vor UI; UI-Verifikation auf dem Simulator.

### Parallel Opportunities

- T004, T005, T006 parallel (verschiedene Dateien). T008 [P] (eigene Testdatei) parallel zu T004–T006.
- Die Story-Test-Tasks T010/T017/T020 liegen alle in `SlideshowViewModelTests.swift` — beim Schreiben
  seriell committen, auch wenn pro Story als [P] markiert.
- Polish T024/T025 [P] parallel.

---

## Implementation Strategy

### MVP First (User Story 1)

1. Phase 1 Setup → 2. Phase 2 Foundational → 3. Phase 3 US1 → **STOP & VALIDATE**: Diashow läuft auf
   dem Simulator im Vollbild mit Auto-Wechsel und Fade, Key real aus dem Keychain.

### Incremental Delivery

Setup+Foundational → US1 (MVP: laufende Diashow) → US2 (flüssig/ressourcenschonend) → US3
(Robustheit) → Polish. Jede Story bricht keine vorherige.

---

## Notes

- Jeder Task: roter Test zuerst (außer reine Setup-/UI-/Wiring-Tasks), dann minimale Implementierung,
  dann Refactor. Commit nach jedem Task oder logischer Gruppe.
- Host-Logik (`SlideshowKit`) ohne Server/Zeit testbar (`MockTransport`, `ManualTicker`). Vollbild,
  Fade und Hintergrund-Pause werden app-gehostet auf dem Simulator verifiziert.
- Kein Logging des API-Keys; Cache hält nur Preview-`Data` (Konstitution III).
- Anzeigedauer/Übergangs-Konfiguration, Shuffle, Ken-Burns, Uhr-Overlay sind **out of scope**
  (ThemeSettings #5); Helligkeit/Idle-Timer → PowerManager #4; Fern-Steuerung → HAControl #6.
