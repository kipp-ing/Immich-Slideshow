# Handover — Onboarding (Feature 002)

_Last updated: 2026-06-18. Branch: `002-onboarding` (branched off the 001 work; **001 not yet
merged to `main`** — 002 builds on top of it)._

## TL;DR
Feature **001 ImmichClient is complete + verified** (14/14 host tests; app + library compile/link on
the iPad sim via XcodeBuildMCP). Feature **002 Onboarding is fully spec'd/planned/tasked**, and
**T001–T010 are done**: the new `Packages/OnboardingKit` package exists with shared types + stores +
fakes, **6 host tests green**. **Next up: US1 (T011–T021)** — the MVP onboarding flow.

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

## Next: User Story 1 (MVP) — T011–T021 in `specs/002-onboarding/tasks.md`
Recommended split (it's pre-marked in tasks.md):
- **Codex batch → T011–T016** (host-testable, MockTransport/fakes):
  - T011/T015: add `serverVersion()` to `ImmichAPI` + `ImmichClient` (step-1 reachability)
  - T012–T014/T016: `OnboardingViewModel` (`@Observable`) — server/key/album flow, `ImmichError`→message
    mapping, single album-fetch, `isBusy`
- **Claude inline → T017–T021** (need the simulator):
  - T017 keychain round-trip test (red) → T018 real `KeychainAPIKeyStore` (Security)
  - T019 SwiftUI step views, T020 app routing, T021 link `OnboardingKit` into the app target (pbxproj) +
    `test_sim` verification

⚠️ **Open real-world flag (T015)**: the reachability route `GET /api/server/version` is **assumed** —
verify against the live Immich (`/api/openapi.json`) before relying on it (Constitution IV). The Codex
batch is fully mockable, so it does not block on this.

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
