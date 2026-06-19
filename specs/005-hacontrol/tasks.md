# Tasks: HAControl (Fernsteuerung über MQTT/Home Assistant)

**Input**: Design documents from `/specs/005-hacontrol/`

**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓

**Tests**: TDD ist laut Konstitution (Prinzip I, NON-NEGOTIABLE) verbindlich → Test-Tasks sind
enthalten und werden **vor** der Implementierung geschrieben und müssen zuerst **rot** sein.

**Organization**: Nach User Stories gruppiert; jede Story ist unabhängig testbar.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: parallelisierbar (andere Datei, keine offenen Abhängigkeiten)
- **[Story]**: zugehörige User Story (US1, US2, US3)
- Pfade relativ zum Repo-Root. Neues Paket unter `Packages/HAControlKit/`; Transport-Wrapper + Verdrahtung im App-Target.

**Orchestrierung** (CLAUDE.md): Host-testbare Kern-Logik (`HAControlKit`: Coordinator, Discovery,
Topics, Wertmodelle) eignet sich zum Delegieren an Codex (`swift test`). **Inline bei Claude:** das
AsyncStream-/Concurrency-Test-Design (eingehende Commands, connection events, Reconnect), die reale
`NIOMQTTTransport`-Impl (mqtt-nio + TLS), der Keychain-`BrokerConfigStore`, der `RemoteControlling`-
Adapter, App-Entry/Lebenszyklus, `*.pbxproj`-Verdrahtung, `.gitignore`-Allowlist (`!Packages/HAControlKit/`),
das Sicherheits-/Secret-Review und die manuelle Broker-Verifikation.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Lokales SPM-Paket `HAControlKit` (Kern dependency-frei) + Target `HAControlMQTT` (mqtt-nio) anlegen.

- [ ] T001 SPM-Paket-Gerüst `Packages/HAControlKit/Package.swift` (Swift 6, iOS 18 / macOS-Host): Target `HAControlKit` (keine externen Deps); Target `HAControlMQTT` (Dependency `mqtt-nio` via `.package(url: "https://github.com/swift-server/mqtt-nio", from: "2.x")` + `HAControlKit`); Test-Target `HAControlKitTests` (Dependency `HAControlKit`). Zwei Library-Products (`HAControlKit`, `HAControlMQTT`).
- [ ] T002 Quell-/Testverzeichnisse anlegen: `Sources/HAControlKit/`, `Sources/HAControlMQTT/`, `Tests/HAControlKitTests/`.
- [ ] T003 Leeren Build verifizieren (`swift build`/`swift test` auf dem Host grün; mqtt-nio wird aufgelöst). `.gitignore`-Allowlist `!Packages/HAControlKit/` ergänzen (Claude — `Packages/*` ist ignoriert).

**Checkpoint**: Paket existiert, baut, mqtt-nio aufgelöst.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Geteilte Protokolle, Wertmodelle, Topics und Test-Fakes für alle Stories.

**⚠️ CRITICAL**: Muss vor allen User Stories fertig sein.

- [ ] T004 [P] Wertmodelle in `Packages/HAControlKit/Sources/HAControlKit/HAEntityState.swift`: `HAEntity` (`enum {playback,brightness,album}`, `CaseIterable`, `Sendable`), `PlaybackState` (`playing`/`paused`), `ConnectionState` (`disconnected`/`connecting`/`connected`); alle `Equatable`, `Sendable`.
- [ ] T005 [P] `MQTTTransport`-Protokoll + `MQTTMessage` (`topic`/`payload: Data`/`retain`) in `Packages/HAControlKit/Sources/HAControlKit/MQTTTransport.swift` (`connect(will:)`/`disconnect()`/`publish(_:)`/`subscribe(_:)`/`incoming: AsyncStream`/`connectionEvents: AsyncStream<Bool>`; `Sendable`).
- [ ] T006 [P] `RemoteControlling`-Protokoll (`@MainActor`, `AnyObject`; `playbackState`/`brightness`/`albumOptions`/`currentAlbum`; `pause()`/`resume()`/`setBrightness(_:) async`/`selectAlbum(_:)`; `onLocalChange`) in `Packages/HAControlKit/Sources/HAControlKit/RemoteControlling.swift`.
- [ ] T007 [P] `BrokerConfigStore`-Protokoll + `BrokerConfig` (`host`/`port`/`username`/`password`/`deviceID`; `Sendable`, `Equatable`) in `Packages/HAControlKit/Sources/HAControlKit/BrokerConfigStore.swift`.
- [ ] T008 [P] `HATopics` (reine Topic-Builder: base/availability/command/state/discoveryConfig je `HAEntity`) in `Packages/HAControlKit/Sources/HAControlKit/HATopics.swift`.
- [ ] T009 Test-Fakes in `Packages/HAControlKit/Tests/HAControlKitTests/Fakes.swift`: `FakeMQTTTransport` (zeichnet `connect(will:)`/`published: [MQTTMessage]`/`subscriptions: [String]` auf; `inject(_:)` speist eingehende Commands über `incoming`; `emitConnection(_:)` über `connectionEvents`) und `FakeRemoteControl` (`@MainActor`; konfigurierbare Zustände/Albumliste; zeichnet Aufrufe auf).

