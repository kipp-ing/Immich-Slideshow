# Tasks: Broker-Setup (MQTT-Verbindungsdaten einrichten)

**Input**: Design documents from `/specs/006-broker-setup/`

**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓

**Tests**: TDD verbindlich (Konstitution I) → Test-Tasks vor Implementierung, zuerst rot.

**Organization**: Nach User Stories gruppiert; jede Story unabhängig testbar.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: parallelisierbar (andere Datei). **[Story]**: US1/US2. Pfade relativ zum Repo-Root.

**Orchestrierung** (CLAUDE.md): Host-testbare Logik (`BrokerSetupKit`: Validierung, Provider-Bridge,
In-Memory-Fake) eignet sich zum Delegieren an Codex (`swift test`). **Inline bei Claude:** die reale
Keychain-/UserDefaults-Impl (`KeychainBrokerSettingsStore`), die SwiftUI-`BrokerSetupView` + Menü-
Einstieg, die App-Verdrahtung (Provider mit `identifierForVendor` an HAControl), `*.pbxproj`,
`.gitignore`-Allowlist (`!Packages/BrokerSetupKit/`) und alle Simulator-Verifikationen.

---

## Phase 1: Setup

- [ ] T001 SPM-Paket-Gerüst `Packages/BrokerSetupKit/Package.swift` (Swift 6, iOS 18 / macOS-Host; Target `BrokerSetupKit` mit Dependency `.package(path: "../HAControlKit")` + Produkt `HAControlKit`; Test-Target `BrokerSetupKitTests` mit Dependency `BrokerSetupKit`).
- [ ] T002 Quell-/Testverzeichnisse `Sources/BrokerSetupKit/`, `Tests/BrokerSetupKitTests/`.
- [ ] T003 Leeren Build verifizieren (`swift build`/`swift test` grün; HAControlKit aufgelöst). `.gitignore`-Allowlist `!Packages/BrokerSetupKit/` ergänzen (Claude).

**Checkpoint**: Paket baut, hängt an HAControlKit.

---

## Phase 2: Foundational

- [ ] T004 [P] Test-Fake `InMemoryBrokerSettingsStore` (hält `BrokerSettings?`; `save` validiert; `load`/`clear`) in `Packages/BrokerSetupKit/Tests/BrokerSetupKitTests/Fakes.swift`.

**Checkpoint**: Fake steht.

---

## Phase 3: User Story 1 - Broker-Verbindung einrichten (Priority: P1) 🎯 MVP

**Goal**: Eingaben validieren, persistieren (atomar), als `BrokerConfig` für 005 bereitstellen.

**Independent Test**: `save(gültig)` → `provider.load()` == vollständiges `BrokerConfig` (mit Geräte-ID);
ungültige Eingaben → kein Persistieren; Credentials im Keychain.

### Tests for User Story 1 (zuerst schreiben, MUSS rot sein) ⚠️

- [ ] T005 [P] [US1] Validierungs-Test in `Packages/BrokerSetupKit/Tests/BrokerSetupKitTests/BrokerSettingsTests.swift`: `validate()` → `.emptyHost` (leer/whitespace), `.invalidPort` (0 / 70000), `.emptyUsername`, `.emptyPassword`; gültige Settings → `nil`. `store.save(ungültig)` wirft und `load()==nil`; `save(gültig)`→`load()` Round-Trip; `clear()`→`nil`. (FR-002/FR-004)
- [ ] T006 [P] [US1] Provider-Test in `Packages/BrokerSetupKit/Tests/BrokerSetupKitTests/BrokerConfigProviderTests.swift`: bei vorhandenen Settings liefert `BrokerConfigProvider(settingsStore:, deviceID:"dev1").load()` ein `BrokerConfig` mit den Settings-Werten + `deviceID=="dev1"`; ohne Settings → `nil`. (FR-005/FR-010)

### Implementation for User Story 1

