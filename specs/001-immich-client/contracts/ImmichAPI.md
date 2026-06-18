# Contract: `ImmichAPI` & `HTTPTransport`

Die öffentlichen Schnittstellen des `ImmichClient`-Moduls. Verbindlich für Implementierung und Tests.

## `HTTPTransport` (injizierbar, für Tests mockbar)

```swift
public protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}
```

- **Live-Impl** wraps `URLSession` (Default `.shared`), keine TLS-Ausnahme.
- **MockTransport** (Test): zeichnet alle empfangenen `URLRequest`s auf und liefert vorkonfigurierte
  `(Data, URLResponse)` oder wirft einen vorkonfigurierten `Error` (z. B. `URLError(.timedOut)`).

## `ImmichAPI`

```swift
public protocol ImmichAPI: Sendable {
    /// Story 1 — Albumliste des Nutzers.
    func albums() async throws -> [Album]

    /// Story 2 — Bild-Assets eines Albums. Leeres Album → [].
    func assets(albumID: String) async throws -> [Asset]

    /// Story 3 — herunterskaliertes Vorschaubild eines Assets (nicht das Original).
    func preview(assetID: String) async throws -> Data
}
```

### Vertrag je Methode

| Methode | Request | Erfolg | Fehler |
|---------|---------|--------|--------|
| `albums()` | `GET {baseURL}/api/albums`, Header `x-api-key` | `[Album]` aus JSON | 401 → `.unauthorized`; Timeout → `.unreachable`; sonst → `.invalidResponse` |
| `assets(albumID:)` | `GET {baseURL}/api/albums/{albumID}`, Header `x-api-key` | `[Asset]` aus `assets`; leer → `[]` | wie oben |
| `preview(assetID:)` | `GET {baseURL}/api/assets/{assetID}/thumbnail?size=preview`, Header `x-api-key` | `Data` (Bildbytes) | wie oben |

### Invarianten (testbar)

- **INV-1**: Jeder ausgehende Request trägt den Header `x-api-key` mit dem konfigurierten Key (SC-001).
- **INV-2**: 2xx mit gültiger JSON → verlustfreies Mapping in Modelle (SC-002).
- **INV-3**: Statuscode 401 → `ImmichError.unauthorized` (SC-003).
- **INV-4**: `URLError(.timedOut)` o. ä. → `ImmichError.unreachable` (SC-004).
- **INV-5**: Album ohne Assets → `[]`, kein Fehler (SC-005).
- **INV-6**: non-2xx (≠401) oder undekodierbare Antwort → `ImmichError.invalidResponse`.

## `ImmichClient` (Live-Impl)

```swift
public struct ImmichClient: ImmichAPI {
    public init(config: ServerConfig, transport: HTTPTransport = URLSessionTransport())
}
```

- Baut Requests aus `config.baseURL`, hängt API-Pfade an, setzt `x-api-key`.
- Klassifiziert Antworten/Fehler gemäß Tabelle oben.
- Loggt den API-Key niemals.
