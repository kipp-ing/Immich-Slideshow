# Manual Verification — pending hardware/simulator checks

The host test suites cover all the logic offline (see [testing.md](testing.md)). What remains can only be
confirmed against real hardware: a live MQTT broker + Home Assistant (feature 005) and an on-device
UserDefaults/Keychain inspection on the simulator (feature 006).

This file is the checklist for those steps. Tick the matching tasks in the feature `tasks.md` once each
passes. Nothing here runs in CI.

---

## Feature 005 — HAControl (real broker + Home Assistant)

**Open tasks:** `T019` (US1), `T023` (US2), `T027` (US3).

### Prerequisites
- A reachable MQTT broker over **TLS** (port 8883) with Home Assistant's MQTT integration connected to it.
- Valid broker credentials saved in the app (use the "Broker einrichten" sheet from the slideshow chrome,
  feature 006 US1) — host, TLS port, username, password.
- App running the slideshow in the foreground.

### Optional: automated TLS transport check first
Before touching Home Assistant, the real `NIOMQTTTransport` can be exercised against a local mosquitto
broker (connect + LWT, retained publish, subscribe round-trip, reconnect after a drop). Trust is anchored
to a local test CA with verification left **on**:

```sh
MQTT_INTEGRATION=1 Packages/HAControlKit/Scripts/mqtt-integration.sh
```

### T019 — US1: Pause/Play + availability
1. Start the slideshow with valid broker credentials present.
2. In Home Assistant a device **"Immich Slideshow"** appears with a Pause/Play switch and an availability
   (online/offline) indicator. *(SC-001)*
3. Toggle the switch in HA → the slideshow pauses / resumes; the HA state mirrors the app. *(SC-002)*
4. Pause/resume **in the app** → the HA switch reflects it. *(SC-003)*
5. Send the app to the background / leave the slideshow → the device goes **"offline"** in HA (LWT);
   return to the foreground → **"online"**. *(SC-004)*
6. Confirm the connection uses the **TLS port only** — no plaintext. *(SC-007)*
7. Sanity: trigger a broker drop/restart → the entity recovers without duplicate devices (stable
   `unique_id`). *(SC-005)*

### T023 — US2: Brightness from HA
1. With `.brightness` enabled, HA shows a **dimmable light** for the device. *(SC-008)*
2. Change brightness from HA → the iPad screen brightness follows, and the applied value is echoed back.
3. Background the app → HA cannot force brightness (foreground-gated); no crash.

### T027 — US3: Album from HA
1. With `.album` enabled, HA shows a **select** whose options are the album list. *(SC-009)*
2. Pick a valid album in HA → the slideshow switches album and echoes the new selection.
3. Pick an unknown/invalid value → no-op; the echoed state stays unchanged.

---

## Feature 006 — Broker setup (simulator persistence + secret boundary)

**Open tasks:** `T014` (US1), `T019` (quickstart SC mapping).

US2 (change / remove) is now covered automatically by
`BrokerSetupUITests.testExistingBrokerPrefillsFieldsMasksPasswordAndRemoves` (prefill, masked password,
remove → dismiss). What's left here is the **real-Keychain** round-trip, which the XCUITests deliberately
skip (they use an in-memory store), plus the quickstart SC walkthrough.

Run on the iPad simulator via XcodeBuildMCP (scheme "Immich Slideshow").

### T014 — US1: persistence + UserDefaults secret boundary
1. Open the slideshow → reveal chrome → **"Broker einrichten"**.
2. Enter valid host / port (default 8883) / username / password and save.
3. Relaunch the app → the saved data is still present (with feature 005 the app now attempts a
   connection). *(SC-001, SC-004)*
4. Inspect the app's `UserDefaults` (keys `mqtt.brokerHost`, `mqtt.brokerPort`) → only **host/port** are
   stored there; **no username/password**. Credentials live in the Keychain only. *(SC-003)*

### T019 — quickstart SC mapping
Confirm SC-001…SC-006 from [specs/006-broker-setup/quickstart.md](../specs/006-broker-setup/quickstart.md)
on the simulator. The host-side criteria are already covered by `BrokerSetupKit` tests; this step is the
simulator-side confirmation (form validation hints, persistence, secret boundary). US2's change/remove UI
(SC-005/SC-006/FR-009) is already covered automatically by `BrokerSetupUITests`.
