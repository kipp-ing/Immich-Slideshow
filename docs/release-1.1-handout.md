# Release 1.1 — what Jan needs to do by hand

Audited 2026-07-29 against the live App Store Connect API. This is the short list of things
**no test suite and no agent can do for you**, in the order they should happen.

Everything the machines *can* prove is proven — see `docs/testing.md` for the suites and
`docs/manual-verification.md` for the full per-spec tick-list this summarises. Nothing below
is a re-run of something already green.

---

## 0. The one-line situation

Release 1.1 (build 9) is the **first version the public will ever see** (FR-1100-17), because
v1.0 build 8 was approved but the app has never been available in any territory. The store
record is essentially complete. **Three things block the release, and one of them takes days,
so start it today.**

---

## 1. START NOW — EU trader status (multi-day, blocks Germany)

**This is the long pole. Nothing else here takes calendar time; this does.**

27 of 175 territories carry `TRADER_STATUS_NOT_PROVIDED` on their availability record — every
EU member state, **including Germany**, the home market the entire de-DE listing was written
for. Without trader status the app legally cannot be sold in the EU at all (Digital Services
Act).

- **Where:** App Store Connect web UI → **Business** → *Trader Status*. It is not exposed in
  the ASC API, so it cannot be scripted.
- **What it needs:** your legal trader details (name, address, phone, email) — these become
  **publicly visible on your App Store listing** in the EU.
- **Expect multi-day verification by Apple.** Submitting 1.1 for review before this clears is
  fine; *selling* in the EU is not possible until it does.

**Do this first, then come back to the rest.**

---

## 2. Check whether anyone already downloaded v1.0 (10 minutes, changes what you write)

v1.0 was approved **2026-07-14** with `releaseType: AFTER_APPROVAL`, and all 175 territories
were switched off effective **2026-07-22**. That leaves a **~7-day window (07-15 → 07-22)
where the ungated build may have been publicly downloadable.**

- **Where:** ASC → **App Analytics** → Downloads, date range 2026-07-14 → 2026-07-23.
- **If the count is zero:** nothing changes. "Initial release." in What's New is honest.
- **If anyone installed:** two consequences —
  1. **Never-claw-back (FR-1100-13) binds for those users** — they have an ungated build and
     must not lose anything they already had.
  2. **"Initial release." / "Erste Veröffentlichung." is factually wrong** and should be
     reworded before submission.

This is cheap to check and it determines whether item 5 below needs an extra upgrade-path pass.

---

## 3. Attach build 9 to the 1.1 version record (2 minutes)

Build 9 is uploaded and `VALID`, but the **1.1 version record has no build attached**. The
submission cannot proceed without it.

- **Where:** ASC → the app → **1.1 Prepare for Submission** → *Build* → select build 9.
- While you are there, attach the **four in-app purchases to the submission** — first-time IAPs
  are reviewed together with the build, and they will not be reviewed if left off.

---

## 4. Sandbox purchase testing (the big one — needs real Apple IDs)

Nothing here is automatable: StoreKit sandbox, Family Sharing and Ask-to-Buy all require real
accounts. The StoreKit *adapter* is already proven in CI (7/7 `StoreKitClientTests` under
headless `xcodebuild`) — what is unproven is the **real StoreKit path against real ASC
products**, which is exactly where product-id drift and Family Sharing flags bite.

You need: a sandbox tester account, a second device, and a family-member account.

**Core purchase flow**
- [ ] **Products load at all.** If this fails, it is id drift — the ids changed to
      `ing.kipp.ownframe.*` (ASC rejects hyphens, and the bundle id has one). This is the
      single most likely failure and the cheapest to spot.
- [ ] Buy the **Supporter Unlock** for real → gated features activate **without a relaunch**
      (SC-1100-03).
- [ ] Buy a **tip** → thank-you state, and **no entitlement change whatsoever** (FR-1100-08).
- [ ] **Cancel mid-flow** → back to the offer, no charge, no nagging follow-up.
- [ ] **Ask-to-Buy** with a child account → pending; approve later → entitlement arrives over
      the updates stream **without reopening the app** (FR-1100-15).
- [ ] **Refund/revoke** → relocks on next refresh, and stored settings survive intact
      (FR-1100-12 + FR-1100-14).
- [ ] **Relock is boundary-aligned, not instant** — with Ken Burns running, trigger the relock
      and watch a photo already on screen: its pan must **finish naturally**, the gate applies
      at the next advance. A pan freezing mid-photo is the bug this catches.

**Household**
- [ ] Restore on a **second device**, same sandbox account → unlocks repopulate.
- [ ] A **second Family Sharing member** gets the unlocks free, without paying again.
      (Family Sharing is ON for the unlock, OFF for the three tips — verified in ASC.)

**Unattended-frame behaviour — the whole reason this feature is cache-first**
- [ ] **24 h offline entitlement soak** (SC-1100-04): buy, take the frame fully offline, leave
      it a day. Owned features still active at every relaunch. Piggyback the 1000-series soak.
- [ ] **Airplane mode from cold boot, already entitled** → features active at first render, no
      loading state, no network wait (FR-1100-10).
- [ ] **≥ 4 h free-tier playback with zero purchase UI** (SC-1100-02). The XCUITest proxy
      window is ~12 s; this is the actual criterion.

---

## 5. Pre-gate upgrade path — your own running frames

This is the one class of bug that **only your own frames can find**, because it needs a device
that was configured *before* the gate existed.

