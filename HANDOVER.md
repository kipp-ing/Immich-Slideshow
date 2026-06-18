# Handover — Onboarding (Feature 002)

_Last updated: 2026-06-18. Branch: `002-onboarding` (branched off the 001 work; **001 not yet
merged to `main`** — 002 builds on top of it)._

## TL;DR
Feature **001 ImmichClient is complete + verified**. Feature **002 Onboarding: Setup + Foundational +
US1 (MVP) + US2 are done** — **T001–T025 complete**. The three-step flow (Server → API-Key → Album)
builds and runs on the iPad sim; the real keychain round-trip is green app-hosted; `StartupGate` routes
relaunch (complete state → main screen, else first missing step). **Next up: US3 (T026–T029)** — `reset()`
on the ViewModel + a reset entry point, then **Polish (T030–T032)**.

Test counts: ImmichClient **17** host + OnboardingKit **18** host (incl. 4 StartupGate); app-hosted sim
suite **11/11** (incl. `OnboardingKeychainTests` real keychain round-trip). Verify with `test_sim`
(scheme "Immich Slideshow", iPad Pro 11" M5, `preferXcodebuild: true` — already the session default).
Fresh-install onboarding UI confirmed via screenshot (server step renders, light/simple).

⚠️ **Still-open real-world flag (T015)**: `GET /api/server/version` and its `{major,minor,patch}` decode
are still **assumed** — all US1 tests are mocked, so nothing failed, but verify against the live Immich
(`/api/openapi.json`) before trusting step-1 reachability in the field (Constitution IV).

## What's done on 002 (all committed on `002-onboarding`)
- **Spec → Plan → Tasks** via Spec Kit, all in `specs/002-onboarding/` (spec.md, plan.md, research.md,
  data-model.md, contracts/, quickstart.md, tasks.md). `/speckit-analyze` ran clean (0 critical);
  fixes D1 (single album-fetch) + C1 (keychain test-before-impl) applied.
- **T001–T010** — `Packages/OnboardingKit/` (depends on `ImmichClient`):
  - `AppConfiguration`, `OnboardingStep`
  - `ConfigStore` protocol + `UserDefaultsConfigStore` (https+host validation, injectable defaults)
  - `KeychainStore` **protocol only** (real impl is T018)
  - Test fakes `InMemoryConfigStore` / `InMemoryKeychainStore` (forced-save-error option)
  - `ConfigStoreTests` — 6 host tests green (TDD: T009 red before T010)

## US1 done (T011–T021) — what landed
- **T011–T016** (Codex batch, committed `385c243`): `serverVersion()` on `ImmichAPI`/`ImmichClient`
  (`GET /api/server/version` → `"major.minor.patch"`); `OnboardingViewModel` (`@Observable`) with
  `submitServerURL()`/`submitAPIKey()`/`selectAlbum(id:)`, `ImmichError`→message mapping, single
  `albums()` validation, `isBusy` guard. `reset()` deliberately **not** added yet (US3/T027).
- **T017–T021** (Claude inline, committed `7901e1c`): real `KeychainAPIKeyStore` (Security,
  `kSecClassGenericPassword`, fixed service/account) + app-hosted round-trip test; SwiftUI step views
  under `Immich Slideshow/Onboarding/` (`OnboardingFlowView` + Server/APIKey/Album, SecureField for the
  key); app routing in `Immich_SlideshowApp.swift` (complete state → `ContentView`, else flow);
  `OnboardingKit` linked into app + test targets via `project.pbxproj`.

## US2 done (T022–T025) — what landed
- **T022–T023** (Codex, committed `71bf65c`): `StartupGate(config:keychain:).initialStep()` →
  `.done` (complete config + key) / `.apiKey` (complete config, no key) / `.server` (else). 4 host tests.
  **Design note:** the spec's "album-ID missing → album" row is unreachable — `ConfigStore.load()` is
  all-or-nothing and the VM only persists at `selectAlbum`, so partial state never exists. It folds to
  `.server` per FR-011. (If product later wants mid-flow resume at `album`, that needs persisting the
  URL after step 1 — a contract change, not currently in scope.)
- **T024–T025** (Claude inline, committed `16c8e14`): `Immich_SlideshowApp.swift` derives the initial
  step from `StartupGate` instead of the temp check. Sim: 11/11 green, fresh-install server step renders.
  ⚠️ The full "complete config → relaunch → main screen" path can't be driven end-to-end in the sim
  without a live Immich (onboarding submits hit a real server); covered by the 4 StartupGate host tests.

## Next: User Story 3 — T026–T029, then Polish T030–T032 in `specs/002-onboarding/tasks.md`
- **T026 [P]** (Codex-suitable, host): test `OnboardingViewModel.reset()` → `ConfigStore.clear()` +
  `KeychainStore.delete()`, clears inputs, `step = .server`. In `OnboardingViewModelTests.swift`.
- **T027**: implement `reset()` in `OnboardingViewModel.swift` (was deliberately omitted in US1).
- **T028** (Claude inline): a reset entry point in `ContentView.swift` (placeholder main screen) /
  a simple settings action that calls `reset()` and returns to onboarding. Note ContentView is still
  the stock "Hello, world!" placeholder — wire the reset action there.
- **T029** (Claude inline): sim verification — trigger reset → onboarding restarts at step 1; the
  previously saved key is gone from the real `KeychainAPIKeyStore`.

> pbxproj pattern for new local packages (used for OnboardingKit): add to 6 spots — PBXBuildFile (one
> per target frameworks), each target's PBXFrameworksBuildPhase `files`, each target's
> `packageProductDependencies`, project `packageReferences`, plus the `XCLocalSwiftPackageReference`
> and `XCSwiftPackageProductDependency` sections. Synthetic IDs `3DAA0100…0008–000C` are OnboardingKit's.

⚠️ **Open real-world flag (T015)**: `GET /api/server/version` route + `{major,minor,patch}` decode are
**assumed** (all US1 tests mocked). Verify against the live Immich (`/api/openapi.json`) before relying
on step-1 reachability in the field (Constitution IV).

## Environment / gotchas (hard-won this session — keep honoring)
- **XcodeBuildMCP**: `.mcp.json` must invoke `npx -y xcodebuildmcp@latest **mcp**` (the `mcp`
  subcommand). Without it the server prints usage and the client gets `-32000`. Enabled in
  `.claude/settings.local.json`. After a fresh start, run `/mcp` to confirm it's connected.
- **`preferXcodebuild: true`** for `build_sim`/`test_sim` — the incremental builder (xcodemake) chokes
  on project changes; set it via `session_set_defaults`. Default sim: **iPad Pro 11" (M5)**,
  id `9B6E6F8A-D3A6-4FBC-942B-E51E120CAA35`.
- **SPM package *test* targets can't run on the simulator via the app `.xcodeproj`** (only library
  products surface as schemes). So: package logic → host `swift test`; real-target/simulator coverage →
  the **app-hosted** test bundle `Immich SlideshowTests` (it links the packages; see 001). This is why
  T017's keychain test lives in the app test target. (Also saved in project memory.)
