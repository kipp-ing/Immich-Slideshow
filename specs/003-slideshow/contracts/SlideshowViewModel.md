# Contract: SlideshowViewModel

Verhaltensvertrag der Diashow-Logik. `@Observable`, `@MainActor`, host-testbar, alle Abhängigkeiten
injiziert (`ImmichAPI`, `SlideshowTicker`, `ImageCache`, `SlideshowConfig`, `albumID`).

## Signatur

```swift
@MainActor
@Observable
public final class SlideshowViewModel {
    public init(api: ImmichAPI,
                albumID: String,
                ticker: SlideshowTicker,
                cache: ImageCache = ImageCache(limit: SlideshowConfig.default.cacheLimit),
                config: SlideshowConfig = .default)

    // Zustand (observiert von der View):
    public private(set) var phase: SlideshowPhase            // loading / playing / empty / failed
    public private(set) var currentAssetID: String?         // aktuelles Bild (in .playing)
    public private(set) var currentImageData: Data?         // Preview-Data des aktuellen Bildes

    public func start() async        // Assetliste laden, ersten anzeigbaren Frame setzen, Lauf starten
    public func advance() async      // einen Schritt vorrücken (Index+1 mod n, Skip-on-Error, Prefetch)
    public func retry() async        // nur aus .failed: erneuter Ladeversuch
    public func pause()              // Foreground-Pause: Ticker-Lauf anhalten (FR-012)
    public func resume()             // Lauf fortsetzen
}
```

## Verhalten je Aktion

- **start()**
  - `phase = loading`; ruft `assets(albumID:)`.
  - Wirft/`.unreachable`/`.invalidResponse` → `phase = failed` (FR-010).
  - Liste leer oder nach Bild-Filter (FR-011) leer → `phase = empty` (FR-009).
  - Sonst: Reihenfolge = gefilterte Albumreihenfolge; lädt das erste anzeigbare Bild (skip bei
    Einzelfehler), setzt `currentAssetID`/`currentImageData`, `phase = playing`, stößt Prefetch der
    nächsten `prefetchDepth` Bilder an und startet den Ticker-Lauf.
- **advance()**
  - In `playing`: Index = `(i+1) mod n`; nutzt Cache, sonst Abruf. Schlägt das Bild fehl, wird es
    übersprungen und das nächste ladbare gesucht (FR-008/SC-005); sind ab dem aktuellen Punkt alle
    unladbar (ganzer Ring), bleibt das letzte gute Bild bzw. → `failed`.
  - Aktualisiert `currentAssetID`/`currentImageData`, stößt Prefetch der nächsten Bilder an
    (Wrap-around am Ende → erstes Bild, FR-005/FR-006).
- **retry()**: nur aus `failed`; verhält sich wie `start()`.
- **pause()/resume()**: hält bzw. setzt den Ticker-getriebenen Vorlauf; ändert die Phase nicht;
  verdrahtet an `scenePhase` im App-Target (FR-012).

## Timing

- Der Lauf vollzieht Wechsel über den injizierten `SlideshowTicker` (siehe
  [SlideshowTicker.md](./SlideshowTicker.md)) — nicht über rohe `Task.sleep` im ViewModel.
- `advance()` ist auch ohne Ticker direkt aufrufbar, damit Reihenfolge/Schleife/Skip ohne echte Zeit
  geprüft werden können.

## Tests (TDD, Host)

- **US1**: Album mit ≥2 Bildern → `start()` setzt erstes Bild, `phase == .playing`; `advance()` zeigt
  das zweite; nach dem letzten wieder das erste (Schleife). Einzelbild-Album: `advance()` bleibt beim
  selben Bild ohne Fehler.
- **US2**: Nach `start()`/`advance()` liegt das jeweils nächste Bild bereits im Cache (Prefetch); ein
  Wechsel auf ein vorgeladenes Bild löst keinen erneuten `preview()`-Abruf aus (über `MockTransport`-
  Aufrufzähler geprüft).
- **US3**: `preview()` wirft für ein bestimmtes Asset → dieses wird übersprungen, nächstes erscheint.
  Leere/komplett gefilterte Liste → `phase == .empty`. `assets()` wirft → `phase == .failed`;
  `retry()` mit nun gültiger Antwort → `playing`.
- **Timing**: `ManualTicker` treibt N Ticks → erwartete Bildfolge (deterministisch, ohne echte Zeit).
