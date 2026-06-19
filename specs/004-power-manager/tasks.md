# Tasks: PowerManager (Display wach halten & Helligkeit steuern)

**Input**: Design documents from `/specs/004-power-manager/`

**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓

**Tests**: TDD ist laut Konstitution (Prinzip I, NON-NEGOTIABLE) verbindlich → Test-Tasks sind
enthalten und werden **vor** der Implementierung geschrieben und müssen zuerst **rot** sein.

**Organization**: Nach User Stories gruppiert; jede Story ist unabhängig testbar.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: parallelisierbar (andere Datei, keine offenen Abhängigkeiten)
- **[Story]**: zugehörige User Story (US1, US2, US3)
- Pfade relativ zum Repo-Root. Neues Paket unter `Packages/PowerKit/`; reale Naht + Verdrahtung im App-Target.

**Orchestrierung** (CLAUDE.md): Host-testbare Logik (`PowerKit`: `PowerManager`, `PowerConfig`, Nähte)
eignet sich zum Delegieren an Codex (`swift test`). **Inline bei Claude:** das Concurrency-/Timing-
Test-Design der Soft-Dim-Ramp (Cancellation/Latest-Target-wins), die reale `ScreenControlling`-Impl
(`UIScreen`/`UIApplication`, nur Simulator), die `SlideshowView`-/`scenePhase`-Verdrahtung,
`*.pbxproj`-Verdrahtung und alle Simulator-Verifikationen.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Lokales SPM-Paket `PowerKit` anlegen, baubar und host-testbar.

- [ ] T001 SPM-Paket-Gerüst anlegen: `Packages/PowerKit/Package.swift` (Swift 6, Plattform iOS 18 / macOS-Host; Target `PowerKit` ohne externe Dependencies; Test-Target `PowerKitTests` mit Dependency `PowerKit`).
- [ ] T002 Quell- und Testverzeichnisse anlegen: `Packages/PowerKit/Sources/PowerKit/` und `Packages/PowerKit/Tests/PowerKitTests/`.
- [ ] T003 Leeren Build verifizieren (Paket baut, leere Suite grün via `swift build`/`swift test` auf dem Host).

**Checkpoint**: Paket existiert und baut.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Geteilte Wertmodelle, Nähte und Test-Fakes, die alle Stories brauchen.

**⚠️ CRITICAL**: Muss vor allen User Stories fertig sein.

- [ ] T004 [P] `PowerConfig` (`softDimDuration: Duration`, `softDimSteps: Int`; `Sendable`, `Equatable`; statische `.default` mit **konkret gepinnten** v1-Werten: `softDimDuration = .milliseconds(600)`, `softDimSteps = 8`; Invarianten `softDimSteps >= 2`, `softDimDuration > .zero`) in `Packages/PowerKit/Sources/PowerKit/PowerConfig.swift`.
- [ ] T005 [P] `ScreenControlling`-Protokoll (`@MainActor`, `AnyObject`; `var brightness: Double { get set }`, `var isIdleTimerDisabled: Bool { get set }`) in `Packages/PowerKit/Sources/PowerKit/ScreenControlling.swift`.
- [ ] T006 [P] `PowerClock`-Protokoll (`func sleep(for: Duration) async throws`, `Sendable`) + `RealClock()` (über `Task.sleep`/`ContinuousClock`, respektiert Cancellation) in `Packages/PowerKit/Sources/PowerKit/PowerClock.swift`.
- [ ] T007 Test-Fakes: `FakeScreenController` (`@MainActor`; speichert `isIdleTimerDisabled`; zeichnet jede Helligkeits-Schreibung in `brightnessWrites: [Double]` auf; `brightness`-Getter liefert den letzten gesetzten Wert, Startwert injizierbar) und `ManualClock` (`sleep` kehrt sofort zurück) in `Packages/PowerKit/Tests/PowerKitTests/Fakes.swift`.

**Checkpoint**: Foundation steht — User Stories können beginnen.

---

## Phase 3: User Story 1 - Display bleibt während der Diashow wach (Priority: P1) 🎯 MVP

**Goal**: Im Vordergrund Leerlauf-Timer deaktivieren; beim Verlassen normalisieren; nur im Vordergrund
wirksam (Hintergrund gibt Kontrolle zurück, Vordergrund stellt wieder her).

