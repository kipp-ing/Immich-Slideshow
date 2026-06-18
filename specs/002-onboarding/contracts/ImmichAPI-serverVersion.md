# Contract: ImmichAPI-Erweiterung `serverVersion()`

Kleine Erweiterung des bestehenden `ImmichAPI`-Protokolls (Paket `ImmichClient`) für die
Erreichbarkeitsprüfung in Onboarding-Schritt 1 — **vor** dem API-Key.

## Signatur

```swift
public protocol ImmichAPI: Sendable {
    func albums() async throws -> [Album]
    func assets(albumID: String) async throws -> [Asset]
    func preview(assetID: String) async throws -> Data
    func serverVersion() async throws -> String   // NEU
}
```

## Verhalten

- Sendet `GET /api/server/version` an `baseURL`. **Route gegen die laufende Immich-Version
  verifizieren** (Konstitution IV); Fallback älterer Stände: `/api/server-info/version`.
- Endpunkt ist **unauthentifiziert**: funktioniert auch ohne gültigen API-Key (im Onboarding mit
  leerem Key aufgerufen). Ein mitgesendeter `x-api-key`-Header schadet nicht.
- 2xx → dekodierte Versionszeichenkette (z. B. „1.x.y"); genaue Form ist für Schritt 1 unkritisch
  (Erfolg = erreichbar).
- Fehler-Mapping wie die übrigen Methoden: `.unreachable` (Timeout/keine Verbindung),
  `.invalidResponse` (unerwarteter Status/nicht dekodierbar).

## Tests (TDD, MockTransport)

- Erfolg: gültige Versions-JSON → String; aufgezeichneter Request geht an `…/api/server/version`.
- `URLError(.timedOut)` aus dem Transport → `ImmichError.unreachable`.
- Nicht-2xx / nicht dekodierbar → `ImmichError.invalidResponse`.

> Diese Erweiterung liegt im Paket `ImmichClient` (eine Quelle für Netzwerk/Fehler-Mapping). Die
> bestehende `ImmichClient`-Suite bleibt grün; `MockTransport`/`ImmichClientTestSupport` werden
> wiederverwendet.
