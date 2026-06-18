# Tasks: Onboarding (Ersteinrichtung)

**Input**: Design documents from `/specs/002-onboarding/`

**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓

**Tests**: TDD ist laut Konstitution (Prinzip I, NON-NEGOTIABLE) verbindlich → Test-Tasks sind
enthalten und werden **vor** der Implementierung geschrieben und müssen zuerst **rot** sein.

**Organization**: Nach User Stories gruppiert; jede Story ist unabhängig testbar.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: parallelisierbar (andere Datei, keine offenen Abhängigkeiten)
- **[Story]**: zugehörige User Story (US1, US2, US3)
- Pfade relativ zum Repo-Root. Neues Paket unter `Packages/OnboardingKit/`; Views im App-Target.

**Orchestrierung** (CLAUDE.md): Host-testbare Logik (OnboardingKit, `serverVersion()`) eignet sich
zum Delegieren an Codex (`swift test`). SwiftUI-Views, `*.pbxproj`-Verdrahtung und alle
Simulator-Verifikationen macht Claude inline.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Lokales SPM-Paket `OnboardingKit` anlegen, baubar und host-testbar.

- [X] T001 SPM-Paket-Gerüst anlegen: `Packages/OnboardingKit/Package.swift` (Swift 6, Plattform iOS 18 / macOS-Host; Target `OnboardingKit` mit Dependency auf `ImmichClient`; Test-Target `OnboardingKitTests` mit Dependencies `OnboardingKit` + `ImmichClientTestSupport`).
- [X] T002 Quell- und Testverzeichnisse anlegen: `Packages/OnboardingKit/Sources/OnboardingKit/` und `Packages/OnboardingKit/Tests/OnboardingKitTests/`.
- [X] T003 Leeren Build verifizieren (Paket baut, leere Suite grün via `swift build`/`swift test` auf dem Host).

**Checkpoint**: Paket existiert und baut.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Geteilte Typen, Persistenz-Protokolle und Test-Fakes, die alle Stories brauchen.

**⚠️ CRITICAL**: Muss vor allen User Stories fertig sein.

- [X] T004 [P] `AppConfiguration` (baseURL: URL, selectedAlbumID: String; `Sendable`, `Equatable`) in `Packages/OnboardingKit/Sources/OnboardingKit/AppConfiguration.swift`.
- [X] T005 [P] `OnboardingStep` enum (`server`/`apiKey`/`album`/`done`; `Sendable`, `Equatable`) in `Packages/OnboardingKit/Sources/OnboardingKit/OnboardingStep.swift`.
- [X] T006 [P] `ConfigStore`-Protokoll (`load()`/`save(_:)`/`clear()`, `Sendable`) in `Packages/OnboardingKit/Sources/OnboardingKit/ConfigStore.swift`.
- [X] T007 [P] `KeychainStore`-Protokoll (`save(_:) throws`/`read()`/`delete()`, `Sendable`) in `Packages/OnboardingKit/Sources/OnboardingKit/KeychainStore.swift`.
- [X] T008 Test-Fakes `InMemoryConfigStore` und `InMemoryKeychainStore` (Letzterer mit optional erzwingbarem `save`-Fehler) in `Packages/OnboardingKit/Tests/OnboardingKitTests/Fakes.swift`.
- [X] T009 [P] Test (zuerst rot): `UserDefaultsConfigStore` persistiert/lädt/löscht baseURL + selectedAlbumID (eigene `UserDefaults`-Suite), in `Packages/OnboardingKit/Tests/OnboardingKitTests/ConfigStoreTests.swift`.
- [X] T010 `UserDefaultsConfigStore` implementieren in `Packages/OnboardingKit/Sources/OnboardingKit/ConfigStore.swift` bis T009 grün; `load()` liefert nur bei vollständiger Konfiguration eine `AppConfiguration`.

**Checkpoint**: Foundation steht — User Stories können beginnen.

---

