# Handover — ImmichClient (Feature 001)

_Last updated: 2026-06-18. Branch: `001-immich-client`._

## TL;DR
The `ImmichClient` module is **complete and verified — all tasks T001–T025 done.**
Host unit tests 14/14 green (MockTransport, SC-001…SC-006 covered); both the
`ImmichClient` library and the `Immich Slideshow` app compile/link clean for iPadOS
through **XcodeBuildMCP** (`build_sim`, iPad Pro 11" (M5), 0 warnings/errors).
**Feature is ready for a PR to `main`.**

## XcodeBuildMCP — fixed
The server failed to connect with `-32000` because `.mcp.json` invoked
`npx xcodebuildmcp@latest` with **no subcommand**; v2.6.x prints usage and exits unless
you pass `mcp`. Fixed: args are now `["-y", "xcodebuildmcp@latest", "mcp"]`. It's enabled
in `.claude/settings.local.json` (`enableAllProjectMcpServers` + `enabledMcpjsonServers`).
Verified connected (24 tools).

Note on the test gate: the package test target isn't bound into an Xcode test scheme and
the SwiftPM MCP workflow tools are disabled by default, so `test_sim` can't run the suite.
The unit suite runs on the host (`swift test`); MCP covers the iPadOS compile/link gate.
If you later want the suite through MCP, either add the test target to a shared
`ImmichClient` test scheme or enable the SwiftPM workflow in XcodeBuildMCP config.

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

## Next step
Open a PR from `001-immich-client` → `main`. The feature slice (ImmichClient data layer)
is done and verified; no further tasks in `tasks.md`.

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
