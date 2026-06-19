# Quickstart & Validation: Broker-Setup

Host-Tests sichern Validierung + Provider-Bridge; der Simulator verifiziert die reale Keychain-/
UserDefaults-Persistenz und die Eingabemaske.

## Voraussetzungen

- Feature 005 (HAControl) vorhanden — liefert `BrokerConfig`/`BrokerConfigStore`, die dieses Feature
  konformiert/befüllt.
- Neues Paket `Packages/BrokerSetupKit` ins App-Target eingebunden.

## Logik-Tests (Host, schnell)

```text
swift test  (im Paket Packages/BrokerSetupKit)  bzw. test_sim für das App-Target
```

- `InMemoryBrokerSettingsStore` ersetzt Keychain/UserDefaults für die host-testbare Validierung/Bridge.

## Akzeptanz-Mapping (Spec → Validierung)

| Kriterium | Validierung |
|-----------|-------------|
| **SC-001** vollständige Config abrufbar | Provider-Test: nach `save(gültig)` → `provider.load()` == `BrokerConfig` mit allen Feldern + Geräte-ID. |
| **SC-002** ungültige Eingaben → keine Config | Settings-Test: `validate()` liefert Fehler je Feld; `store.save(ungültig)` wirft, `load()==nil`. Sim: Form zeigt Hinweis, speichert nicht. |
| **SC-003** Credentials nur im Keychain | Sim-Test/Review: nach `save` enthält UserDefaults nur host/port; username/password liegen im Keychain, nicht in UserDefaults/Logs. |
| **SC-004** Persistenz über Neustart | Sim-Test: `save`, neuer Store-Instanz `load()` → gleiche Settings (Keychain+UserDefaults überdauern). |
| **SC-005** (P2) Entfernen | Sim/Host-Test: `clear()` → `load()==nil`, `provider.load()==nil`, Keychain-Item weg. |
| **SC-006** (P2) Passwort überschreiben | Sim-Test: `save` mit neuem Passwort → `load()` liefert neues; kein verwaistes Alt-Geheimnis. |

## Simulator-Verifikation (XcodeBuildMCP)

1. Über das Long-Press-Menü „Broker einrichten" öffnen; Host/Port/User/Pass eingeben, speichern.
2. App neu starten → Daten weiterhin vorhanden; (mit Feature 005) versucht die App nun eine Verbindung.
3. UserDefaults inspizieren → kein Passwort/Benutzername; nur host/port.
4. „Entfernen" → keine Config mehr; Fernsteuerung wird inert.

## Out of Scope (nicht hier prüfen)

- Verbindungsaufbau/MQTT/Discovery/Fernsteuerung (Feature 005).
- Anonyme Broker, Self-signed, Auto-Discovery, Mehr-Broker-Verwaltung.
