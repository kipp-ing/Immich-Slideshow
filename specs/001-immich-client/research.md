# Phase 0 Research: ImmichClient

Ziel: alle offenen technischen Punkte vor dem Design klären. Die Technical Context im Plan enthält
keine `NEEDS CLARIFICATION` (Stack ist durch `CLAUDE.md` festgelegt). Einziger echter Recherchepunkt:
die konkreten Immich-API-Pfade — laut Konstitution gegen die OpenAPI der **laufenden** Serverversion
zu prüfen, nicht aus alten Tutorials zu übernehmen.

## Entscheidung 1: API-Pfade (Immich REST)

**Decision** (Stand moderner Immich-Versionen, `/api`-Präfix, plural Routen):

| Zweck | Methode & Pfad | Hinweise |
|-------|----------------|----------|
| Serverversion (Verifikation) | `GET /api/server/version` | Zum Abgleich der API-Version beim Setup. |
| Albumliste | `GET /api/albums` | Liefert Array von Alben (u. a. `id`, `albumName`). |
| Album + Assets | `GET /api/albums/{id}` | Album-Detail enthält `assets`-Array. |
| Vorschaubild | `GET /api/assets/{id}/thumbnail?size=preview` | `size=preview` (größer) bzw. `size=thumbnail` (klein); liefert Bilddaten, nicht das Original. |

**Rationale**: Entspricht der aktuellen Immich-API (plural `albums`/`assets`, `/api`-Präfix). Das
Album-Detail liefert die Assets mit, sodass kein separater Asset-Endpoint nötig ist. `thumbnail` mit
`size`-Query liefert eine herunterskalierte Variante — exakt FR-005.

**Alternatives considered**:
- Legacy-Pfade `GET /api/album`, `/api/asset/thumbnail/{id}` (Singular): veraltet, in aktuellen
  Versionen entfernt/umbenannt — verworfen.
- Original statt Vorschau (`/api/assets/{id}/original`): überträgt volle Auflösung — widerspricht FR-005.

**⚠️ Verifikationspflicht (Konstitution IV / CLAUDE.md):** Vor/while implementing gegen die laufende
Instanz prüfen: `GET /api/server/version` aufrufen und die Routen gegen `/api/openapi.json` (bzw. die
Swagger-UI der Instanz) abgleichen. Bei Abweichung Pfade hier korrigieren, **nicht** raten.

## Entscheidung 2: Authentifizierung

**Decision**: Jeder Request trägt den Header `x-api-key: <API-Key>`. Kein Query-Parameter, kein
Bearer-Token in diesem Feature.

**Rationale**: Immich akzeptiert API-Keys über `x-api-key` (FR-002, Spec). Header statt Query hält den
Key aus URLs/Logs heraus (Konstitution III).

**Alternatives considered**: API-Key als Query-Param — verworfen, weil er in Logs/Caches landen kann.

## Entscheidung 3: Fehler-Mapping

**Decision**: HTTP/Transport-Ergebnisse werden auf eine domänenspezifische `ImmichError`-Enum
abgebildet:
- `401` → `.unauthorized`
- `URLError` mit `.timedOut`/`.cannotConnectToHost`/`.notConnectedToInternet` → `.unreachable`
- nicht dekodierbare/erwartungswidrige Antwort (inkl. anderer non-2xx-Codes) → `.invalidResponse`

**Rationale**: Erfüllt FR-006/FR-007 (klar unterscheidbare Fehler) und SC-003/SC-004.

**Alternatives considered**: Rohe `URLError`/`HTTPURLResponse` nach außen reichen — verworfen, weil
Aufrufer dann selbst klassifizieren müssten und die Akzeptanzkriterien nicht testbar wären.

## Entscheidung 4: Transport-Abstraktion (Testbarkeit)

**Decision**: Ein `HTTPTransport`-Protokoll mit `func data(for: URLRequest) async throws -> (Data,
URLResponse)`. Live-Impl wraps `URLSession`; Tests nutzen `MockTransport`, der eingehende Requests
aufzeichnet und feste `(Data, URLResponse)` bzw. geworfene Fehler liefert.

**Rationale**: Erfüllt Konstitution II + FR-010 + SC-001/SC-006 — gesamte Logik ohne echten Server
testbar, inkl. Verifikation des `x-api-key`-Headers über die aufgezeichneten Requests.

**Alternatives considered**: `URLProtocol`-Stubbing — funktioniert, ist aber globaler Zustand und
weniger explizit als ein injiziertes Protokoll; verworfen zugunsten klarer DI.

## Entscheidung 5: Concurrency

**Decision**: `async/await`; `ImmichAPI`-Methoden sind `async throws`. Swift-6-Strict-Concurrency;
Modelle sind `Sendable`.

**Rationale**: Moderne, testbare Netzwerk-API ohne Callback-Verschachtelung; passt zu Swift 6.

**Output**: Alle offenen Punkte aufgelöst. Bereit für Phase 1 (Design & Contracts).
