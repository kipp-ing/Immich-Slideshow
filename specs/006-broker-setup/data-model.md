# Phase 1 Data Model: Broker-Setup

## Wertmodelle

### BrokerSettings (`Sendable`, `Equatable`)

| Feld | Typ | Bedeutung | Validierung |
|------|-----|-----------|-------------|
| `host` | `String` | Broker-Hostname | nach Trimmen nicht leer |
| `port` | `Int` | Broker-Port | 1…65535 |
| `username` | `String` | MQTT-Benutzername (→ Keychain) | nicht leer |
| `password` | `String` | MQTT-Passwort (→ Keychain) | nicht leer |

- `validate() -> BrokerValidationError?` (oder `func validated() throws`): liefert den ersten
  Verstoß bzw. nichts. `BrokerValidationError`: `.emptyHost`, `.invalidPort`, `.emptyUsername`,
  `.emptyPassword` (`Equatable`).
- Port-Default-Vorschlag in der UI: 8883 (TLS). Nicht Teil der Validierung.

### BrokerValidationError (`Error`, `Equatable`)

- Aufzählung der Feldverstöße (s. o.); steuert UI-Hinweis und verhindert Speichern (FR-002/FR-004).

## Persistenz

### BrokerSettingsStore (Protokoll)

- `func save(_ settings: BrokerSettings) throws` — nur gültige Settings; schreibt atomar
  Keychain (user/pass) + UserDefaults (host/port).
- `func load() -> BrokerSettings?` — vollständig (beide Teile) oder `nil`.
- `func clear()` — entfernt beide Teile.

Reale Impl `KeychainBrokerSettingsStore`:
- UserDefaults-Keys: `mqtt.brokerHost`, `mqtt.brokerPort`.
- Keychain: ein Generic-Password-Item (Service z. B. `de.kippings.ImmichSlideshow.mqttCredentials`),
  Wert = JSON `{ "username": …, "password": … }`, idempotentes Überschreiben.

### Bridge: BrokerConfigProvider (konformiert `HAControlKit.BrokerConfigStore`)

- `init(settingsStore: BrokerSettingsStore, deviceID: String)` (deviceID injiziert).
- `load() -> BrokerConfig?`:
  - `settingsStore.load()` → falls `nil` ⇒ `nil`.
  - sonst `BrokerConfig(host:port:username:password:deviceID:)` mit den Settings + injizierter `deviceID`.

## Zustandsübergänge

```text
   (keine Config)
        │ save(gültig)
        ▼
   (konfiguriert) ──load()──▶ BrokerConfig (für Feature 005)
        │ save(gültig, geänderte Werte) → konfiguriert (überschrieben; Keychain-Pass ersetzt)
        │ clear() → (keine Config); load() ⇒ nil; Keychain gelöscht
```

## Invarianten

- `load()` liefert nur vollständige, gültige Daten oder `nil` (FR-004/FR-005).
- Passwort/Benutzername existieren ausschließlich im Keychain (Konstitution III, SC-003).
- `save` mit ungültigen Settings wirft und persistiert nichts (FR-002/FR-004).
- `clear` hinterlässt kein verwaistes Keychain-Geheimnis (SC-005/SC-006).
- Geräte-ID ist injiziert und stabil (FR-010).
