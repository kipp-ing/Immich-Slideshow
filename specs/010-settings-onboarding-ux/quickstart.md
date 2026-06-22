# Quickstart / Validation: Settings & Onboarding UX Consolidation

Validation guide for the three slices. Host unit tests run via SwiftPM; the SwiftUI flows and the
scroll fix are verified on the simulator via XcodeBuildMCP (the constitution's primary gate). All
secrets stay in the Keychain; no live server required (mocks + `--uitest*` seams).

## Prerequisites

- iOS 26.5 simulator that builds the app scheme (see project memory: pin `simulatorId`,
  `preferXcodebuild`).
- Existing fakes: `InMemoryConfigStore`, `InMemoryKeychainStore`, `MockTransport`-backed `ImmichAPI`,
  and an in-memory `BrokerSettingsStore` (`BrokerSetupUITestStore` pattern).

## US1 — One-screen onboarding

**Host unit tests** (`OnboardingViewModelTests`, rewritten for `.connection`):

```
swift test --package-path Packages/OnboardingKit
```

Expected: the merged-step tests in `contracts/OnboardingViewModel.md` pass — advance to `.album` only
when reachable + authorized + non-empty album list; distinct unreachable vs unauthorized messages
(SC-006); key saved only on success.

**Simulator / UI**: launch onboarding (no stored config). Confirm one screen shows server + API key
with helper text and a single primary **Continue**; Continue is disabled until both fields are filled;
a valid pair advances to album selection; a wrong key keeps the screen open with a clear error and
preserved input. Confirm the shared-link placeholder is visible but disabled (no action).

## US2 — Connection + MQTT folded into Settings

**Host unit tests** (`BrokerSetupViewModelTests`, new):

```
swift test --package-path Packages/BrokerSetupKit
```

Expected: the broker view-model tests in `contracts/BrokerSetupViewModel.md` pass — load without
secret, save persists, empty password keeps the stored secret, invalid port/host report errors, remove
clears.

**Simulator / UI**: from a running slideshow open Settings. Confirm Connection and MQTT appear as
collapsible sections (collapsed by default). Expand MQTT → edit host → save → persists without the
reset dialog. Expand Connection → change URL/key → validated before persist, applies live, key never
shown (009 behavior). Confirm the "Reset configuration?" dialog no longer offers broker setup.

## US3 — Settings scroll fix

**Simulator** (XcUITest): open Settings with all sections present. Scroll to the bottom-most section in
**portrait** and **landscape**; confirm it becomes fully visible. Focus a text field in a lower section
so the keyboard appears; confirm the field and the controls below it remain reachable.

## Full gate before merge

Per project memory, run the full XcUITest suite via XcodeBuildMCP `test_sim` before merging (screenshots
alone miss UI-test regressions), plus the package unit tests above. Cross-model `/codex:review` on the
final diff.
