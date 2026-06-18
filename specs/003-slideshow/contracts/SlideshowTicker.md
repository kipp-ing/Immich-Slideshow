# Contract: SlideshowTicker

Zeit-Naht für den automatischen Bildwechsel. Trennt „wann" (Intervall) von „was" (Vorrücken), damit
Wechsel deterministisch ohne echte Wartezeit testbar sind (Konstitution II; CLAUDE.md: Timer-Test-
Design inline).

## Signatur

```swift
public protocol SlideshowTicker: Sendable {
    /// Liefert beim nächsten fälligen Tick zurück (produktiv nach `interval`).
    /// Wirft `CancellationError`, wenn der Lauf abgebrochen/pausiert wird.
    func waitForNextTick() async throws
}

public struct RealTicker: SlideshowTicker {
    public init(interval: Duration)
    // wartet `interval` über die Swift-Concurrency-Uhr (Task.sleep / ContinuousClock)
}
```

## Verhalten

- **RealTicker**: `waitForNextTick()` wartet `interval` (z. B. 8 s) und kehrt dann zurück; respektiert
  Task-Cancellation (für pause/Teardown).
- Das ViewModel ruft in seiner Lauf-Schleife wiederholt `waitForNextTick()` und danach `advance()`.
  `pause()` bricht die laufende Wartung ab; `resume()` startet die Schleife neu.

## Test-Ticker (in `Tests/SlideshowKitTests/Fakes.swift`)

```swift
// ManualTicker: jeder Test-„tick()" lässt genau einen wartenden waitForNextTick() zurückkehren.
final class ManualTicker: SlideshowTicker, @unchecked Sendable {
    func waitForNextTick() async throws   // blockiert bis tick()
    func tick()                           // gibt genau einen Tick frei
}
```

- Ermöglicht: „N Ticks → erwartete Bildfolge" ohne echte Zeit; keine flaky Sleeps.

## Tests (TDD, Host)

- `ManualTicker.tick()` lässt das ViewModel genau ein Bild weiterrücken.
- Ohne `tick()` rückt nichts vor (kein selbsttätiges Vorlaufen).
- Cancellation/Pause: nach `pause()` führt ein `tick()` zu keinem Vorrücken, bis `resume()`.
