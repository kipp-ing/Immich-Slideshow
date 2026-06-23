# TDD Workflow

Binding loop for every feature. Claude Code runs it per task from `tasks.md`.

## Red → Green → Refactor
1. **Red** — write a test describing the desired behavior. Run it via XcodeBuildMCP → it must
   **fail** (otherwise it isn't testing anything).
2. **Green** — minimal implementation until the test is green. Nothing more than necessary.
3. **Refactor** — clean up, tests stay green. Only then move to the next task.

No implementation without a previously failing test. No skipping across multiple tasks.

## Test Levels
- **Unit** (main focus): logic per module, isolated. Mock network/MQTT/keychain behind
  protocols.
- **Integration** (few, targeted): real Immich server / real broker. Local only, not on every
  run.
- **UI/Preview**: SwiftUI previews for visual review (Apple Xcode MCP), no mandatory assertions.

## Enforcing Testability
- `ImmichAPI` protocol → live impl (URLSession) + mock impl (fixed responses) for tests.
- `KeychainStore` protocol → real keychain + in-memory fake.
- `MQTTTransport` protocol → real client + fake that records published messages.
- Time/timer injectable (no `Date()` directly in logic), so slideshow timing is deterministically
  testable.

## Per Module: What Gets Tested First
- **ImmichClient**: parsing album JSON → models; auth header set; error cases (401, timeout).
- **SlideshowView (ViewModel)**: ordering, shuffling, advancing after interval, prefetch
  triggering.
- **Onboarding**: step validation; connection-test result → correct next step; key lands in the
  keychain.
- **PowerManager**: brightness clamped to 0…1; idle timer on/off at start/stop.
- **ThemeSettings**: persistence round-trip; defaults correct.
- **HAControl**: discovery payload built correctly; incoming command → correct action triggered;
  LWT set.

## Definition of Done (per task)
- Test(s) green via XcodeBuildMCP.
- No secrets in code.
- Constraints from `CLAUDE.md` honored.
- For UI: preview renders without crashing.
