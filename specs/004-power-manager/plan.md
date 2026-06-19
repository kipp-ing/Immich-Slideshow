# Implementation Plan: PowerManager (Display wach halten & Helligkeit steuern)

**Branch**: `004-power-manager` | **Date**: 2026-06-19 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/004-power-manager/spec.md`

## Summary

Während die Diashow im Vordergrund läuft, hält die App das Display wach (Leerlauf-Timer aus) und kann
die Bildschirmhelligkeit setzen (0.0–1.0) inkl. weichem Dimmen auf nahe 0 als „Display aus"-Ersatz.
Beim Verlassen wird der Leerlauf-Timer normalisiert und eine von der App geänderte Helligkeit auf den
erfassten Ausgangswert zurückgesetzt; alles wirkt nur im Vordergrund (Konstitution V).

Technischer Ansatz: ein neues lokales SPM-Paket `PowerKit` enthält die host-testbare Logik — ein
`@Observable @MainActor PowerManager` (Aktiv-Zustand, erfasster Helligkeits-Ausgangswert, Klemmen auf
0.0–1.0, Latest-Target-wins, Foreground-Gating, Restore-on-Exit) hinter zwei injizierten Nähten:
`ScreenControlling` abstrahiert den hardwarenahen Zugriff (Leerlauf-Timer-Flag + Helligkeit lesen/
schreiben), `PowerClock` abstrahiert die Zeit für das weiche Dimmen (deterministische Tests ohne echte
Wartezeit, analog zu `SlideshowTicker`). Ein `PowerConfig`-Wertmodell pinnt die v1-Defaults für die
Soft-Dim-Dauer/Schrittzahl. Die reale `ScreenControlling`-Implementierung (`UIScreen.main.brightness`,
`UIApplication.shared.isIdleTimerDisabled`) und die Lebenszyklus-Verdrahtung an `SlideshowView`
(`scenePhase`/Erscheinen/Verlassen) liegen im App-Target — so bleibt das Paket UIKit-frei und
host-testbar. Logik per Host-Tests (Swift Testing, Fake-`ScreenController` + manueller `PowerClock`);
das reale Wach-halten/Helligkeitsverhalten wird app-gehostet auf dem iPad-Simulator über XcodeBuildMCP
verifiziert.

## Technical Context

**Language/Version**: Swift 6

**Primary Dependencies**: SwiftUI, Observation (`@Observable`), Foundation für die Verdrahtung;
UIKit (`UIScreen`, `UIApplication`) nur in der realen `ScreenControlling`-Implementierung im
App-Target. Das Paket `PowerKit` selbst ist UIKit-frei (Foundation/Observation). Keine
Drittbibliotheken. Keine Abhängigkeit zu `ImmichClient`/`SlideshowKit` (reines Geräte-Power-Modul).

**Storage**: Kein persistenter Speicher. Der Helligkeits-Ausgangswert wird flüchtig im
`PowerManager` gehalten (nur für die Wiederherstellung innerhalb einer Diashow-Sitzung). Keine
UserDefaults, kein Keychain (kein Secret).

**Testing**: Swift Testing (`@Test`). Paketlogik als Host-Tests (`swift test`): Fake-
`ScreenControlling` zeichnet Helligkeitsschreibvorgänge und das Leerlauf-Flag auf; ein manueller
`PowerClock` treibt das weiche Dimmen Schritt für Schritt deterministisch ohne echte Zeit.
Reales Wach-halten/Helligkeit als app-gehostete Verifikation auf dem iPad-Simulator über
XcodeBuildMCP (`test_sim` / Screenshot-Smoke).

**Target Platform**: iPadOS 18+ (SwiftUI). `PowerKit`-Logik plattformneutral (iOS + macOS-Host)
testbar; UIKit-abhängiger Zugriff (Leerlauf-Timer, Helligkeit) nur im App-Target/Simulator.

**Project Type**: Mobile-App-Feature — lokales SPM-Paket `PowerKit` + reale `ScreenControlling`-
Implementierung und Lebenszyklus-Verdrahtung im App-Target „Immich Slideshow".

**Performance Goals**: Weiches Dimmen ruckelfrei (kurze Übergangsanimation, feste v1-Schrittzahl/
-Dauer). Vernachlässigbarer Overhead; keine Dauerlast (kein Polling — Steuerung erfolgt
ereignisgetrieben über Lebenszyklus-Signale und explizite `setBrightness`-Aufrufe).

**Constraints**: Leerlauf-Timer und Helligkeit wirken **nur im Vordergrund**; im Hintergrund gibt die
App die Kontrolle an iOS zurück und überschreibt nichts (Konstitution V, FR-003/FR-009). Kein
physisches Display-Aus (nur Dimmen gegen ~0, FR-008). Kein verstecktes Singleton — `ScreenControlling`
und `PowerClock` injiziert (Konstitution II, FR-013). Kein Secret (Konstitution III). Ruhige,
nicht aufgedrängte Defaults (Konstitution VII): Helligkeitssteuerung greift nur, wenn explizit
ausgelöst.

**Scale/Scope**: Ein Gerät, ein Nutzer, eine Vordergrund-Sitzung. Ein `PowerManager` + zwei Nähte
(`ScreenControlling`, `PowerClock`) + ein `PowerConfig`. Reale `ScreenControlling`-Impl (~1 kleine
Datei) + Verdrahtung in `SlideshowView`/App-Entry.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Prinzip | Bewertung | Status |
|---------|-----------|--------|
| I. Test-First (NON-NEGOTIABLE) | TDD: rote Tests für Klemmen, Foreground-Gating, Restore-on-Exit, Latest-Target-wins und Soft-Dim-Zwischenschritte (über Fake-`ScreenController` + manuellen `PowerClock`) **vor** Implementierung; reales Wach-halten/Helligkeit auf dem Simulator verifiziert. | ✅ |
| II. Modulare Isolation | `ScreenControlling` (Hardwarezugriff) und `PowerClock` (Zeit) als injizierte Protokolle; `PowerManager` ohne Singletons, deterministisch testbar ohne echtes Display. | ✅ |
| III. Keine Secrets im Klartext (NON-NEGOTIABLE) | Kein neues Secret; PowerManager fasst keine Credentials an, hält nur einen flüchtigen Helligkeits-Ausgangswert. | ✅ |
| IV. Sicherheit der Transportschicht | Nicht betroffen (kein Netzwerk). | ✅ (n/a) |
| V. Plattformgrenzen respektieren | **Kernprinzip dieses Features:** Steuerung nur im Vordergrund; Hintergrund gibt Kontrolle an iOS zurück; kein Display-Aus (nur Dimmen ~0); kein erzwungenes Überschreiben nutzergesetzter Werte im Hintergrund (FR-003/FR-008/FR-009). | ✅ |
| VI. Verifizierbare Akzeptanzkriterien | Spec liefert messbare SC-001…SC-006; quickstart.md mappt sie auf Host-/Sim-Tests. | ✅ |
| VII. Schlicht und hell als Default | Keine aufgedrängten Effekte; Helligkeit ändert sich nur auf explizite Auslösung, Soft-Dim ruhig. Konkrete Dim-Werte/Trigger-UI sind deferred an ThemeSettings #5. | ✅ |

**Ergebnis: PASS — keine Verletzungen, keine Komplexitäts-Ausnahmen nötig.**

## Project Structure

### Documentation (this feature)

```text
specs/004-power-manager/
├── plan.md              # This file
├── research.md          # Phase 0 output (Nähte, Soft-Dim-Modell, Foreground-Gating, Restore)
├── data-model.md        # Phase 1 output (Entitäten + Zustandsübergänge)
├── quickstart.md        # Phase 1 output (SC-Mapping auf Tests)
├── contracts/           # Phase 1 output (PowerManager / ScreenControlling / PowerClock)
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
Packages/
├── ImmichClient/                        # bestehend; unverändert
├── OnboardingKit/                       # bestehend; unverändert
├── SlideshowKit/                        # bestehend; unverändert
└── PowerKit/                            # NEU
    ├── Package.swift                    # Swift 6, iOS 18 + macOS-Host; keine externen Deps
    ├── Sources/PowerKit/
    │   ├── PowerConfig.swift            # Soft-Dim-Dauer/Schritte (feste v1-Defaults)
    │   ├── ScreenControlling.swift      # Protokoll: Leerlauf-Flag + Helligkeit lesen/schreiben
    │   ├── PowerClock.swift             # Protokoll + RealClock (Task.sleep); Test-Clock in Tests
    │   └── PowerManager.swift           # @Observable @MainActor; aktivieren/deaktivieren, setBrightness, Hintergrund/Vordergrund
    └── Tests/PowerKitTests/
        ├── Fakes.swift                  # FakeScreenController (zeichnet Schreibvorgänge), ManualClock
        ├── PowerManagerTests.swift      # Klemmen, Foreground-Gating, Restore-on-Exit, Latest-wins
        └── BrightnessRampTests.swift    # Soft-Dim erreicht Zielwert über Zwischenschritte (SC-004)

