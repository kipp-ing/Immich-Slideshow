# Phase 0 Research — Source Library

All "NEEDS CLARIFICATION" resolved. The shared-link mechanics were verified live against the running
server (Immich 2.7.5); see `specs/110-shared-album-link/spec.md` for the raw recipe.

## D1 — One client, two auth modes

**Decision**: Add an auth mode to `ServerConfig`: `.apiKey(String)` (current `x-api-key` header) or
`.shareKey(String)` (append `?key=<token>` to every request). `ImmichClient` branches on the mode
when building each `URLRequest`; all endpoint methods (`albums`, `assets`, `assetInfo`, `preview`,
`original`) stay identical otherwise.

**Rationale**: The verified shared-link flow uses exactly the same album/asset endpoints, only the
auth carrier differs (query vs header). One client keeps the slideshow engine and prefetch logic
unchanged (FR-120-03 / FR-110-08).

**Alternatives**: a separate `SharedLinkClient` type (rejected — duplicates all endpoint logic and
forks the engine's `ImmichAPI` dependency); a URLSession delegate injecting auth (rejected —
over-engineered for one query param).

## D2 — Shared-link resolver

**Decision**: A `SharedLinkResolver` (in ImmichClient) performs the one-time resolve:
`GET /api/shared-links/me?slug=<slug>[&password=<pw>]` → `SharedLinkResolution(key, albumID,
expiresAt)`. The app then builds a `.shareKey(key)` `ServerConfig` and uses `albumID` as the
slideshow album. Resolve runs once per activation, not per photo.

**Rationale**: Verified: `me` returns the bearer key + album id; the password is needed only here;
all later `albums/{id}?key=` and `assets/{id}/...?key=` calls use the key alone.

**Error mapping** (`ImmichError`): `me` 401 **with** a password supplied → `wrongPassword`; 401
**without** a password → password required (a `wrongPassword`/`passwordRequired` distinction surfaced
to the UI); `me` 404/410/expired → `invalidShareLink` / `shareLinkExpired` (honor `expiresAt`);
transport failure → existing `unreachable`. Never log the `me` response (it echoes the password).

## D3 — Persistence layout

**Decision**: Persist the library as JSON under a single UserDefaults key
`immich.sourceLibrary` = `{ sources: [{id, label, kind, ...locator}], activeID }`. Album locator =
`{albumID}` (served by the existing `baseURL` + Keychain API key). Shared-link locator =
`{baseURL, slug}` (non-secret, both come from the pasted URL). The shared-link **password** is stored
in the Keychain keyed by the source `id`; the resolved bearer **key is never persisted**.

**Rationale**: Constitution III — only the password is secret and goes to the Keychain; the slug/URL
are public (they are in the shared link the user pasted). Not caching the key avoids persisting a
bearer token and tolerates key rotation/expiry (see D6).

**Alternatives**: storing the whole library in the Keychain (rejected — metadata isn't secret, and
Keychain is awkward for a list); CoreData (rejected — overkill for a small list).

## D4 — Migration from `selectedAlbumID`

**Decision**: On first `SourceLibraryStore.load()` where `immich.sourceLibrary` is absent but the
legacy `immich.selectedAlbumID` is present, synthesize a one-entry library:
`Source.album(id: selectedAlbumID, label: <album name if resolvable, else the id>)`, active. Persist
the new library. Leave the legacy key in place (harmless; supports rollback) but stop reading it once
the library exists.

**Rationale**: FR-120-06 / SC-120-02 — zero reconfiguration; playback continues. Label resolution is
best-effort (a network call may be unavailable at migration), so fall back to the id.

## D5 — Home Assistant: keep the entity, broaden the options

**Decision**: Keep the existing `select` entity (HA entity key `album`, MQTT discovery/topics
unchanged) to avoid orphaning users' existing HA entities, but broaden its **options** from "all
server albums" to "the saved source labels," and its command/state semantics to "active source."
`RemoteControlling.albumOptions/currentAlbum/selectAlbum` are backed by the `SourceLibrary` instead
of `[Album]`. The HA friendly name can read "Source"; the entity id stays stable.

**Rationale**: Reuses the verified select machinery (`HADiscovery` `select`, command/state echo) with
minimal change; not renaming the entity keeps existing automations working. (Renaming `album`→`source`
is recorded as a possible future breaking change, not done now.)

## D6 — Open spec questions (resolved here as plan-stage decisions)

- **OQ2 HA disambiguation**: Enforce **unique labels** in the source manager UI (reject/auto-suffix a
  duplicate on add/rename). HA select options are the labels verbatim, so uniqueness keeps selection
  unambiguous.
- **OQ3 slug→key freshness**: **Re-resolve** the slug→key on each activation (and app launch for the
  active source); do **not** cache the key. Tolerates rotated/expired links and means no bearer token
  is ever persisted. Cost is one `me` call per activation — negligible.
- **OQ4 label source of truth**: Default a source's label from the album/shared-link name at add
  time; allow an optional rename in the manager. v1 ships default + rename.

## D7 — Image format

**Decision**: Keep fetching `preview` (JPEG) for display by default (existing `quality` setting).
Shared-link originals can be HEIC; `UIImage` decodes HEIC, but preview avoids large transfers and
keeps parity with album sources.
