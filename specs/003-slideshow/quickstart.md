# Quickstart & Validation: SlideshowView

Runnable-Validierung des Features. Host-Tests sichern die Logik; der Simulator verifiziert Vollbild,
Fade und Hintergrund-Pause. Befehle laufen über XcodeBuildMCP (nicht roher `xcodebuild`).

## Voraussetzungen

- Feature 001 (`ImmichClient`) und 002 (`Onboarding`) vorhanden; abgeschlossenes Onboarding liefert
  `baseURL`, API-Key (Keychain) und `selectedAlbumID`.
- Neues Paket `Packages/SlideshowKit` ins App-Target eingebunden (wie `OnboardingKit`).

## Logik-Tests (Host, schnell)

```text
swift test  (im Paket Packages/SlideshowKit)  bzw. test_sim für das App-Target
```

- `MockTransport` (aus `ImmichClientTestSupport`) liefert Asset-/Preview-Antworten.
- `ManualTicker` treibt Wechsel deterministisch ohne echte Zeit.

## Akzeptanz-Mapping (Spec → Validierung)

| Kriterium | Validierung |
|-----------|-------------|
| **SC-001** erstes Bild im Vollbild ohne Bedienschritt | ViewModel-Test: `start()` → `phase == .playing`, `currentImageData != nil`; Sim: Vollbild zeigt Bild direkt nach `.done`. |
| **SC-002** Auto-Wechsel + Schleife über einen Durchlauf | ViewModel-Test: `ManualTicker` N Ticks → Bildfolge 1→2→…→n→1; Einzelbild bleibt stabil. |
| **SC-003** kein Ladeflackern (Prefetch) | ViewModel-Test: nächstes Bild nach `start()`/`advance()` bereits im Cache; Wechsel auf vorgeladenes Bild ohne neuen `preview()`-Aufruf (Aufrufzähler). |
| **SC-004** Cache-Obergrenze im Dauerbetrieb | `ImageCacheTests`: nach vielen `store()` ist `count <= limit`; ältester Eintrag verdrängt. |
| **SC-005** Einzelfehler → Skip statt Stillstand | ViewModel-Test: `preview()` wirft für ein Asset → übersprungen, nächstes ladbares erscheint. |
| **SC-006** leeres Album / nicht abrufbare Liste → Hinweis | ViewModel-Test: leere/gefilterte Liste → `.empty`; `assets()` wirft → `.failed`, `retry()` → `.playing`. Sim: Leer-/Fehler-View statt leerem Vollbild. |

## Simulator-Verifikation (XcodeBuildMCP)

1. App mit abgeschlossenem Onboarding starten → Diashow erscheint sofort im Vollbild (SC-001).
2. Beobachten/Screenshot über zwei, drei Wechsel → sanftes Fade, kein leerer Zwischenzustand
   (FR-004/SC-003).
3. App in den Hintergrund schicken und zurückholen → Lauf pausiert und setzt fort (FR-012);
   per `scenePhase`.
4. Hermetischer XCUITest über die `--uitest`-Naht: Stub-`ImmichAPI` mit mehreren Bildern → Diashow
   ohne Netz/Server deterministisch (siehe `docs/testing.md`).

## Out of Scope (nicht hier prüfen)

- Anzeigedauer/Übergangs-Konfiguration, Ken-Burns, Uhr-Overlay, Shuffle → ThemeSettings (#5).
- Helligkeit/Idle-Timer → PowerManager (#4). Fern-Pause/Albumwechsel → HAControl (#6).