- [ ] T007 [US1] `BrokerSettings` + `BrokerValidationError` + `validate()` in `Packages/BrokerSetupKit/Sources/BrokerSetupKit/BrokerSettings.swift`. Test T005 (Validierungsteil) grün.
- [ ] T008 [US1] `BrokerSettingsStore`-Protokoll in `Packages/BrokerSetupKit/Sources/BrokerSetupKit/BrokerSettingsStore.swift`; `save` validiert vor Schreiben (atomar). (In-Memory-Fake erfüllt den Protokoll-Kontrakt; T005 Store-Teil grün.)
- [ ] T009 [US1] `BrokerConfigProvider: HAControlKit.BrokerConfigStore` in `Packages/BrokerSetupKit/Sources/BrokerSetupKit/BrokerConfigProvider.swift` (Settings + injizierte `deviceID` → `BrokerConfig?`). Test T006 grün.
- [ ] T010 [US1] Reale `KeychainBrokerSettingsStore` (host/port → UserDefaults; user/pass als JSON → Keychain, idempotent; `save` validiert; `clear` entfernt beide) in `Packages/BrokerSetupKit/Sources/BrokerSetupKit/BrokerSettingsStore.swift`. (Claude — Keychain/Secrets; Simulator-Verifikation.)
- [ ] T011 [US1] SwiftUI `BrokerSetupView` im App-Target: `Immich Slideshow/Slideshow/BrokerSetupView.swift` (Felder Host/Port/User/Pass mit SecureField; Port-Default 8883; Validierungs-Hinweise; Speichern). (Claude — UI/Simulator.)
- [ ] T012 [US1] Einstieg + Verdrahtung: Long-Press-Menü in `SlideshowView.swift` um „Broker einrichten" (Sheet `BrokerSetupView`) ergänzen; in `Immich_SlideshowApp.swift` `BrokerConfigProvider(settingsStore: KeychainBrokerSettingsStore(), deviceID: identifierForVendor)` bauen und an den HAControl-Coordinator (005) reichen. (Claude.)
- [ ] T013 [US1] `BrokerSetupKit` ins App-Target einbinden (`*.xcodeproj/project.pbxproj`). App baut auf dem iPad-Simulator. (Claude.)
- [ ] T014 [US1] Simulator-Verifikation: Setup öffnen, gültige Daten speichern, App neu starten → Daten vorhanden; UserDefaults enthält kein Passwort/Benutzername (nur host/port). (SC-001/SC-003/SC-004)

**Checkpoint**: US1 — Broker-Daten einrichten & für 005 bereitstellen (MVP).

---

## Phase 4: User Story 2 - Broker-Verbindung ändern/entfernen (Priority: P2)

**Goal**: Ändern (Passwort überschreiben), Entfernen (kein verwaistes Geheimnis), Passwort maskiert.

**Independent Test**: Ändern → neue Werte abrufbar; Entfernen → `load()==nil`, Keychain-Item weg.

### Tests for User Story 2 (zuerst schreiben, MUSS rot sein) ⚠️

- [ ] T015 [P] [US2] Test in `BrokerSettingsTests.swift`/`BrokerConfigProviderTests.swift`: erneutes `save` mit geändertem Passwort → `load()` liefert neue Werte (Round-Trip); `clear()` → `load()==nil` und `provider.load()==nil`. (FR-007/FR-008/SC-005/SC-006)

### Implementation for User Story 2

- [ ] T016 [US2] `BrokerSetupView` um „Entfernen" + Vorbefüllen bestehender Host/Port (Passwort maskiert, nicht im Klartext; Hinweis „gesetzt") erweitern; `KeychainBrokerSettingsStore.clear()` anbinden. (Claude — UI/Keychain.)
- [ ] T017 [US2] Simulator-Verifikation: Werte ändern → wirksam; Entfernen → keine Config; Passwort wird nie im Klartext vorbefüllt. (SC-005/SC-006/FR-009)

**Checkpoint**: Einrichten + Ändern/Entfernen vollständig.

---

## Phase 5: Polish & Cross-Cutting Concerns

- [ ] T018 [P] Sicherheitsreview (Konstitution III): username/password nur im Keychain; nichts in UserDefaults/Logs/Cache/committeten Dateien; Passwort nicht im Klartext in der UI vorbefüllt.
- [ ] T019 [P] `quickstart.md`-Validierung; SC-001…SC-006 bestätigen.
- [ ] T020 Voller Simulator-Lauf (`test_sim`, Scheme „Immich Slideshow"): app-gehostete Tests grün; Host-Suite (`BrokerSetupKit` + bestehende Pakete) grün via `swift test`.

---

## Dependencies & Execution Order

- Setup (P1) → Foundational (P2: T004) → US1 (P3) → US2 (P4) → Polish (P5).
- US1: Tests T005/T006 (rot) → Impl T007→T008→T009 (host-grün) → reale Persistenz T010 → UI T011 → Verdrahtung T012 → Linking T013 → Sim T014.
- US2: Test T015 (rot) → UI T016 → Sim T017. Baut auf US1.
- 006 hängt an 005 (HAControlKit-Protokolle); 005-Transport/-Wiring nutzt anschließend den 006-Provider.

### Parallel Opportunities

- T005/T006 [P] (verschiedene Testdateien). T018/T019 [P].

---

## Implementation Strategy

1. Setup → Foundational → US1 → **STOP & VALIDATE**: Broker-Daten speicherbar + als `BrokerConfig`
   abrufbar; Credentials im Keychain. 2. US2 (ändern/entfernen). 3. Polish.

Danach: zurück zu Feature 005 (NIOMQTTTransport + Wiring) — jetzt mit echtem `BrokerConfigProvider`
end-to-end gegen einen realen Broker verifizierbar.

## Notes

- Host-Logik ohne echten Keychain testbar (`InMemoryBrokerSettingsStore`); reale Keychain-/UserDefaults-
  Persistenz + Form auf dem Simulator.
- Keine Credentials in UserDefaults/Logs (Konstitution III); nie unvollständig persistieren (atomar).
- Verbindungsaufbau/MQTT/Discovery sind Feature 005; anonyme Broker/Self-signed/Auto-Discovery out of scope.