**Checkpoint**: Foundation steht — User Stories können beginnen.

---

## Phase 3: User Story 1 - Pause/Play + Verfügbarkeit (Priority: P1) 🎯 MVP

**Goal**: TLS-Verbindung, HA-Discovery für einen Schalter, Verfügbarkeit (LWT online/offline),
Fern-Pause/Play mit Zustands-Echo, Reconnect, robuste Nutzlasten.

**Independent Test**: Mit `FakeMQTTTransport`+`FakeRemoteControl`: `start()` → connect(will: offline),
availability online, Discovery für `switch`, `switch/set` abonniert; `switch/set OFF`→pause + Echo OFF;
`onLocalChange`→Echo; connection false→true→online+Discovery+Echo; ungültige Payload→kein Crash.

### Tests for User Story 1 (zuerst schreiben, MUSS rot sein) ⚠️

- [ ] T010 [P] [US1] Discovery-/Topic-Test in `Packages/HAControlKit/Tests/HAControlKitTests/HADiscoveryTests.swift`: `HADiscovery.config(for: .playback, …)` enthält `unique_id == "<deviceID>_playback"`, korrekte `availability_topic`/`command_topic`/`state_topic` (deckungsgleich mit `HATopics`), `device.identifiers == [deviceID]`, kein Credential im Payload; Topics stabil über mehrere Aufrufe (SC-005). (FR-006/FR-007/SC-005)
- [ ] T011 [US1] Coordinator-Test in `Packages/HAControlKit/Tests/HAControlKitTests/HAControlCoordinatorTests.swift`: `start()` mit gültiger Config → `connect(will:)` mit availability=`offline`-Will, danach availability=`online` (retained), Discovery für `switch` (retained), `switch/set` abonniert, State-Echo `playbackState` (FR-001/FR-004/FR-006/FR-007/SC-001); eingehend `switch/set OFF`→`control.pause()`+Echo `OFF`, `ON`→`resume()`+Echo `ON` (FR-008/FR-009/SC-002); `control.onLocalChange()`→Echo (SC-003); ungültige/leere Payload→kein Crash, kein Zustandswechsel, Echo=unverändert (FR-011); `connectionEvents` false→true→erneut online+Discovery+Echo (FR-005/SC-004/SC-005); `start()` ohne Config (`nil`)→kein `connect`, `connection==.disconnected`, kein Throw (FR-003/SC-006); `stop()`→`disconnect()`. **Concurrency-/AsyncStream-Testdesign bei Claude.**

### Implementation for User Story 1