- **`.gitignore`** ignores `Packages/*`; each local package needs an explicit allow line. Already added:
  `!Packages/ImmichClient/`, `!Packages/OnboardingKit/`.
- **Don't create Xcode files (schemes, etc.) while a Codex job runs in the same tree** — Codex "tidies"
  untracked out-of-scope files and deleted a scheme once. Sequence such edits, or keep the tree clean.

## Workflow: Claude orchestrates, Codex implements
- Brief via `.claude/scripts/codex-brief.sh "<task>" <files...>` (set `VERIFY_PACKAGE=Packages/OnboardingKit`
  for 002 logic), then `codex-agent start "$(...)" -s workspace-write -r medium`. Omit `--map` (no
  `docs/CODEBASE_MAP.md`).
- **Codex needs `--disable-sandbox` + `CLANG_MODULE_CACHE_PATH=/private/tmp/...`** for SwiftPM (non-writable
  Home caches). Env artifact only — **Claude re-verifies unsandboxed** as the real gate.
- **Codex does not auto-commit.** Claude verifies (host `swift test` + reviews diff for scope), fixes
  `.gitignore` if a new package, marks tasks `[X]`, then commits with `Co-authored-by: Codex`.
- Spell out the **micro-order** (red→green) in briefs for TDD slices; state explicit scope ("protocol
  only, no real impl") to prevent over-reach.
- Poll a running job for completion with `codex-agent capture <id>` grepping for `Worked for [0-9]`
  (don't match `error:` — that fires on the expected red test).

## Verification commands (host fallback)
```bash
# OnboardingKit host tests:
cd "Packages/OnboardingKit" && swift build && swift test     # 6 green
# ImmichClient host tests:
cd "Packages/ImmichClient" && swift build && swift test       # 14 green
```
Simulator/app gate goes through XcodeBuildMCP (`build_sim`/`test_sim`, scheme "Immich Slideshow",
`preferXcodebuild: true`).

## Constraints honored (keep honoring)
- No secrets in code/UserDefaults/logs; API key only via `KeychainStore` (Keychain), sent as `x-api-key`.
- No TLS validation disabled; HTTPS only (URL validation rejects non-https).
- TDD first (Constitution I); modules behind injected protocols; no singletons.
