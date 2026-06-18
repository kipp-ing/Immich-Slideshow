# Handover — Project State

_Last updated: 2026-06-18. Branch: `002-onboarding` (001 is **not yet merged to `main`**;
002 builds on top of it)._

This file is just the **live state + next steps**. Durable knowledge lives in the docs:

- [docs/testing.md](docs/testing.md) — how to run each test layer, the `--uitest` seam, the live-server check.
- [docs/engineering-notes.md](docs/engineering-notes.md) — learnings, gotchas, conventions, Codex workflow.
- [CLAUDE.md](CLAUDE.md) — architecture, modules, constraints, working agreement.

## Status

- **Feature 001 — ImmichClient:** complete + verified, including the live **Immich 2.7.5**
  contract check (real decode path: version / albums / assets / preview).
- **Feature 002 — Onboarding:** **COMPLETE** (T001–T032). Three-step flow Server → API-Key → Album;
  `StartupGate` routes relaunch; reset clears config + the real Keychain; security review clean
  (key Keychain-only, zero logging).
- **Tests green:** ImmichClient 17 host + OnboardingKit 19 host; app-hosted simulator suite plus the
  hermetic onboarding XCUITest — `test_sim` **13/13**. See [docs/testing.md](docs/testing.md) to run them.

## Design notes worth keeping

- **`StartupGate.initialStep()`** → `.done` (config + key) / `.apiKey` (config, no key) / `.server` (else).
  The spec's "album-ID missing → album" row is **unreachable**: `ConfigStore.load()` is all-or-nothing and
  the view model only persists at `selectAlbum`, so partial state never exists — it folds to `.server`
  per FR-011. Mid-flow resume at `album` would require persisting the URL after step 1 (a contract change,
  out of scope).

## Next up

A new feature — likely **SlideshowView** or **PowerManager** (see the module list in
[CLAUDE.md](CLAUDE.md)). Start with `/speckit-specify`. For any new SwiftUI flow, reuse the hermetic
XCUITest seam (`UITestSupport`; see [docs/testing.md](docs/testing.md)) so the UI is testable offline
from day one.