- [ ] T012 [US1] `HADiscovery` (reine Payload-Builder, JSON `Data` für `switch`/`light`/`select` + availability/device-Block) in `Packages/HAControlKit/Sources/HAControlKit/HADiscovery.swift`. Test T010 grün.
- [ ] T013 [US1] `HAControlCoordinator` (`@MainActor @Observable`) in `Packages/HAControlKit/Sources/HAControlKit/HAControlCoordinator.swift`: `init(transport, control, configStore, deviceName, enabledEntities=[.playback])`; `start()` (Config laden; bei nil no-op; sonst connect(will), online, Discovery je Entität, subscribe, State-Echo; `incoming`/`connectionEvents` konsumieren), Command→`pause()`/`resume()`, State-Echo nach Command **und** `onLocalChange`, Reconnect-Handling, robuste Payload-Verarbeitung; `stop()` (disconnect). Test T011 grün.
- [ ] T014 [US1] Reale `NIOMQTTTransport: MQTTTransport` in `Packages/HAControlKit/Sources/HAControlMQTT/NIOMQTTTransport.swift` über `mqtt-nio` mit **TLS** (Validierung aktiv), LWT, Keepalive, Reconnect; bildet `incoming`/`connectionEvents` auf AsyncStreams ab. (Claude — Lib/TLS/Concurrency.)
- [ ] T015 [US1] Keychain-`BrokerConfigStore` im App-Target: `Immich Slideshow/Slideshow/KeychainBrokerConfigStore.swift` (Broker-Host/Port/User/Pass + deviceID aus dem bestehenden Keychain; nie loggen). (Claude — Keychain/Secrets.)
- [ ] T016 [US1] `RemoteControlling`-Adapter im App-Target: `Immich Slideshow/Slideshow/SlideshowRemoteControlAdapter.swift` (leitet pause/resume auf `SlideshowViewModel`; `onLocalChange` bei lokalen Pausen/Resumes; brightness/album als no-op bis US2/US3). (Claude.)
- [ ] T017 [US1] `HAControlKit` (+ `HAControlMQTT`) ins App-Target einbinden (`*.xcodeproj/project.pbxproj`: `XCLocalSwiftPackageReference` + zwei `XCSwiftPackageProductDependency` + Frameworks). App baut auf dem iPad-Simulator. (Claude.)
- [ ] T018 [US1] Lebenszyklus-Verdrahtung in `Immich_SlideshowApp.swift`/`SlideshowView.swift`: `HAControlCoordinator` mit `NIOMQTTTransport` + `KeychainBrokerConfigStore` + Adapter bauen; beim Erscheinen `start()`, beim Verlassen/Hintergrund `stop()`. Diashow bleibt bei fehlendem Broker unbeeinflusst (FR-003). **`--uitest`/DEBUG:** Coordinator mit Fake-Transport/ohne Config, damit der hermetische Lauf kein Netz braucht. (Claude.)
- [ ] T019 [US1] Manuelle Broker-Verifikation (out of CI): gültige Broker-Daten im Keychain → Diashow starten → in HA erscheint Gerät mit Pause/Play-Schalter + Verfügbarkeit; Schalten pausiert/läuft; App in den Hintergrund → „offline" (LWT), zurück → „online". TLS-Port, kein Klartext. (Claude.)

**Checkpoint**: US1 unabhängig funktionsfähig — Fernsteuerung Pause/Play + Verfügbarkeit (MVP).

---

## Phase 4: User Story 2 - Helligkeit aus HA setzen (Priority: P2)

**Goal**: Dimmbares Licht per Discovery; Helligkeitsbefehl → PowerManager (geklemmt, foreground-gated) + Echo.

**Independent Test**: Mit Fakes: `light/set <wert>` → `control.setBrightness(clamp)`, State-Echo=angewandter Wert.

### Tests for User Story 2 (zuerst schreiben, MUSS rot sein) ⚠️

- [ ] T020 [P] [US2] Test in `HAControlCoordinatorTests.swift` (+ Discovery-Test in `HADiscoveryTests.swift`): mit `.brightness` aktiviert → Discovery für `light` (unique_id `<deviceID>_brightness`); eingehend `light/set` → `control.setBrightness(clamp 0…1)`; Helligkeit 0–255↔0.0–1.0-Mapping; State-Echo = angewandter Wert; außerhalb Bereich → geklemmt (FR-012/FR-013/SC-008).

### Implementation for User Story 2

- [ ] T021 [US2] Coordinator + `HADiscovery` um `light` erweitern (`Packages/HAControlKit/Sources/HAControlKit/HAControlCoordinator.swift`, `HADiscovery.swift`): Command-Mapping `light/set`→`setBrightness`, 0–255↔0.0–1.0, State-Echo. Test T020 grün.
- [ ] T022 [US2] App-Adapter `SlideshowRemoteControlAdapter` um Helligkeit erweitern (an `PowerManager.setBrightness`); `.brightness` in `enabledEntities` aufnehmen. (Claude.)
- [ ] T023 [US2] Manuelle Broker-Verifikation: HA zeigt dimmbares Licht; Fern-Helligkeit wirkt auf dem iPad und wird zurückgemeldet; Hintergrund erzwingt nichts.

**Checkpoint**: US1 + US2 — Pause/Play + Helligkeit fern.

---

## Phase 5: User Story 3 - Album aus HA wechseln (Priority: P3)

**Goal**: Auswahl (Albumliste) per Discovery; Auswahlbefehl → Albumwechsel + Echo; ungültig → unverändert.

**Independent Test**: Mit Fakes: `select/set <gültig>` → `selectAlbum` + Echo neue Auswahl; `<ungültig>` → no-op + Echo unverändert.

### Tests for User Story 3 (zuerst schreiben, MUSS rot sein) ⚠️

- [ ] T024 [P] [US3] Test in `HAControlCoordinatorTests.swift` (+ Discovery): mit `.album` aktiviert → Discovery für `select` mit `options == albumOptions` (unique_id `<deviceID>_album`); `select/set <gültig>`→`control.selectAlbum`+Echo; `<ungültig/unbekannt>`→no-op, Echo=aktueller Zustand (FR-014/FR-015/SC-009).

### Implementation for User Story 3

