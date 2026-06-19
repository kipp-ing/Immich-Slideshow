# Contracts: HAControlKit

Öffentliche Schnittstellen. Signaturen sind Zielbild; Implementierung folgt TDD (roter Test zuerst).
Swift 6, `Sendable` wo zutreffend. Kern-Target `HAControlKit` ist abhängigkeitsfrei.

## `MQTTTransport` (injizierte Naht — Transport)

```swift
public struct MQTTMessage: Sendable, Equatable {
    public var topic: String
    public var payload: Data
    public var retain: Bool
    public init(topic: String, payload: Data, retain: Bool)
}

public protocol MQTTTransport: Sendable {
    /// Verbindet (TLS) und registriert das Last-Will (availability=offline, retained).
    func connect(will: MQTTMessage) async throws
    func disconnect() async
    /// Publiziert eine Nachricht (QoS/retain wie in der Message).
    func publish(_ message: MQTTMessage) async throws
    /// Abonniert ein Topic(-Filter).
    func subscribe(_ topicFilter: String) async throws
    /// Strom eingehender Nachrichten (Command-Topics).
    var incoming: AsyncStream<MQTTMessage> { get }
    /// Strom des Verbindungszustands (für availability/reconnect).
    var connectionEvents: AsyncStream<Bool> { get }   // true=connected, false=disconnected
}
```

- **Real (`HAControlMQTT.NIOMQTTTransport`)**: über `mqtt-nio` mit TLS; Will/Reconnect/Keepalive.
- **Test (`FakeMQTTTransport`)**: zeichnet `publish`/`subscribe`/`connect(will:)` auf (`published:
  [MQTTMessage]`, `subscriptions: [String]`, `will: MQTTMessage?`); erlaubt `inject(_ message:)` zum
  Einspeisen eingehender Commands und `emitConnection(_:)`.

## `RemoteControlling` (injizierte Naht — App-Steuerfläche)

```swift
@MainActor
public protocol RemoteControlling: AnyObject {
    var playbackState: PlaybackState { get }     // playing/paused
    var brightness: Double { get }               // 0.0–1.0 (aktueller Zielwert)
    var albumOptions: [String] { get }           // verfügbare Albumnamen
    var currentAlbum: String? { get }

    func pause()
    func resume()
    func setBrightness(_ value: Double) async    // an PowerManager (geklemmt, foreground-gated)
    func selectAlbum(_ name: String)             // unbekannt ⇒ no-op (Zustand bleibt)

    /// Wird von der App bei lokalen Zustandsänderungen aufgerufen → Coordinator publiziert State-Echo.
    var onLocalChange: (@MainActor () -> Void)? { get set }
}
```

- **App-Adapter (`SlideshowRemoteControlAdapter`)**: leitet auf `SlideshowViewModel` + `PowerManager`.
- **Test (`FakeRemoteControl`)**: zeichnet Aufrufe auf; konfigurierbare Zustände/Albumliste.

## `BrokerConfigStore` (injizierte Naht — Keychain)

```swift
public protocol BrokerConfigStore: Sendable {
    func load() -> BrokerConfig?    // nil ⇒ keine Fernsteuerung (FR-003)
}

public struct BrokerConfig: Sendable, Equatable {
    public var host: String
    public var port: Int
    public var username: String
    public var password: String
    public var deviceID: String
    public init(host: String, port: Int, username: String, password: String, deviceID: String)
}
```

## `HATopics` (reine Topic-Struktur)

```swift
public enum HATopics {
    public static func base(deviceID: String) -> String              // "immichslideshow/<id>"
    public static func availability(deviceID: String) -> String
    public static func commandTopic(deviceID: String, entity: HAEntity) -> String   // ".../set"
    public static func stateTopic(deviceID: String, entity: HAEntity) -> String     // ".../state"
    public static func discoveryConfigTopic(deviceID: String, entity: HAEntity) -> String
}

public enum HAEntity: String, CaseIterable, Sendable { case playback, brightness, album }
```

## `HADiscovery` (reine Payload-Builder)

```swift
public enum HADiscovery {
    /// Discovery-Config-JSON (Data) für eine Entität; enthält unique_id, availability/command/state-Topics, device-Block.
    public static func config(for entity: HAEntity, deviceID: String, deviceName: String, albumOptions: [String]) -> Data
}
```

- Garantien (testbar): stabile `unique_id == "<deviceID>_<entity>"`; `availability_topic`,
  `command_topic`, `state_topic` stimmen mit `HATopics` überein; `device.identifiers == [deviceID]`;
  `select` enthält `options == albumOptions`. Kein Credential im Payload.

## `HAControlCoordinator` (`@MainActor @Observable`)

```swift
@MainActor
@Observable
public final class HAControlCoordinator {
    public private(set) var connection: ConnectionState

    public init(
        transport: any MQTTTransport,
        control: any RemoteControlling,
        configStore: any BrokerConfigStore,
        deviceName: String,
        enabledEntities: Set<HAEntity> = [.playback]   // P1 default; P2/P3 erweitern
    )

    /// Diashow erscheint: Config laden; falls vorhanden, verbinden→online→discovery→subscribe→state-echo.
    public func start() async
    /// Diashow verlassen/Hintergrund: trennen (LWT→offline).
    public func stop() async
}
```

### Verhaltens-Kontrakt (testbar, über Fakes)

| Auslöser | Garantierte Wirkung |
|----------|---------------------|
| `start()` mit gültiger Config | `transport.connect(will:)` mit availability=`offline`-Will; nach connect: availability=`online` (retained); Discovery-Config je aktivierter Entität (retained); Command-Topics abonniert; State-Echo je Entität |
| `start()` ohne Config (`nil`) | kein `connect`; `connection == .disconnected`; keine Exceptions (FR-003) |
| eingehender `switch/set` `ON`/`OFF` | `control.resume()`/`control.pause()`; danach State-Echo = echter `playbackState` (FR-008/FR-009) |
| eingehender `light/set` (P2) | `control.setBrightness(clamp)`; State-Echo = angewandter Wert (FR-013) |
| eingehender `select/set` gültig/ungültig (P3) | gültig: `control.selectAlbum`; ungültig: no-op; immer State-Echo = echter Zustand (FR-015) |
| ungültige/leere Payload | kein Crash, kein Zustandswechsel; State-Echo = unveränderter Zustand (FR-011) |
| `control.onLocalChange` ausgelöst | State-Echo des betroffenen Zustands (SC-003) |
| `connectionEvents`=false → true (reconnect) | erneut availability=`online` + Discovery (idempotent) + State-Echo (FR-005, SC-004/SC-005) |
| `stop()` | `transport.disconnect()`; danach `connection == .disconnected` |
