# Quickstart — Source Library validation

How to prove the feature end-to-end. Logic via `swift test` (host); UI via XcodeBuildMCP/XCUITest on
the pinned iOS 26.5 simulator. Each scenario maps to FR/SC in `spec.md`.

## Prerequisites

- Build/test through XcodeBuildMCP (no hand-parsed `xcodebuild`).
- Fakes: `InMemorySourceLibraryStore`, `InMemorySharedLinkSecretStore`, stub `SharedLinkResolving`,
  stub `ImmichAPI`. No live server needed for the suite.
- A real shared link is available for manual end-to-end: unprotected `…/s/geo2026`; protected
  `…/s/korsika2026` (password `12345678`).

## Logic scenarios (Swift Testing, host)

1. **Library ops** (FR-120-01/04/11) — add two sources → first is active; `setActive` switches;
   `remove(active)` promotes the next; duplicate label rejected; exactly one active throughout.
2. **Migration** (FR-120-06 / SC-120-02) — store with legacy `selectedAlbumID`, no library → `load()`
   yields a one-entry album library, active = that album; persisted on next `load()`.
3. **Persistence + secrets** (FR-120-08 / SC-120-03) — save a shared-link source with a password →
   UserDefaults JSON contains no password and no bearer key; password readable only from the secret
   store; relaunch (reload) restores sources + active id.
4. **Auth modes** (FR-120-03) — `ImmichClient` with `.apiKey` sets `x-api-key` header and no `key=`
   query; with `.shareKey` appends `key=<token>` to album/asset URLs and sets no header.
5. **Shared-link resolve** (FR-120-09, 110) — stub transport: `me` 200 → `(key, albumID, expiresAt)`;
   401+pw → `wrongPassword`; 401 no-pw → `passwordRequired`; expired/unknown → `shareLinkExpired`/
   `invalidShareLink`; transport fail → `unreachable`. Nothing persisted on failure.
6. **HA select** (FR-120-07 / SC-120-04) — adapter backed by a 2-source library: discovery `options`
   == the two labels; command with a known label switches active + state echoes it; unknown label is
   a no-op that echoes the real active source.

## UI scenarios (XCUITest, `--uitest`)

7. **Add a source in onboarding** (FR-120-05) — connect → add an album → confirmation lists it as
   active → slideshow runs it.
8. **Manage in Settings** (FR-120-05 / US1) — open Sources → add a second source → switch active →
   the running slideshow swaps to it; remove one → list updates.
9. **Calm default** (FR-120-10) — no new overlay appears unless the user opens the source manager.

## Manual end-to-end (real server, optional)

- Add the protected shared link (`korsika2026` / `12345678`) as a source, set it active → slideshow
  plays its photos with no personal API key; a wrong password shows the password error and persists
  nothing.

## Definition of done

- All logic scenarios green on host `swift test`; UI scenarios green via XcodeBuildMCP/XCUITest;
  full XCUITest run before merge (screenshots miss UI-test regressions).
- No secret in UserDefaults/logs (grep the suite + a manual log check).
