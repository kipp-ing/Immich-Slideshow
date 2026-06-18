# Phase 1 Data Model: SlideshowView

Entitäten und Zustände der Diashow. Alle Typen `Sendable`; Werte- vor Referenztypen, wo möglich.
Quelle der Bilddaten ist das bestehende `ImmichClient` (`Asset`, `preview(assetID:) -> Data`).

## Entitäten

### SlideshowConfig (Wertmodell)

Feste v1-Parameter der Diashow (keine UI-Konfiguration — das ist ThemeSettings, #5).

| Feld | Typ | Bedeutung | v1-Default |
|------|-----|-----------|------------|
| `interval` | `Duration` | Anzeigedauer pro Bild | `.seconds(8)` |
| `prefetchDepth` | `Int` | wie viele Bilder voraus geladen werden (1–2) | 2 |
| `cacheLimit` | `Int` | max. gleichzeitig gehaltene Bilder im Cache | 5 |

- `Sendable`, `Equatable`. Defaults als statische `SlideshowConfig.default`.
- Invarianten: `prefetchDepth >= 1`, `cacheLimit >= prefetchDepth + 1`.

### SlideshowPhase (Zustand)

```text
loading   – Assetliste wird geladen
playing   – mindestens ein Bild vorhanden; Diashow läuft (aktuelles Bild sichtbar)
empty     – Album enthält keine anzeigbaren Bilder (FR-009)
failed    – Assetliste nicht abrufbar (FR-010); erlaubt „Erneut versuchen"
```

- `Equatable`. `playing` trägt den aktuellen Bildbezug (Asset-ID + Daten) über den ViewModel-Zustand,
  nicht im Enum-Case (schlanke Phase).

### Slideshow-Reihenfolge (abgeleitet)

- Eingang: `[Asset]` aus `assets(albumID:)`.
- Gefiltert auf Standbilder (`Asset.type` == Bild-Diskriminator; Videos/sonstige raus, FR-011). Der
  konkrete `type`-Wert (Erwartung „IMAGE") wird gegen die laufende Immich-Instanz verifiziert, nicht
  geraten (Konstitution IV; in T011).
- Reihenfolge = Albumreihenfolge (kein Shuffle, Assumption).
- Index läuft modulo Länge → Endlosschleife (FR-005).

### ImageCache (begrenzter LRU)

| Aspekt | Festlegung |
|--------|------------|
| Schlüssel | `assetID: String` |
| Wert | `Data` (rohes Preview-Thumbnail) |
| Kapazität | `cacheLimit` (fest, aus `SlideshowConfig`) |
| Eviction | Least-Recently-Used: ältester Zugriff fällt zuerst raus |

- Operationen: `data(for:)`, `store(_:for:)`, `contains(_:)`, Count nie über `cacheLimit` (SC-004).
- Reiner Wertespeicher, kein UIKit, host-testbar.

## Zustandsübergänge (SlideshowViewModel)

```text
                 start()
   (init) ───────────────────────────► loading
                                          │
              assets() wirft / unreachable│            assets() → []  (oder alle gefiltert)
                       ▼                  │                   ▼
                    failed ◄──────────────┤            empty
                       │  retry()         │
                       └──────────────────┘
                                          │ assets() → ≥1 Bild
                                          ▼
                                       playing ──┐
                                          ▲      │ Ticker-Tick / advance()
                                          └──────┘  Index = (i+1) mod n, Fade
                                                    Einzelbild unladbar → skip zum nächsten (FR-008)
```

- **pause()/resume()** wirken nur auf den Lauf in `playing` (Foreground-Pause, FR-012); ändern die
  Phase nicht.
- **retry()** nur aus `failed`: erneuter `assets()`-Versuch → `loading` → `playing`/`empty`/`failed`.
- Aus `playing` kann bei vollständigem Ausfall aller Bilder erneut `empty`/`failed` erreicht werden
  (Album während des Betriebs geleert, Edge Case).

## Beziehungen / Abhängigkeiten

- `SlideshowViewModel` —benutzt→ `ImmichAPI` (injiziert), `SlideshowTicker` (injiziert),
  `ImageCache` (injiziert/erzeugt), `SlideshowConfig`, `albumID: String`.
- `albumID` + authentifizierter `ImmichAPI`-Client stammen aus der Onboarding-Konfiguration
  (`AppConfiguration` + Keychain), verdrahtet im App-Target.
- Kein neuer persistenter Speicher; Cache ist flüchtig.
