# Phase 1 Data Model: PowerManager

Flüchtige In-Memory-Entitäten; kein persistenter Speicher.

## Entitäten

### PowerConfig (Wertmodell, `Sendable`, `Equatable`)

| Feld | Typ | Bedeutung | v1-Default |
|------|-----|-----------|------------|
| `softDimDuration` | `Duration` | Gesamtdauer einer weichen Helligkeitsänderung | `.milliseconds(600)` |
| `softDimSteps` | `Int` | Anzahl Zwischenschritte der Ramp (≥ 2) | `8` |

- Statische `.default` mit konkret gepinnten v1-Werten.
- Invarianten: `softDimSteps >= 2` (mind. ein beobachtbarer Zwischenwert, SC-004),
  `softDimDuration > .zero`.

### Brightness-Ziel (intern, parameterisiert über `setBrightness`)

| Feld | Typ | Bedeutung |
|------|-----|-----------|
| `target` | `Double` | angefragter Zielwert, geklemmt auf `0.0...1.0` (FR-006) |
| `animated` | `Bool` | `true` = weiche Ramp über `PowerConfig`; `false` = harter Sprung |

### PowerManager (Beobachtbarer Zustand, `@MainActor @Observable`)

| Feld | Typ | Bedeutung |
|------|-----|-----------|
| `isKeepingAwake` | `Bool` (read-only) | ob das Display aktuell wach gehalten wird (Leerlauf-Timer aus) |
| `isForegroundActive` | intern `Bool` | ob die Sitzung im Vordergrund aktiv ist (Gate für alle Schreibungen) |
| `baselineBrightness` | intern `Double?` | beim ersten `activate()` erfasster Ausgangswert; `nil` = nicht erfassbar |
| `didChangeBrightness` | intern `Bool` | ob die App seit `activate()` die Helligkeit geschrieben hat (steuert Restore) |
| (Abhängigkeiten) | `ScreenControlling`, `PowerClock`, `PowerConfig` | injiziert (Konstitution II) |

## Operationen (Kontrakt-Verhalten)

- `activate()` — Vordergrund-Sitzung beginnt (Diashow erscheint): erfasst `baselineBrightness` aus
  `screen.brightness`, setzt `isForegroundActive = true`, `screen.isIdleTimerDisabled = true`,
  `isKeepingAwake = true`. Idempotent (mehrfacher Aufruf ändert nichts Weiteres).
- `setBrightness(_ value: Double, animated: Bool)` — klemmt `value` auf `0...1`; im Hintergrund
  (`!isForegroundActive`) **No-Op**. Sonst: markiert `didChangeBrightness = true`, bricht eine
  laufende Ramp ab; `animated == false` → sofort `screen.brightness = value`; `animated == true` →
  Ramp über `softDimSteps` Zwischenschritte mit `clock.sleep` zwischen den Schritten bis zum Zielwert.
- `didEnterBackground()` — `isForegroundActive = false`; bricht laufende Ramp ab; setzt
  `screen.isIdleTimerDisabled = false`, `isKeepingAwake = false`; **schreibt keine Helligkeit**.
- `willEnterForeground()` — nur wenn die Sitzung logisch noch läuft (zwischen `activate` und
  `deactivate`): `isForegroundActive = true`, `screen.isIdleTimerDisabled = true`,
  `isKeepingAwake = true`.
- `deactivate()` — Sitzung endet (Diashow verlassen/beendet): bricht laufende Ramp ab; setzt
  `screen.isIdleTimerDisabled = false`, `isKeepingAwake = false`; falls `didChangeBrightness` **und**
  `baselineBrightness != nil` → `screen.brightness = baselineBrightness`. Setzt internen Zustand
  zurück (`didChangeBrightness = false`, `baselineBrightness = nil`, `isForegroundActive = false`).

## Zustandsübergänge

```text
            activate()                 deactivate()
  (idle) ───────────────▶ (active, awake) ───────────────▶ (idle, restored)
                              │   ▲
        didEnterBackground()  │   │ willEnterForeground()
                              ▼   │
                         (suspended: idle-timer freigegeben,
                          keine Schreibungen, Ramp gestoppt)
```

- In `(active, awake)`: `setBrightness` wirkt (hart/weich), Latest-Target-wins.
- In `(suspended)`: alle Schreibungen No-Op; iOS hat die Kontrolle (Konstitution V).
- `deactivate()` aus jedem Zustand führt nach `(idle)` und stellt — falls verändert — den Ausgangswert
  wieder her.

## Invarianten

- Helligkeit, die `PowerManager` schreibt, liegt immer in `0.0...1.0`.
- Nach `deactivate()` ist der Leerlauf-Timer immer freigegeben (`isIdleTimerDisabled == false`).
- Im Hintergrund schreibt `PowerManager` weder Helligkeit noch Leerlauf-Flag (außer dem Freigeben des
  Flags beim Übergang in den Hintergrund).
- Wurde die Helligkeit nie von der App geschrieben, wird sie bei `deactivate()` nicht angefasst.