## Phase 3: User Story 1 - Ersteinrichtung abschließen (Priority: P1) 🎯 MVP

**Goal**: Drei-Schritt-Fluss Server → Key → Album erzeugt eine gültige Konfiguration; Hauptscreen erscheint.

**Independent Test**: Mit gemockter `ImmichAPI` (MockTransport) und Fakes die drei Schritte
durchlaufen (gültige URL/Key/Album) → `step == done`, Config gespeichert, Key im (Fake-)Keychain.

### Tests for User Story 1 (zuerst schreiben, MUSS rot sein) ⚠️

- [X] T011 [P] [US1] Test: `serverVersion()`-Request geht an `GET /api/server/version` und liefert Versions-String; `URLError(.timedOut)` → `.unreachable`; non-2xx/undekodierbar → `.invalidResponse`. In `Packages/ImmichClient/Tests/ImmichClientTests/ServerVersionTests.swift`. (FR-004)
- [X] T012 [P] [US1] Test: `submitServerURL()` — ungültige/Nicht-HTTPS-URL → `errorMessage`, bleibt `server`; Erfolg → `step = apiKey`; `.unreachable` → Meldung, bleibt `server`. In `Packages/OnboardingKit/Tests/OnboardingKitTests/OnboardingViewModelTests.swift`. (FR-003/FR-004)
- [X] T013 [P] [US1] Test: `submitAPIKey()` — Erfolg validiert mit **einem** `albums()`-Aufruf, speichert Key via `KeychainStore`, übernimmt die geladene Albumliste und setzt `step = album`; `.unauthorized` → „Ungültiger API-Key", bleibt `apiKey`; Keychain-`save`-Fehler → Schritt nicht erfolgreich + Meldung. In `OnboardingViewModelTests.swift`. (FR-005/FR-006/FR-008)
- [X] T014 [P] [US1] Test: nach erfolgreicher Key-Validierung leere Albumliste → Hinweis, kein Fehler, keine Auswahl/`done` (FR-013); `selectAlbum(id:)` bei vorhandener Liste → `ConfigStore.save` mit nicht-leerer Album-ID und `step = done` (FR-009). Albumliste stammt aus dem `submitAPIKey()`-Aufruf (kein zweiter Abruf). In `OnboardingViewModelTests.swift`.

### Implementation for User Story 1

- [X] T015 [US1] `serverVersion()` zu `ImmichAPI` (`Packages/ImmichClient/Sources/ImmichClient/ImmichAPI.swift`) und Implementierung in `Packages/ImmichClient/Sources/ImmichClient/ImmichClient.swift` ergänzen (Route gegen laufende Immich-Instanz prüfen, Konstitution IV). Tests T011 grün; bestehende 14 bleiben grün.
- [X] T016 [US1] `OnboardingViewModel` (`@Observable`) in `Packages/OnboardingKit/Sources/OnboardingKit/OnboardingViewModel.swift`: Zustand + `submitServerURL()`/`submitAPIKey()`/`selectAlbum(id:)`, Fehler-Mapping aus `ImmichError`, `isBusy`-Sperre, injizierte `api`-Factory + Stores. `submitAPIKey()` übernimmt die bei der Validierung geladene Albumliste (kein zweiter Abruf). Tests T012–T014 grün.
- [X] T017 [US1] **Test zuerst (rot)**: realer `KeychainAPIKeyStore` `save`→`read`→`delete` Round-Trip in `Immich SlideshowTests/OnboardingKeychainTests.swift`. Vor der Implementierung (T018) geschrieben; Ausführung via `test_sim`, sobald das Paket verknüpft ist (T021). (Konstitution I, SC-005)
- [X] T018 [US1] Reale `KeychainAPIKeyStore`-Implementierung (Security, `kSecClassGenericPassword`, fester Service/Account) in `Packages/OnboardingKit/Sources/OnboardingKit/KeychainStore.swift` → macht T017 grün.
- [X] T019 [US1] SwiftUI-Schritt-Views im App-Target: `Immich Slideshow/Onboarding/OnboardingFlowView.swift`, `ServerStepView.swift`, `APIKeyStepView.swift`, `AlbumStepView.swift` (an `OnboardingViewModel` gebunden; schlicht/hell, Konstitution VII; API-Key-Feld als SecureField, kein Logging).
- [X] T020 [US1] App-Verdrahtung in `Immich Slideshow/Immich_SlideshowApp.swift`: bei nicht abgeschlossenem Onboarding `OnboardingFlowView` zeigen, sonst `ContentView` (Platzhalter). ViewModel mit realen Stores + `ImmichClient`-Factory instanziieren.
- [X] T021 [US1] `OnboardingKit` als lokale Paket-Abhängigkeit ins App-Target „Immich Slideshow" einbinden (`*.xcodeproj/project.pbxproj`: `XCSwiftPackageProductDependency` + Frameworks-Verknüpfung). App baut auf dem iPad-Simulator; danach T017 via `test_sim` grün (realer Keychain-Round-Trip). (SC-005)

