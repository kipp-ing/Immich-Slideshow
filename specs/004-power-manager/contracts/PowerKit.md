# Contracts: PowerKit

Öffentliche Schnittstellen des Pakets `PowerKit`. Signaturen sind Zielbild; die Implementierung folgt
TDD (roter Test zuerst). Alle Typen `Swift 6`, `Sendable` wo zutreffend.

## `ScreenControlling` (injizierte Naht — Hardwarezugriff)

```swift
@MainActor
public protocol ScreenControlling: AnyObject {
    /// Aktuelle Bildschirmhelligkeit, 0.0–1.0. Setzen wirkt nur im Vordergrund (vom Aufrufer gegated).
    var brightness: Double { get set }
    /// Leerlauf-/Sperr-Timer unterdrückt? true = Display bleibt an.
    var isIdleTimerDisabled: Bool { get set }
}
```

- **Real (App-Target, `UIScreenController`)**: mappt auf `UIScreen.main.brightness` und
  `UIApplication.shared.isIdleTimerDisabled`.
- **Test (`FakeScreenController`)**: speichert `isIdleTimerDisabled`; zeichnet jede Helligkeits-
  Schreibung in `brightnessWrites: [Double]` auf; `brightness`-Getter liefert den letzten Wert.

## `PowerClock` (injizierte Naht — Zeit)

```swift
public protocol PowerClock: Sendable {
    /// Wartet die angegebene Dauer; respektiert Cancellation. Test-Clock kehrt sofort zurück.
    func sleep(for duration: Duration) async throws
}

public struct RealClock: PowerClock {
    public init()
    public func sleep(for duration: Duration) async throws  // Task.sleep / ContinuousClock
}
```

- **Test (`ManualClock`)**: `sleep` kehrt sofort zurück (kein echtes Warten), sodass die Soft-Dim-Ramp
  in Tests synchron durchläuft und Zwischenwerte über `FakeScreenController.brightnessWrites`
  beobachtbar sind.

## `PowerConfig` (Wertmodell)

```swift
public struct PowerConfig: Sendable, Equatable {
    public var softDimDuration: Duration   // v1: .milliseconds(600)
    public var softDimSteps: Int           // v1: 8 (>= 2)
    public static let `default`: PowerConfig
    public init(softDimDuration: Duration, softDimSteps: Int)
}
```

- Invarianten: `softDimSteps >= 2`, `softDimDuration > .zero`.

## `PowerManager` (`@MainActor @Observable`)

```swift
@MainActor
@Observable
public final class PowerManager {
    public private(set) var isKeepingAwake: Bool

    public init(
        screen: any ScreenControlling,
        clock: any PowerClock = RealClock(),
        config: PowerConfig = .default
    )

    /// Vordergrund-Sitzung beginnt: Ausgangshelligkeit erfassen, Leerlauf-Timer deaktivieren.
    public func activate()

    /// Zielhelligkeit (geklemmt 0.0–1.0) setzen; weich oder hart. Im Hintergrund No-Op.
    public func setBrightness(_ value: Double, animated: Bool) async

    /// App geht in den Hintergrund: Leerlauf-Timer freigeben, Ramp stoppen, nichts mehr schreiben.
    public func didEnterBackground()

    /// App kehrt in den Vordergrund zurück (Sitzung läuft noch): Wach-halten wiederherstellen.
    public func willEnterForeground()

    /// Sitzung endet: Leerlauf-Timer normalisieren, ggf. Ausgangshelligkeit wiederherstellen.
    public func deactivate()
}
```

### Verhaltens-Kontrakt (testbar)

| Methode | Vorbedingung | Garantierte Wirkung |
|---------|--------------|---------------------|
| `activate()` | — | `baselineBrightness = screen.brightness`; `isIdleTimerDisabled = true`; `isKeepingAwake = true` |
| `setBrightness(v, animated:false)` | Vordergrund | `screen.brightness = clamp(v)`; `didChangeBrightness = true` |
| `setBrightness(v, animated:true)` | Vordergrund | Helligkeit erreicht `clamp(v)` über `softDimSteps` Zwischenwerte; neuer Aufruf löst laufende Ramp ab (Latest-wins) |
| `setBrightness(_, _)` | Hintergrund | **No-Op** (kein `brightness`-Write) |
| `didEnterBackground()` | — | `isIdleTimerDisabled = false`; `isKeepingAwake = false`; laufende Ramp abgebrochen; kein `brightness`-Write |
| `willEnterForeground()` | Sitzung aktiv | `isIdleTimerDisabled = true`; `isKeepingAwake = true` |
| `deactivate()` | — | `isIdleTimerDisabled = false`; `isKeepingAwake = false`; falls `didChangeBrightness && baseline != nil` → `screen.brightness = baseline`; sonst Helligkeit unangetastet |
