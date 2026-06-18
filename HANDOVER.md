# Handover — ImmichClient (Feature 001)

_Last updated: 2026-06-18. Branch: `001-immich-client`. Pushed to `origin/001-immich-client`._

## TL;DR
The `ImmichClient` module is **functionally complete and verified** (host unit tests
14/14 green; app target links the package and builds for an iPad simulator).
**One task remains: T024** — re-run the full verification through **XcodeBuildMCP**
and confirm SC-001…SC-006. That's why you're restarting: to load the MCP server.

## Why the restart
`XcodeBuildMCP` is declared in `.mcp.json` and enabled in `.claude/settings.local.json`,
but the server was **not connected** in the previous session (it loads at startup; that
session predated `.mcp.json`). `ToolSearch` found none of its tools. After restart it
should connect — confirm before relying on it.

If it still doesn't load: the fallback used so far was raw `xcodebuild` (see commands
below). CLAUDE.md prefers MCP over raw `xcodebuild`, so only fall back if MCP is truly
unavailable, and say so.

## What's done (all committed + pushed)
- **Setup T001–T003** — `Packages/ImmichClient/` SPM package (Swift 6 tools, iOS 18 + macOS host).
- **Foundational T004–T008** — `ServerConfig`, `ImmichError`, `HTTPTransport`+`URLSessionTransport`,
  `MockTransport` (actor), `ImmichAPI` protocol, `ImmichClient` skeleton.
- **US1 T009–T013** — `albums()` → `GET /api/albums`, `Album` (Codable, `albumName`→`name`),
  shared `makeRequest(path:queryItems:)` helper.
- **US2 T014–T017** — `assets(albumID:)` → `GET /api/albums/{id}`, `Asset` (Codable),
  `AlbumDetail` wrapper, empty album → `[]`.
- **US3 T018–T019** — `preview(assetID:)` → `GET /api/assets/{id}/thumbnail?size=preview` → raw `Data`.
- **Polish T020–T023** — centralized error mapping in `responseData(for:)`/`decode(_:from:)`:
  401→`.unauthorized`, caught `URLError`→`.unreachable`, non-2xx/non-decodable→`.invalidResponse`.
  API key never logged.
- **T025** — app target "Immich Slideshow" links the local package
  (`XCLocalSwiftPackageReference` + `ImmichClient` product dependency in `project.pbxproj`,
  objectVersion 77). Link only, no UI. `xcodebuild` → **BUILD SUCCEEDED** with the package compiled.

## The one remaining task
**T024** (`specs/001-immich-client/tasks.md:115`): whole suite green via XcodeBuildMCP +
`quickstart.md` validation, SC-001…SC-006 covered. Steps:
1. Confirm XcodeBuildMCP is connected (its tools appear via ToolSearch).
2. Run the `ImmichClient` package tests through MCP (or the app scheme on an iPad sim).
3. Cross-check `specs/001-immich-client/quickstart.md` and the success criteria SC-001…SC-006.
4. Mark T024 `[X]`, commit, push. Feature is then ready for a PR to `main`.

## Verification commands (fallback, host + sim)
```bash
# Host unit tests (Foundation-only module) — currently 14/14 green:
cd "Packages/ImmichClient" && swift build && swift test

# App build with package linked (raw xcodebuild fallback; prefer MCP):
xcodebuild build -project "Immich Slideshow.xcodeproj" -scheme "Immich Slideshow" \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
```
Available iPad sims include: iPad Pro 13"/11" (M5), iPad Air 13"/11" (M4), iPad mini (A17 Pro), iPad (A16).

## Workflow notes (Claude orchestrates, Codex implements)
This worked well — reuse it for future features:
- Brief via `.claude/scripts/codex-brief.sh "<task>" <files...>`, then
  `codex-agent start "$(...)" -s workspace-write -r medium`. Omit `--map` (no
  `docs/CODEBASE_MAP.md` yet).
- **First launch in the repo stalls on a "Do you trust this directory?" prompt** —
  answer with `codex-agent send <job> "1"`. Already trusted now, but watch for it.
- **Codex needs `--disable-sandbox` (+ `CLANG_MODULE_CACHE_PATH=.build/module-cache`)**
  for SwiftPM inside its sandbox (non-writable Home caches). That's an env artifact, not a
  code issue — Claude re-verifies unsandboxed and it's clean.
- **Codex does not auto-commit.** Claude commits after the verification gate (the pattern
  used for every slice here). The brief intentionally doesn't tell Codex to commit.
- For TDD slices with intertwined shared types (e.g. a protocol referencing a not-yet-built
  model), spell out the **micro-order** in the brief (red→green steps) so Codex doesn't
  collapse them. This produced genuine red-first transitions.

## Constraints honored (keep honoring)
- No secrets in code/UserDefaults/logs; API key only sent as `x-api-key`, never logged.
- No TLS validation disabled; standard `URLSession` over HTTPS.
- `.gitignore` was amended to track `Packages/ImmichClient/` (otherwise `Packages/` is ignored).