**Checkpoint**: US1 unabhängig funktionsfähig — Ersteinrichtung führt bis zum Hauptscreen (MVP).

---

## Phase 4: User Story 2 - Einrichtung beim erneuten Start überspringen (Priority: P2)

**Goal**: Vorhandene vollständige Konfiguration überspringt das Onboarding; unvollständige startet beim ersten fehlenden Schritt.

**Independent Test**: `StartupGate` mit verschiedenen Store-Zuständen → korrekter `OnboardingStep`
(`done` nur bei URL + Album-ID + Key).

### Tests for User Story 2 (zuerst schreiben, MUSS rot sein) ⚠️

- [X] T022 [P] [US2] Test: `StartupGate.initialStep()` für alle Zeilen der Entscheidungstabelle (vollständig → `done`; Key fehlt → `apiKey`; Album-ID fehlt → `album`/`apiKey`; URL fehlt → `server`). In `Packages/OnboardingKit/Tests/OnboardingKitTests/StartupGateTests.swift`. (FR-001/FR-002/FR-011, SC-004)

### Implementation for User Story 2

- [X] T023 [US2] `StartupGate` (kombiniert `ConfigStore` + `KeychainStore`) in `Packages/OnboardingKit/Sources/OnboardingKit/StartupGate.swift`. Test T022 grün.
- [X] T024 [US2] App-Routing in `Immich Slideshow/Immich_SlideshowApp.swift` nutzt `StartupGate.initialStep()` beim Start, um Onboarding (ab erstem fehlenden Schritt) vs. Hauptscreen zu wählen.
- [X] T025 [US2] Simulator-Verifikation (XcodeBuildMCP): nach abgeschlossenem Onboarding App neu starten → direkt Hauptscreen (kein Schritt); unvollständiger Zustand → Onboarding. (SC-004)

**Checkpoint**: US1 + US2 — Erstsetup einmalig, danach direkter Einstieg.

---

## Phase 5: User Story 3 - Einstellungen zurücksetzen / neu einrichten (Priority: P3)

**Goal**: Reset entfernt Konfiguration + Key und startet das Onboarding neu.

**Independent Test**: `reset()` aufrufen → `ConfigStore` leer, `KeychainStore` ohne Key, `step == server`.

### Tests for User Story 3 (zuerst schreiben, MUSS rot sein) ⚠️

- [X] T026 [P] [US3] Test: `OnboardingViewModel.reset()` ruft `ConfigStore.clear()` + `KeychainStore.delete()`, leert Eingaben und setzt `step = server`. In `Packages/OnboardingKit/Tests/OnboardingKitTests/OnboardingViewModelTests.swift`. (FR-012, SC-006)

### Implementation for User Story 3

