# Quickstart / Validation: ImmichClient

Beweist, dass das Feature end-to-end funktioniert. Details zu Typen/Verträgen siehe
[data-model.md](./data-model.md) und [contracts/ImmichAPI.md](./contracts/ImmichAPI.md).

## Voraussetzungen

- Xcode aktiv (`xcode-select -p` zeigt `/Applications/Xcode.app/...`).
- Swift 6 Toolchain.
- Tests laufen über XcodeBuildMCP (kein echter Server nötig — Mock-Transport).

## Unit-Tests ausführen (Standard, kein Server)

Paketverzeichnis: `Packages/ImmichClient`. Über XcodeBuildMCP das Swift-Package-Test-Tool nutzen
(bzw. `swift test` im Paket). Erwartetes Ergebnis: alle Tests grün, u. a.

- `albums()` parst gültige JSON → Alben mit `id`/`name`.
- jeder Request trägt `x-api-key` (über MockTransport-Aufzeichnung verifiziert).
- 401 → `.unauthorized`; Timeout → `.unreachable`; leeres Album → `[]`.
- `preview(assetID:)` liefert die Mock-Bilddaten.

## Akzeptanz-Mapping

| Success Criterion | Validierung |
|-------------------|-------------|
| SC-001 (x-api-key überall) | `ErrorTests`/`AlbumTests` prüfen `recordedRequest.value(forHTTPHeaderField: "x-api-key")`. |
| SC-002 (verlustfreies Mapping) | `AlbumTests` vergleicht geparste Modelle mit Eingabe-JSON. |
| SC-003 (401 → unauthorized) | `ErrorTests` mit 401-Response. |
| SC-004 (Timeout → unreachable) | `ErrorTests` mit `URLError(.timedOut)`. |
| SC-005 (leeres Album → []) | `AssetTests` mit leerem `assets`-Array. |
| SC-006 (ohne echten Server) | gesamte Suite nutzt MockTransport. |

## Integrationstest (optional, lokal, nicht in jedem Lauf)

Gegen die echte Instanz: gültige `baseURL` + API-Key in eine lokale, **nicht committete** Konfig
setzen, `albums()` aufrufen, prüfen, dass die echten Albumnamen erscheinen. Zuvor
`GET /api/server/version` aufrufen und Routen gegen `/api/openapi.json` abgleichen (Konstitution IV).
