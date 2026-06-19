# Quickstart & Validation: PowerManager

Runnable-Validierung des Features. Host-Tests sichern die Logik; der Simulator verifiziert das reale
Leerlauf-Timer-/Helligkeitsverhalten. Befehle laufen über XcodeBuildMCP (nicht roher `xcodebuild`).

## Voraussetzungen

- Feature 003 (`SlideshowView`) vorhanden; liefert die Lebenszyklus-Signale (Erscheinen/Verlassen,
  `scenePhase` Vordergrund/Hintergrund), an die der `PowerManager` angehängt wird.
- Neues Paket `Packages/PowerKit` ins App-Target eingebunden (wie `SlideshowKit`/`OnboardingKit`).

## Logik-Tests (Host, schnell)

```text
swift test  (im Paket Packages/PowerKit)  bzw. test_sim für das App-Target
```

- `FakeScreenController` zeichnet Helligkeits-Schreibvorgänge (`brightnessWrites`) und das
  Leerlauf-Flag auf.
- `ManualClock` lässt die Soft-Dim-Ramp ohne echte Zeit synchron durchlaufen, sodass Zwischenwerte
  beobachtbar sind.

## Akzeptanz-Mapping (Spec → Validierung)

| Kriterium | Validierung |
|-----------|-------------|
| **SC-001** Display bleibt im Vordergrund wach | PowerManager-Test: `activate()` → `screen.isIdleTimerDisabled == true`, `isKeepingAwake == true`. Sim: Diashow läuft, Display bleibt an. |
| **SC-002** Leerlauf normal nach Verlassen | PowerManager-Test: `deactivate()` → `isIdleTimerDisabled == false`. Sim: nach Verlassen dunkelt das Gerät wieder nach Leerlaufzeit ab. |
| **SC-003** Zielhelligkeit erreicht, Klemmen | PowerManager-Test: `setBrightness(0.4, animated:false)` → letzter Write == 0.4; `setBrightness(1.5)` → 1.0; `setBrightness(-0.2)` → 0.0. |
| **SC-004** Weiches Dimmen über Zwischenschritte | PowerManager-Test (`ManualClock`): `setBrightness(0.0, animated:true)` von 0.8 → `brightnessWrites` enthält ≥ 1 Zwischenwert zwischen 0.8 und 0.0, endet bei 0.0. |
| **SC-005** Ausgangshelligkeit nach Verlassen | PowerManager-Test: baseline 0.7, `setBrightness(0.1)`, `deactivate()` → letzter Write == 0.7. Ohne vorheriges Setzen: `deactivate()` schreibt keine Helligkeit. |
| **SC-006** Im Hintergrund keine Änderungen | PowerManager-Test: `didEnterBackground()` dann `setBrightness(0.2)` → kein neuer `brightness`-Write; `isIdleTimerDisabled == false`. |

## Simulator-Verifikation (XcodeBuildMCP)

1. Diashow starten → Gerät bleibt wach (Leerlauf-Timer aus); per Verdrahtung über die injizierte Naht
   verifiziert (richtige `activate`-Aufrufe), da echte Leerlaufzeit im CI nicht praktikabel abwartbar.
2. Helligkeit setzen/dimmen → Bildschirmhelligkeit ändert sich sichtbar (Screenshot-Smoke); Dimmen
   auf nahe 0 lässt das Bild sehr dunkel, aber nicht aus.
3. App in den Hintergrund und zurück → `deactivate`/`didEnterBackground`/`willEnterForeground` werden
   korrekt ausgelöst (Leerlauf-Timer-Zustand folgt); kein Überschreiben im Hintergrund.
4. Diashow verlassen → Leerlauf-Timer normal, ggf. Ausgangshelligkeit wiederhergestellt.

## Out of Scope (nicht hier prüfen)

- Fernsteuerung der Helligkeit / Pause / Album → HAControl (#6).
- Zeitpläne/Automationen und Theme-/Einstellungs-UI → ThemeSettings (#5).
- Physisches Abschalten des Displays (von iOS nicht möglich — nur Dimmen auf nahe 0).
