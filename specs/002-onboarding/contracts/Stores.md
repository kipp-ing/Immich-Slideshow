# Contract: Persistenz-Protokolle (ConfigStore, KeychainStore)

Beide Protokolle entkoppeln Persistenz von der Logik (Konstitution II) und ermöglichen Fakes in
Tests. Reale Implementierungen: `UserDefaultsConfigStore` bzw. `KeychainAPIKeyStore`.

## ConfigStore

```swift
public protocol ConfigStore: Sendable {
    func load() -> AppConfiguration?
    func save(_ configuration: AppConfiguration)
    func clear()
}
```

**Verhalten**
- `load()` liefert eine `AppConfiguration` nur, wenn **beide** Felder (baseURL, selectedAlbumID)
  vorhanden und gültig sind; sonst `nil`.
- `save(_:)` persistiert beide Felder dauerhaft (App-Neustart-fest).
- `clear()` entfernt beide Felder (Reset, FR-012).
- Enthält **niemals** den API-Key.

**Reale Impl**: `UserDefaultsConfigStore` (feste Defaults-Keys, injizierbares `UserDefaults`).

## KeychainStore

```swift
public protocol KeychainStore: Sendable {
    func save(_ apiKey: String) throws
    func read() -> String?
    func delete()
}
```

**Verhalten**
- `save(_:)` legt den API-Key sicher ab; überschreibt einen vorhandenen Eintrag idempotent.
- `read()` liefert den gespeicherten Key oder `nil`.
- `delete()` entfernt den Key (Reset, FR-012); idempotent (kein Fehler, wenn nichts da ist).
- Schlägt `save` fehl, wird der Schritt nicht als erfolgreich markiert (Edge Case „Schreibfehler").

**Reale Impl**: `KeychainAPIKeyStore` über `Security` (`kSecClassGenericPassword`, fester
Service/Account). Wird auf dem Simulator app-gehostet getestet (Host nutzt `InMemoryKeychainStore`).

## Test-Fakes (in Tests)

- `InMemoryConfigStore`: hält `AppConfiguration?` im Speicher.
- `InMemoryKeychainStore`: hält `String?` im Speicher; `save` kann optional einen Fehler erzwingen
  (für den Schreibfehler-Edge-Case).