Immich Slideshow/                        # App-Target
├── Immich_SlideshowApp.swift            # PowerManager bauen (reale ScreenControlling) und in SlideshowView reichen (DEBUG: --uitest-Fake)
└── Slideshow/
    ├── SlideshowView.swift              # Lebenszyklus-Verdrahtung: erscheinen→activate, scenePhase→Vordergrund/Hintergrund, verlassen→deactivate
    └── UIScreenController.swift         # NEU: reale ScreenControlling-Impl (UIScreen.main.brightness, UIApplication.shared.isIdleTimerDisabled)

Immich SlideshowUITests/                 # hermetische XCUITests (Simulator)
└── (optional) PowerLifecycleUITests     # Smoke über --uitest-Naht, falls sinnvoll observierbar
```

**Structure Decision**: Testbare Logik in `Packages/PowerKit` (Foundation/Observation, host-testbar,
„Modulare Isolation") — analog zu `OnboardingKit`/`SlideshowKit`. Der hardwarenahe Zugriff
(`UIScreen`/`UIApplication`) liegt hinter `ScreenControlling` und wird nur im App-Target real
implementiert (`UIScreenController`), damit das Paket UIKit-frei und auf dem Host testbar bleibt. Die
Zeit für das weiche Dimmen wird über `PowerClock` injiziert (deterministische Soft-Dim-Tests ohne
echte Wartezeit, analog zur `SlideshowTicker`-Naht aus 003). Das App-Target bindet `PowerKit` ein und
verdrahtet den Lebenszyklus an `SlideshowView`. Begründung gegen Default-`src/`: Swift/SPM-Konventionen
und bestehende Projektstruktur.

## Complexity Tracking

> Keine Constitution-Verletzungen — Abschnitt leer.