**Independent Test**: Mit `FakeScreenController`: `activate()` → `isIdleTimerDisabled == true`,
`isKeepingAwake == true`; `didEnterBackground()` → `false`; `willEnterForeground()` → wieder `true`;
`deactivate()` → `false`.

### Tests for User Story 1 (zuerst schreiben, MUSS rot sein) ⚠️

- [ ] T008 [P] [US1] Test: `PowerManager.activate()` setzt `screen.isIdleTimerDisabled == true` und `isKeepingAwake == true`; `deactivate()` setzt beide auf `false` (FR-001/FR-002/SC-001/SC-002); `didEnterBackground()` gibt den Leerlauf-Timer frei (`false`) ohne Helligkeits-Write; `willEnterForeground()` bei laufender Sitzung stellt `true` wieder her (FR-003/FR-004/SC-006); mehrfaches `activate()`/Hintergrund-Vordergrund-Wechsel führt zu konsistentem Endzustand (kein „hängender" deaktivierter Timer). In `Packages/PowerKit/Tests/PowerKitTests/PowerManagerTests.swift`. (FR-001/FR-002/FR-003/FR-004/SC-001/SC-002)

### Implementation for User Story 1

- [ ] T009 [US1] `PowerManager` (`@MainActor @Observable`) in `Packages/PowerKit/Sources/PowerKit/PowerManager.swift`: injizierte `screen: ScreenControlling`, `clock: PowerClock`, `config: PowerConfig`; `isKeepingAwake` (read-only); `activate()` (Ausgangshelligkeit erfassen, `isIdleTimerDisabled = true`), `deactivate()` (`isIdleTimerDisabled = false`, internen Zustand zurücksetzen), `didEnterBackground()`/`willEnterForeground()` (Foreground-Gate). Helligkeits-Logik (US2) und Restore (US3) folgen. Test T008 grün.
- [ ] T010 [US1] Reale Naht im App-Target: `Immich Slideshow/Slideshow/UIScreenController.swift` (`final class UIScreenController: ScreenControlling`, `@MainActor`): `brightness` ↔ `UIScreen.main.brightness`, `isIdleTimerDisabled` ↔ `UIApplication.shared.isIdleTimerDisabled`.
- [ ] T011 [US1] `PowerKit` als lokale Paket-Abhängigkeit ins App-Target „Immich Slideshow" einbinden (`*.xcodeproj/project.pbxproj`: `XCLocalSwiftPackageReference` + `XCSwiftPackageProductDependency` + Frameworks-Verknüpfung). App baut auf dem iPad-Simulator.
- [ ] T012 [US1] Lebenszyklus-Verdrahtung in `Immich Slideshow/Slideshow/SlideshowView.swift` (+ ggf. `Immich_SlideshowApp.swift`): `PowerManager` mit `UIScreenController` bauen und injizieren; beim Erscheinen `activate()`, beim Verlassen `deactivate()`; `scenePhase` an `willEnterForeground()`/`didEnterBackground()` binden (FR-003/FR-004). Bestehende `scenePhase`-Pause/Resume der Slideshow bleibt erhalten. **DEBUG/`--uitest`:** Fake-`ScreenControlling` statt `UIScreenController` injizieren, damit der hermetische Lauf die echte Helligkeit nicht verstellt.
- [ ] T013 [US1] Simulator-Verifikation (XcodeBuildMCP): bei laufender Diashow ist der Leerlauf-Timer deaktiviert (über die injizierte Naht/Verdrahtung verifiziert, da echte Leerlaufzeit im CI nicht praktikabel abwartbar); App in den Hintergrund/Vordergrund → Naht folgt; Verlassen → Leerlauf-Timer normal.

**Checkpoint**: US1 unabhängig funktionsfähig — Display bleibt im Vordergrund wach (MVP).

---

## Phase 4: User Story 2 - Helligkeit setzen und sanft dimmen (Priority: P2)

**Goal**: Zielhelligkeit (0.0–1.0, geklemmt) hart oder weich setzen; weiches Dimmen über
Zwischenschritte; nur im Vordergrund; Latest-Target-wins; Hintergrund stoppt.

**Independent Test**: Mit `FakeScreenController` + `ManualClock`: `setBrightness(0.4, animated:false)`
→ letzter Write 0.4; `setBrightness(1.5)` → 1.0; `setBrightness(0.0, animated:true)` von 0.8 →
`brightnessWrites` enthält Zwischenwerte, endet bei 0.0; im Hintergrund No-Op.

### Tests for User Story 2 (zuerst schreiben, MUSS rot sein) ⚠️

- [ ] T014 [P] [US2] Test: `setBrightness(_:animated:false)` schreibt den geklemmten Zielwert (Werte außerhalb 0.0–1.0 → 0.0/1.0, FR-006/SC-003); `setBrightness(_:animated:true)` erreicht den Zielwert über ≥ 1 beobachtbaren Zwischenwert (`ManualClock`, FR-007/SC-004); ein neuer `setBrightness`-Aufruf während laufender Ramp setzt sich durch (Latest-Target-wins, FR-012); im Hintergrund (`didEnterBackground()`) ist `setBrightness` ein No-Op (kein neuer `brightness`-Write, FR-009/SC-006). In `Packages/PowerKit/Tests/PowerKitTests/BrightnessRampTests.swift`. (FR-005/FR-006/FR-007/FR-008/FR-009/FR-012/SC-003/SC-004/SC-006)

### Implementation for User Story 2

- [ ] T015 [US2] `setBrightness(_ value: Double, animated: Bool) async` in `PowerManager` (`Packages/PowerKit/Sources/PowerKit/PowerManager.swift`): Klemmen auf `0...1`; Hintergrund → No-Op; `animated == false` → sofort schreiben; `animated == true` → Ramp über `config.softDimSteps` mit `clock.sleep(for:)` zwischen den Schritten als abbrechbarer `Task`, bestehende Ramp beim neuen Ziel abbrechen (Latest-wins); `didEnterBackground()` bricht laufende Ramp ab. Markiert intern „Helligkeit verändert" (für US3). Test T014 grün.
- [ ] T016 [US2] Simulator-Verifikation (XcodeBuildMCP): eine gesetzte Helligkeit ist sichtbar (Screenshot-Smoke); Dimmen auf nahe 0 lässt das Bild sehr dunkel, aber nicht aus (FR-008).

**Checkpoint**: US1 + US2 — Display wach + steuerbare/dimmbare Helligkeit.

---

## Phase 5: User Story 3 - Helligkeit beim Verlassen zurücksetzen (Priority: P3)

**Goal**: Beim Verlassen eine von der App geänderte Helligkeit auf den erfassten Ausgangswert
zurücksetzen; ungeänderte Helligkeit unangetastet lassen; Ausgangswert nicht erfassbar → nichts
erzwingen.

**Independent Test**: Mit `FakeScreenController`: Startwert 0.7, `activate()`, `setBrightness(0.1)`,
`deactivate()` → letzter Write 0.7; ohne vorheriges Setzen schreibt `deactivate()` keine Helligkeit.

### Tests for User Story 3 (zuerst schreiben, MUSS rot sein) ⚠️

- [ ] T017 [P] [US3] Test: `activate()` erfasst die Ausgangshelligkeit; nach `setBrightness(...)` und `deactivate()` wird der Ausgangswert wiederhergestellt (letzter `brightness`-Write == baseline, FR-010/FR-011/SC-005); hat die App die Helligkeit **nicht** verändert, schreibt `deactivate()` keine Helligkeit (FR-011); im Hintergrund gesetzte Werte werden nicht überschrieben (FR-009/SC-006); fehlender/ nicht erfassbarer Ausgangswert → `deactivate()` erzwingt keine Helligkeit (Edge Case). In `Packages/PowerKit/Tests/PowerKitTests/PowerManagerTests.swift`. (FR-010/FR-011/SC-005)

### Implementation for User Story 3

- [ ] T018 [US3] In `PowerManager` (`Packages/PowerKit/Sources/PowerKit/PowerManager.swift`): `baselineBrightness` bei `activate()` aus `screen.brightness` erfassen; `didChangeBrightness`-Flag bei `setBrightness` setzen; `deactivate()` stellt `baselineBrightness` nur wieder her, wenn `didChangeBrightness && baselineBrightness != nil`; danach internen Zustand zurücksetzen. Test T017 grün.
- [ ] T019 [US3] Simulator-Verifikation (XcodeBuildMCP): Ausgangshelligkeit merken, Diashow starten, Helligkeit ändern, verlassen → Helligkeit entspricht wieder dem Ausgangswert; Leerlauf-Timer normal.

**Checkpoint**: Alle Stories funktionsfähig.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Endabsicherung, Plattformgrenzen-Review, quickstart-Validierung.

- [ ] T020 [P] Plattformgrenzen-Review (Konstitution V): kein Display-Aus (nur Dimmen ~0); keine Schreibungen im Hintergrund; nach `deactivate()` immer Leerlauf-Timer frei; kein verstecktes Singleton (Nähte injiziert). Kein Secret berührt (Konstitution III).
- [ ] T021 [P] `quickstart.md`-Validierung durchspielen; Akzeptanz-Mapping SC-001…SC-006 bestätigen.
- [ ] T022 Voller Simulator-Lauf über XcodeBuildMCP (`test_sim`, Scheme „Immich Slideshow"): app-gehostete Tests grün; Host-Suite (`PowerKit` + bestehende Pakete) grün via `swift test`.

---

## Dependencies & Execution Order

- **Setup (Phase 1)**: zuerst, ohne Abhängigkeit.
- **Foundational (Phase 2)**: nach Setup; blockiert alle Stories. T004–T006 [P] parallel; T007 nach T005/T006.
- **US1 (Phase 3)**: nach Foundational. MVP. Test-Task T008 zuerst (rot) → Impl T009 → reale Naht T010 → Linking T011 → Verdrahtung T012 → Sim T013.
- **US2 (Phase 4)**: nach US1 (erweitert `PowerManager` um `setBrightness`). Test T014 (rot) → Impl T015 → Sim T016.
- **US3 (Phase 5)**: nach US1 (erweitert `activate()`/`deactivate()` um Baseline/Restore) und nach US2 (nutzt das „Helligkeit verändert"-Flag aus `setBrightness`). Test T017 (rot) → Impl T018 → Sim T019.
- **Polish (Phase 6)**: zuletzt.

### Within Each Story (TDD)

- Tests zuerst schreiben und **rot** sehen → minimale Implementierung → grün → Refactor.
- Wertmodelle/Nähte vor Logik; Logik vor realer Naht/Verdrahtung; UI-/Geräte-Verifikation auf dem Simulator.

### Parallel Opportunities

- T004, T005, T006 parallel (verschiedene Dateien). T008 [P] (eigene Testdatei) parallel zu T014/T017 nur, soweit sie in **verschiedenen** Dateien liegen: T008/T017 teilen `PowerManagerTests.swift` (seriell committen), T014 liegt in `BrightnessRampTests.swift` (echt parallel).
- Polish T020/T021 [P] parallel.

---

## Implementation Strategy

### MVP First (User Story 1)

1. Phase 1 Setup → 2. Phase 2 Foundational → 3. Phase 3 US1 → **STOP & VALIDATE**: Display bleibt im
   Vordergrund wach, Leerlauf-Timer folgt dem Lebenszyklus korrekt.

### Incremental Delivery

Setup+Foundational → US1 (MVP: Display wach) → US2 (Helligkeit/Soft-Dim) → US3 (Restore-on-Exit) →
Polish. Jede Story bricht keine vorherige.

---

## Notes

- Jeder Task: roter Test zuerst (außer reine Setup-/Naht-/Wiring-Tasks), dann minimale Implementierung,
  dann Refactor. Commit nach jedem Task oder logischer Gruppe.
- Host-Logik (`PowerKit`) ohne echtes Display/Zeit testbar (`FakeScreenController`, `ManualClock`).
  Reales Leerlauf-/Helligkeitsverhalten wird app-gehostet auf dem Simulator verifiziert.
- Plattformgrenzen (Konstitution V) sind das Kernprinzip: nur Vordergrund, kein Display-Aus, kein
  Überschreiben im Hintergrund.
- Konfigurierbare Dim-Werte/Trigger-UI, Zeitpläne und Fern-Steuerung sind **out of scope**
  (ThemeSettings #5 / HAControl #6).