- [X] T027 [US3] `reset()` in `Packages/OnboardingKit/Sources/OnboardingKit/OnboardingViewModel.swift` implementieren. Test T026 grün.
- [X] T028 [US3] Reset-Einstieg im Hauptscreen-Platzhalter (`Immich Slideshow/ContentView.swift`) bzw. einer schlichten Settings-Aktion, die `reset()` auslöst und zurück ins Onboarding führt.
- [X] T029 [US3] Simulator-Verifikation (XcodeBuildMCP): Reset auslösen → Onboarding startet bei Schritt 1, zuvor gespeicherter Key ist via realem `KeychainAPIKeyStore` entfernt. (SC-006)

**Checkpoint**: Alle Stories funktionsfähig.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Endabsicherung, quickstart-Validierung, Sicherheitsreview.

- [ ] T030 [P] `quickstart.md`-Validierung durchspielen; Akzeptanz-Mapping SC-001…SC-006 bestätigen.
- [ ] T031 [P] Sicherheitsreview: API-Key erscheint nirgends in UserDefaults/Logs/committeten Dateien; `apiKeyInput` wird nie persistiert (Konstitution III). SecureField im UI.
- [ ] T032 Voller Simulator-Lauf über XcodeBuildMCP (`test_sim`, Scheme „Immich Slideshow"): app-gehostete Tests + Onboarding-Flow grün; Host-Suite (`OnboardingKit` + `ImmichClient`) grün.

---

## Dependencies & Execution Order

- **Setup (Phase 1)**: zuerst, ohne Abhängigkeit.
- **Foundational (Phase 2)**: nach Setup; blockiert alle Stories. T004–T007 [P] parallel; T008 nach T006/T007; T009 vor T010.
- **US1 (Phase 3)**: nach Foundational. MVP. Test-Tasks T011–T014 [P] zuerst (rot) → Impl T015–T016; Keychain test-first T017 → Impl T018 → UI/Wiring T019–T020 → Linking + Sim-Ausführung T021.
- **US2 (Phase 4)**: nach Foundational; nutzt Stores. Unabhängig von US1 testbar (StartupGate gegen Fakes), Routing-Verdrahtung baut auf T019 auf.
- **US3 (Phase 5)**: nach US1 (reset() ergänzt das ViewModel) und Foundational.
- **Polish (Phase 6)**: zuletzt.

### Within Each Story (TDD)

- Tests zuerst schreiben und **rot** sehen → minimale Implementierung → grün → Refactor.
- Modelle/Protokolle vor Logik; Logik vor UI; UI-Verifikation auf dem Simulator.

### Parallel Opportunities

- T004, T005, T006, T007 parallel (verschiedene Dateien).
- US1-Test-Tasks T011–T014 [P] parallel schreibbar (T011 in ImmichClientTests, T012–T014 in OnboardingViewModelTests — bei gemeinsamer Datei seriell committen).
- US2-Test T022 unabhängig von US1 schreibbar.

---

## Implementation Strategy

### MVP First (User Story 1)

1. Phase 1 Setup → 2. Phase 2 Foundational → 3. Phase 3 US1 → **STOP & VALIDATE**: Ersteinrichtung
   führt auf dem Simulator bis zum Hauptscreen, Key real im Keychain.

### Incremental Delivery

Setup+Foundational → US1 (MVP) → US2 (skip beim Neustart) → US3 (Reset) → Polish. Jede Story bricht
keine vorherige.

---

## Notes

- Jeder Task: roter Test zuerst (außer reine Setup-/UI-/Wiring-Tasks), dann minimale Implementierung,
  dann Refactor. Commit nach jedem Task oder logischer Gruppe.
- Host-Logik (OnboardingKit, `serverVersion()`) ohne Server/Keychain testbar (Fakes, MockTransport).
  Reale Keychain-Anbindung und UI-Fluss werden app-gehostet auf dem Simulator verifiziert.
- **⚠️ Vor/while T015**: `GET /api/server/version` gegen die laufende Immich-Instanz prüfen
  (`/api/openapi.json`) — nicht aus Tutorials übernehmen (Konstitution IV).
- Kein Logging des API-Keys (Konstitution III).
