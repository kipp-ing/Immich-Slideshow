# Phase 0 Research: Settings & Onboarding UX Consolidation

No external/unknown technologies — everything reuses existing modules. The open design choices below
were resolved against the current codebase (002 onboarding, 009 connection settings, 006 broker setup).

## D1 — Merge the two onboarding steps into one validated action

**Decision**: Replace `OnboardingStep.server` + `.apiKey` with a single `.connection` step, and replace
`submitServerURL()` + `submitAPIKey()` with one `submitConnection()` that makes a **single `albums()`
call** with the entered URL + key. Advance to `.album` only on success.

**Rationale**: `albums()` requires both a reachable server and an authorized key, so one call proves
both at once and returns the album list needed for the next step — exactly the pattern 009's
`ConnectionSettingsViewModel` already uses. `ImmichError` already classifies failures as *unreachable*
vs *unauthorized*, and `ConnectionError.message(for:)` maps them to distinct user messages, so a single
round trip still satisfies FR-003 / SC-006 (distinct server-vs-key errors) without the separate
`serverVersion()` pre-check the two-step flow used. The key is saved to the Keychain only after a
successful `albums()` (unchanged from today's `submitAPIKey()`), preserving Constitution III.

**Alternatives considered**:
- *Keep `serverVersion()` then `albums()` within one button press* — two round trips for no added
  signal; `albums()` alone already distinguishes the two failure classes. Rejected as redundant.
- *Validate server on field blur, key on submit* — reintroduces two implicit "steps" and more state;
  contradicts the one-action goal. Rejected.

## D2 — Distinguishing unreachable vs unauthorized after the merge

**Decision**: Rely on the existing `ImmichError` cases surfaced by `albums()` and the existing
`ConnectionError.message(for:)` mapping; no new error types. The combined screen shows the mapped
message inline and keeps entered values (FR-003).

**Rationale**: Reuses tested mapping from 002/009; avoids a parallel error vocabulary. The
`OnboardingViewModelTests` already exercise unreachable (kept on step) and unauthorized (kept on step,
no key saved) — these tests are rewritten to assert the same outcomes on the merged `.connection` step.

## D3 — Folding the broker form into Settings

**Decision**: Extract the host/port/username/password/`passwordIsSet` state and the
load/save/remove + validation-message logic out of `BrokerSetupView` into a new `@Observable`
`BrokerSetupViewModel` in `BrokerSetupKit`. `SlideshowSettingsView` embeds the broker fields as the
content of a collapsed-by-default `DisclosureGroup`, backed by that view model. `BrokerSetupView`
becomes a thin SwiftUI wrapper over the same view model (kept only if a standalone presentation is
still wanted; otherwise its body content is reused inside the section).

**Rationale**: Today the broker form's logic lives inside the SwiftUI `View` (`@State` + private
`save`/`remove`/`loadExisting`) and is **untested**. Extracting an `@Observable` view model gives a
host-testable seam (Constitution I/II) and lets the same logic render both inline in Settings and, if
needed, standalone — without duplicating the keep-existing-password rule (FR-013). The existing
`BrokerSettingsStore` protocol and `BrokerSetupUITestStore` are reused unchanged for tests.

**Alternatives considered**:
- *Embed `BrokerSetupView` as-is inside a `DisclosureGroup`* — fastest, but leaves the save/validate
  logic untestable and couples it to a `NavigationStack`/toolbar it no longer owns. Rejected on
  Constitution I (test-first) grounds.

## D4 — Connection section in Settings

**Decision**: Reuse the existing `ConnectionSettingsViewModel` (009) as the backing logic and present
its fields inside a collapsed-by-default `DisclosureGroup` in `SlideshowSettingsView`, replacing the
current row-that-opens-a-sheet. The slideshow's connection-error recovery path (also 009) is unchanged.

**Rationale**: 009 already delivers the tested validate-before-persist + live-reconnect + never-show-key
behavior; this feature only changes its **placement** (inline section vs pushed sheet), satisfying
FR-009/FR-012 with no new logic.

## D5 — Default expansion state and the inert shared-link seam

**Decision**: Connection and MQTT disclosure sections default to **collapsed**. The shared-link
placeholder on the onboarding screen is a visibly **disabled** row labelled as not-yet-available, with
no action wired (FR-008).

**Rationale**: Constitution VII (calm/simple default) — brightness and display options stay directly
visible; advanced config is tucked away until opened. An inert, clearly-disabled seam reserves the
layout for spec 011 without inviting taps or implying broken behavior.

## D6 — The "settings not scrollable" defect (US3)

**Decision**: Treat the scroll bug as a **reproduce-then-fix** task on the simulator before/while
adding the new sections. `SlideshowSettingsView` is a SwiftUI `Form` presented in a `.sheet`; a `Form`
scrolls by default, so the reported "swallows lower sections" needs root-causing on-device (candidates:
a sheet presentation detent, a fixed frame/`ScrollView` nesting, or `DisclosureGroup`-in-`Form` layout
quirks on iPad). The fix is whatever makes every section reachable in both orientations and with the
keyboard up (FR-015/FR-016); confirmed via XcUITest scrolling to the bottom-most section.

**Rationale**: The cause is not determinable by static reading alone (the `Form` *should* scroll), so
the plan books a simulator repro rather than guessing a fix. This is inline work (UI/simulator) per
CLAUDE.md.

## D7 — Reset dialog cleanup

**Decision**: Remove the "Broker einrichten" button from the "Reset configuration?" confirmation dialog
in `SlideshowView` (and its `showBrokerSetup` sheet) once broker setup is reachable from Settings; the
dialog returns to reset + cancel only (FR-011).

**Rationale**: The dialog hosting broker setup is the discoverability bug (B1). With MQTT in Settings,
the dialog has a single responsibility again.
