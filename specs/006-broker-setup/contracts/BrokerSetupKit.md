# Contracts: BrokerSetupKit

Öffentliche Schnittstellen. Signaturen sind Zielbild; Implementierung folgt TDD. Swift 6. Paket hängt
an `HAControlKit` (für `BrokerConfig`/`BrokerConfigStore`).

## `BrokerSettings` + Validierung

```swift
public struct BrokerSettings: Sendable, Equatable {
    public var host: String
    public var port: Int
    public var username: String
    public var password: String
    public init(host: String, port: Int, username: String, password: String)

    /// Liefert den ersten Validierungsfehler oder nil (gültig).
    public func validate() -> BrokerValidationError?
}

public enum BrokerValidationError: Error, Equatable {
    case emptyHost, invalidPort, emptyUsername, emptyPassword
}
```

- `validate()`: Host nach `trimmingCharacters(.whitespacesAndNewlines)` nicht leer; `1...65535` Port;
  username/password nicht leer (nach Trimmen für Username; Passwort nicht leer ohne Trim-Zwang).

## `BrokerSettingsStore`

```swift
public protocol BrokerSettingsStore: Sendable {
    func save(_ settings: BrokerSettings) throws   // nur gültige; atomar Keychain+UserDefaults
    func load() -> BrokerSettings?                 // vollständig oder nil
    func clear()
}
```

- **Real (`KeychainBrokerSettingsStore`)**: host/port → UserDefaults; username/password → Keychain
  (JSON-Item, idempotent). `save` ruft zuerst `settings.validate()`; bei Fehler `throw`, nichts
  schreiben.
- **Test (`InMemoryBrokerSettingsStore`)**: hält `BrokerSettings?` im Speicher; `save` validiert ebenso.

## `BrokerConfigProvider` (konformiert `HAControlKit.BrokerConfigStore`)

```swift
import HAControlKit

public struct BrokerConfigProvider: BrokerConfigStore {
    public init(settingsStore: any BrokerSettingsStore, deviceID: String)
    public func load() -> BrokerConfig?   // settings + injizierte deviceID; nil falls keine Settings
}
```

### Verhaltens-Kontrakt (testbar)

| Auslöser | Garantierte Wirkung |
|----------|---------------------|
| `BrokerSettings(host:"", …).validate()` | `.emptyHost` |
| `port=0` / `port=70000` | `.invalidPort` |
| leerer `username`/`password` | `.emptyUsername` / `.emptyPassword` |
| gültige Settings `.validate()` | `nil` |
| `store.save(gültig)` dann `store.load()` | identische Settings zurück |
| `store.save(ungültig)` | wirft; `store.load() == nil` (nichts persistiert) |
| `store.clear()` | `store.load() == nil` |
| `provider.load()` bei vorhandenen Settings | `BrokerConfig` mit Settings-Werten + injizierter `deviceID` |
| `provider.load()` ohne Settings | `nil` |