- [ ] On a frame with a broker configured **before** this update: install the gated build →
      stored config survives **byte-for-byte**, nothing cleared, nothing migrated (SC-1100-06).
- [ ] **Free telemetry** (FR-1100-03a): at the broker (`mosquitto_sub -v`), an **unentitled**
      frame connects and publishes **read-only sensors only** — availability, `current_photo`,
      `phase`, `photo_count`, `version`, and now `frame_status`. Confirm **zero** controllable
      entities, **zero** command-topic subscriptions, and that it acts on **zero** HA commands.
- [ ] **Retained-discovery retraction (T056)** — after the gated build connects unentitled, the
      controllable entities must **disappear from HA**, not just go stale. Confirm
      `light.` / `select.` / `switch.` / `number.` / `button.` frame entities are gone while the
      sensors remain.

      *Premise already verified live 2026-07-21* — all 19 discovery configs are retained, and an
      empty retained payload provably removes an entity on your HA. What is left is only the
      **app-side run**: confirm the app emits those empty payloads on connect.
- [ ] Buy the unlock → controllable entities reappear, HA control resumes from the previously
      stored settings with **zero re-entry** (FR-1100-14).

> **Framepad state note:** it currently carries a **dev-signed Debug build and is unconfigured**
> (no source, no broker) — which is why its HA entities have read `unavailable` since 07-20.
> **Reconfigure it before these checks**, and reinstall the App Store build afterwards. Both
> checks need a frame that actually connects.

---

## 6. New in this release — verify the availability fix live

PR #49 decoupled HA availability from in-app UI. The defect's `onDisappear` trigger **only
reproduces on iOS 17 hardware**, so the simulator cannot prove it. Framepad is iOS 17.7.10.

- [ ] Open **Settings** over the running slideshow → HA **stays online** (it used to flip to
      offline whenever a modal covered the slideshow).
- [ ] The new **`frame_status`** diagnostic sensor flips `running` → `inactive` while the modal
      is up, and back. It is free-tier, so it publishes without the unlock.
- [ ] Genuine exit and backgrounding still tear down exactly as before (FR-400-02/03).

---

## 7. Device day — the rest (eyes and hardware only)

- [ ] **Ken Burns smoothness**, old 60 Hz iPad + a ProMotion iPad: steady drift reads buttery at
      panel distance, **no stutter at photo swaps**. Pause → snaps to the calm full frame
      instantly; resume → arc restarts tight, no zoom-pop.
- [ ] **Change photo duration mid-photo** → drift rate retunes without a visible jump.
- [ ] **SC-220-07** — scan a shared-link **QR with the real camera** → onboarding completes.
- [ ] **SC-120-05** — with a library already set up, add a second shared album by scanning its
      QR from Settings → Sources → + → Shared link, no typing. Same camera hardware, so do both
      in one pass. Also check the **camera-denied** path still leaves manual entry usable.
- [ ] **German Siri** on a German-set device: the localized phrases are recognised ("Pausiere
      OwnFrame", "Nächstes Foto auf OwnFrame") and **Get Frame State** reads back in German
      ("Läuft" / "Pausiert"). *Tip: create a fresh shortcut per check — Siri caches old
      phrasing.*
- [ ] **Real Photos library** end-to-end (900 quickstart).

Rig recipes and every known trap: `docs/device-testing.md`, driven by
`.claude/scripts/framepad.sh`. Two device settings are physical-only and will hang a run if
missed: **Developer → Enable UI Automation**, and **Auto-Lock → Never**.

---

## 8. LAST ACTION — flip availability on

**Do not do this until 1.1 is approved.** All 175 territories are currently `available: false`,
and that switch is the *only* thing keeping the ungated v1.0 build 8 off the store. Turning
availability on before 1.1 ships would **publish the ungated build instantly** and break
FR-1100-17.

Order: 1.1 approved → then availability on → then the app is public for the first time.

---

## Already done — do not redo

Verified against the live ASC API on 2026-07-29:

| Item | State |
|---|---|
| App name / subtitle (en-US + de-DE) | OwnFrame — "Your photos, your own frame" / "Deine Fotos, dein Rahmen" |
| Description, keywords, promo text | Set, both locales |
| Privacy policy URL | Set, both locales |
| Screenshots | 7 × iPad Pro 12.9″ + 7 × iPhone 6.7″, both locales, all `COMPLETE` |
| Categories | Photo & Video / Lifestyle |
| Age rating | Questionnaire answered, all-none → 4+ |
| App Review contact + notes | Jan Kipping, app@kipp.ing, 1351-char notes, no demo account required |
| 4 in-app purchases | All `READY_TO_SUBMIT` — correct `ing.kipp.ownframe.*` ids, prices set, review screenshots `COMPLETE`, 175 territories |
| Family Sharing | ON for Supporter Unlock, OFF for all three tips |
| Version / build | 1.1 (9) consistent across all ten target configurations; build 9 uploaded and `VALID` |
| StoreKit adapter | 7/7 `StoreKitClientTests` green headlessly in CI — no longer a device-day item |

**Not verifiable via the API — glance at it in the web UI:** the **privacy nutrition label**
should read *Data Not Collected*.

---

## Notes

- **iOS only.** There is no tvOS version record in ASC, consistent with tvOS being deferred.
  Universal purchase for tvOS stays a later concern.
- **The tip-jar review screenshot** shows the stub store's placeholder `$1.00` on all three
  rows rather than real ASC prices. Harmless for review, but re-shoot if a reviewer queries it.
- **No price points live in this repo** and none should be added — pricing is decided in ASC.
