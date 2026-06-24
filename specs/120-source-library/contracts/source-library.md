# Contracts — Source Library

Interface contracts this feature exposes/changes. (This is an app; contracts are Swift protocols,
the persistence schema, the Immich HTTP calls consumed, and the HA MQTT entity.)

## 1. Swift protocols (injected boundaries — Constitution II)

- `SourceLibraryStore` — `load()` (with one-time migration) / `save(_:)` / `clear()`.
- `SharedLinkSecretStore` — per-source password `save`/`read`/`delete` (Keychain).
- `SharedLinkResolving` — `resolve(baseURL:slug:password:) async throws -> SharedLinkResolution`.
- `RemoteControlling` (existing, broadened) — `albumOptions`/`currentAlbum`/`selectAlbum(_:)` now
  range over the library's source labels, not server albums.

Each has an in-memory/stub fake so tests run with no server/Keychain.

## 2. Persistence schema (non-secret, UserDefaults)

Key `immich.sourceLibrary` (JSON):
```json
{
  "sources": [
    { "id": "uuid", "label": "Wohnzimmer", "kind": { "album": { "albumID": "a1" } } },
    { "id": "uuid", "label": "Korsika 2026", "kind": { "sharedLink": { "baseURL": "https://bilder.kippings.de", "slug": "korsika2026" } } }
  ],
  "activeID": "uuid"
}
```
- Migration: absent library + legacy `immich.selectedAlbumID` → one album entry, active.
- Secret: shared-link password only in Keychain (service distinct from API key, account = source id).
  No bearer key, no password in this JSON, ever.

## 3. Immich HTTP consumed (verified, Immich 2.7.5)

| Purpose | Request | Auth |
|---|---|---|
| Resolve shared link | `GET /api/shared-links/me?slug=<slug>[&password=<pw>]` | none (password in query) |
| List album assets | `GET /api/albums/{albumID}?key=<key>` | `?key=` (shared) / header (album source) |
| Preview image | `GET /api/assets/{id}/thumbnail?key=<key>&size=preview` | `?key=` / header |
| Original image | `GET /api/assets/{id}/original?key=<key>` | `?key=` / header |

Status mapping: `me` 401 (+pw) → `wrongPassword`; `me` 401 (no pw) → `passwordRequired`; `me`
404/expired → `invalidShareLink`/`shareLinkExpired`; transport error → `unreachable`.

## 4. Home Assistant MQTT (entity stable, options broadened)

- Entity: existing `select` (HA entity key `album`; discovery/command/state topics unchanged).
- `options` = saved source labels (unique). Command payload = a label → switch active source.
- State topic echoes the active source's label after any local or remote change; unknown option is a
  no-op that re-echoes the real active source.

## 5. UI contract (200 surface)

- Onboarding: after connecting, an **Add source** step accepts an Immich album (picker) or a shared
  link (URL + optional password); the confirmation step lists the library and marks the active one.
- Settings: a **Sources** manager — list with add / remove / reorder / rename / set-active; switching
  the active source restarts the running slideshow from it.
- Calm default preserved: no new always-on overlay; switching is explicit.
