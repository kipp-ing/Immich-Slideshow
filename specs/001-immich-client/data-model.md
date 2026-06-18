# Phase 1 Data Model: ImmichClient

Foundation-only Wertetypen, alle `Sendable`. Keine Persistenz in diesem Feature.

## ServerConfig

Verbindungsdaten, von außen übergeben.

| Feld | Typ | Regeln |
|------|-----|--------|
| `baseURL` | `URL` | HTTPS. Basis ohne `/api`-Suffix (Client hängt Pfade an). |
| `apiKey` | `String` | Nicht leer. Wird nur als Header gesendet, nie geloggt. |

## Album

Ein Foto-Album des Nutzers (aus `GET /api/albums`).

| Feld | Typ | Quelle (JSON) | Regeln |
|------|-----|---------------|--------|
| `id` | `String` | `id` | eindeutig, nicht leer |
| `name` | `String` | `albumName` | Anzeigename; darf leer sein |

> Mapping-Hinweis: JSON-Schlüssel `albumName` → Modellfeld `name` (via `CodingKeys`).

## Asset

Ein Bild eines Albums (aus dem `assets`-Array von `GET /api/albums/{id}`).

| Feld | Typ | Quelle (JSON) | Regeln |
|------|-----|---------------|--------|
| `id` | `String` | `id` | eindeutig, nicht leer |
| `type` | `String` | `type` | z. B. `IMAGE`; für spätere Filterung/Anzeige |

> Umfang der „nötigen Metadaten" bewusst minimal (FR-004, Assumption der Spec). Weitere Felder
> (Orientierung, Timestamps) werden erst ergänzt, wenn ein konsumierendes Feature sie braucht.

## Preview (kein eigener Typ)

Das Vorschaubild wird als `Data` zurückgegeben (herunterskalierte Bilddaten aus
`GET /api/assets/{id}/thumbnail?size=preview`). Decodierung in ein Bild ist Sache des UI-Features.

## ImmichError

Domänenspezifische Fehler (unterscheidbar gemäß FR-006/FR-007).

| Case | Bedeutung | Auslöser |
|------|-----------|----------|
| `.unauthorized` | API-Key falsch/abgelaufen | HTTP 401 |
| `.unreachable` | Server nicht erreichbar / Timeout | `URLError` (timedOut, cannotConnectToHost, notConnectedToInternet) |
| `.invalidResponse` | Antwort nicht verwertbar | non-2xx (außer 401), Decoding-Fehler, fehlende/fehlerhafte JSON |

## Beziehungen

```
ServerConfig ──(konfiguriert)──► ImmichClient
Album 1 ──(enthält)──► * Asset
Asset ──(hat Vorschau als)──► Data
```