- [ ] T025 [US3] Coordinator + `HADiscovery` um `select` erweitern (Optionen=Albumliste); Command-Mapping `select/set`→`selectAlbum` (unbekannt→no-op), State-Echo. Test T024 grün.
- [ ] T026 [US3] App-Adapter um Albumliste/-wechsel erweitern (an `SlideshowViewModel`/Album-Quelle); `.album` in `enabledEntities`. (Claude.)
- [ ] T027 [US3] Manuelle Broker-Verifikation: HA zeigt Album-Auswahl mit Optionen; Fernwahl wechselt das Album und meldet zurück; ungültige Wahl lässt den Zustand unverändert.

**Checkpoint**: Alle Stories funktionsfähig.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Sicherheits-/Secret-Review, Plattformgrenzen, quickstart-Validierung.

- [ ] T028 [P] Sicherheitsreview (Konstitution III/IV): Broker-`password`/`username` erscheinen nirgends in publizierten Payloads/Topics, Logs, UserDefaults, Cache oder committeten Dateien; TLS-Validierung in `NIOMQTTTransport` nicht deaktiviert (kein `allowInsecure`/Self-signed-Bypass).
- [ ] T029 [P] `quickstart.md`-Validierung; Akzeptanz-Mapping SC-001…SC-009 bestätigen (Host-Tests + manuelle Broker-Checks).
- [ ] T030 Voller Simulator-Lauf über XcodeBuildMCP (`test_sim`, Scheme „Immich Slideshow"): app-gehostete Tests grün (Coordinator-Verdrahtung bricht den Flow nicht; `--uitest` ohne Netz); Host-Suite (`HAControlKit` + bestehende Pakete) grün via `swift test`.

---

## Dependencies & Execution Order

- **Setup (Phase 1)**: zuerst. T001→T002→T003.
- **Foundational (Phase 2)**: nach Setup; blockiert alle Stories. T004–T008 [P] parallel; T009 nach T005/T006.
- **US1 (Phase 3)**: nach Foundational. MVP. Tests T010/T011 (rot) → Impl T012→T013 → realer Transport T014 → Keychain T015 → Adapter T016 → Linking T017 → Verdrahtung T018 → manuelle Verifikation T019.
- **US2 (Phase 4)**: nach US1 (erweitert Coordinator/Discovery/Adapter). Test T020 (rot) → T021 → T022 → T023. Nutzt PowerManager (004).
- **US3 (Phase 5)**: nach US1 (erweitert Coordinator/Discovery/Adapter). Test T024 (rot) → T025 → T026 → T027. Nutzt Slideshow-Albumquelle (003/001). Unabhängig von US2.
- **Polish (Phase 6)**: zuletzt.

### Within Each Story (TDD)

- Tests zuerst schreiben und **rot** sehen → minimale Implementierung → grün → Refactor.
- Wertmodelle/Protokolle/Topics vor Coordinator; Coordinator (Kern) vor realem Transport/Adapter/Verdrahtung.

### Parallel Opportunities

- T004–T008 [P] (verschiedene Dateien). T010 [P] (eigene Testdatei) parallel zu T011-Vorbereitung;
  T011/T020/T024 teilen `HAControlCoordinatorTests.swift` → seriell committen.
- Polish T028/T029 [P] parallel.

---

## Implementation Strategy

### MVP First (User Story 1)

1. Phase 1 Setup → 2. Phase 2 Foundational → 3. Phase 3 US1 → **STOP & VALIDATE**: HA zeigt Pause/Play
   + Verfügbarkeit; Fernschalten wirkt; LWT/Reconnect funktionieren.

### Incremental Delivery

Setup+Foundational → US1 (MVP: Pause/Play + Verfügbarkeit) → US2 (Helligkeit) → US3 (Album) → Polish.
Jede Story bricht keine vorherige.

---

## Notes

- Jeder Task: roter Test zuerst (außer reine Setup-/Transport-/Wiring-Tasks), dann minimale Impl, dann
  Refactor. Commit nach jedem Task oder logischer Gruppe.
- Kern-Logik (`HAControlKit`) ohne echten Broker testbar (`FakeMQTTTransport`, `FakeRemoteControl`).
  Realer TLS-Transport (`mqtt-nio`) + HA-Sichtbarkeit werden manuell gegen einen realen Broker geprüft.
- Keine Broker-Credentials in Logs/Payloads/Topics (Konstitution III); TLS nie deaktivieren
  (Konstitution IV). MQTT-Lib ist eine dokumentierte, isolierte Dependency-Ausnahme (siehe plan.md).
- Onboarding-UI für Broker-Daten, Cloud ohne Broker, Mehr-Geräte, HA-Automationen sind **out of scope**.
