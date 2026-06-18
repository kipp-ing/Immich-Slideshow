# Tasks: ImmichClient — Datenanbindung

**Input**: Design documents from `/specs/001-immich-client/`

**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓

**Tests**: TDD ist laut Konstitution (Prinzip I, NON-NEGOTIABLE) verbindlich → Test-Tasks sind
enthalten und werden **vor** der Implementierung geschrieben und müssen zuerst **rot** sein.

**Organization**: Nach User Stories gruppiert; jede Story ist unabhängig testbar.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: parallelisierbar (andere Datei, keine offenen Abhängigkeiten)
- **[Story]**: zugehörige User Story (US1, US2, US3)
- Pfade relativ zum Repo-Root. Modul liegt unter `Packages/ImmichClient/`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Lokales SPM-Paket anlegen, baubar und testbar über XcodeBuildMCP.

- [ ] T001 SPM-Paket-Gerüst anlegen: `Packages/ImmichClient/Package.swift` (Swift 6, Plattform iOS 18 / macOS-Host für Tests, Targets `ImmichClient` + `ImmichClientTests` mit Swift Testing).
- [ ] T002 Quell- und Testverzeichnisse anlegen: `Packages/ImmichClient/Sources/ImmichClient/` und `Packages/ImmichClient/Tests/ImmichClientTests/`.
- [ ] T003 Leeren Build über XcodeBuildMCP verifizieren (Paket baut, leere Testsuite läuft grün).

**Checkpoint**: Paket existiert und baut.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Typen und Test-Transport, die alle Stories brauchen.

**⚠️ CRITICAL**: Muss vor allen User Stories fertig sein.

- [ ] T004 [P] `ServerConfig` (baseURL: URL, apiKey: String, `Sendable`) in `Packages/ImmichClient/Sources/ImmichClient/ServerConfig.swift`.
- [ ] T005 [P] `ImmichError` enum (`.unauthorized`, `.unreachable`, `.invalidResponse`; `Error`, `Equatable`) in `Packages/ImmichClient/Sources/ImmichClient/ImmichError.swift`.
- [ ] T006 [P] `HTTPTransport`-Protokoll (`data(for:) async throws -> (Data, URLResponse)`, `Sendable`) + `URLSessionTransport`-Live-Impl in `Packages/ImmichClient/Sources/ImmichClient/HTTPTransport.swift`.
- [ ] T007 `MockTransport` (zeichnet `URLRequest`s auf; liefert konfigurierbare `(Data, URLResponse)` oder wirft konfigurierten Error) in `Packages/ImmichClient/Tests/ImmichClientTests/MockTransport.swift`.
- [ ] T008 Skelett `ImmichClient: ImmichAPI` mit nicht-implementierten Methoden (werfen vorerst), Konstruktor `init(config:transport:)` in `Packages/ImmichClient/Sources/ImmichClient/ImmichClient.swift` und `ImmichAPI`-Protokoll in `Packages/ImmichClient/Sources/ImmichClient/ImmichAPI.swift`.

**Checkpoint**: Foundation steht — User Stories können beginnen.

---

## Phase 3: User Story 1 - Alben abrufen (Priority: P1) 🎯 MVP

**Goal**: `albums()` liefert die Alben des Nutzers; jeder Request trägt `x-api-key`.

**Independent Test**: MockTransport mit gültiger Album-JSON → `[Album]` mit `id`/`name`; aufgezeichneter Request trägt `x-api-key`.

### Tests for User Story 1 (zuerst schreiben, MUSS rot sein) ⚠️

- [ ] T009 [P] [US1] Test: gültige Album-JSON → `[Album]` verlustfrei (`albumName`→`name`), in `Packages/ImmichClient/Tests/ImmichClientTests/AlbumTests.swift`. (SC-002)
- [ ] T010 [P] [US1] Test: `albums()`-Request geht an `GET /api/albums` und trägt Header `x-api-key` (über MockTransport-Aufzeichnung), in `Packages/ImmichClient/Tests/ImmichClientTests/AlbumTests.swift`. (SC-001, INV-1)

### Implementation for User Story 1

- [ ] T011 [US1] `Album`-Modell (`id`, `name`, `Codable`, `Sendable`, `CodingKeys` `albumName`→`name`) in `Packages/ImmichClient/Sources/ImmichClient/Models.swift`.
- [ ] T012 [US1] `albums()` in `ImmichClient.swift`: Request bauen (baseURL + `/api/albums`, `x-api-key`), via Transport laden, 2xx→JSON dekodieren. Tests T009/T010 grün.
- [ ] T013 [US1] Refactor: gemeinsame Request-Bauhilfe (Pfad anhängen, `x-api-key` setzen) extrahieren; Tests bleiben grün.

**Checkpoint**: US1 unabhängig funktionsfähig (MVP).

---

## Phase 4: User Story 2 - Album-Assets abrufen (Priority: P1)

**Goal**: `assets(albumID:)` liefert die Bild-Assets; leeres Album → `[]`.

**Independent Test**: MockTransport mit Album-Detail-JSON → `[Asset]`; leeres `assets`-Array → `[]` ohne Fehler.

### Tests for User Story 2 (zuerst schreiben, MUSS rot sein) ⚠️

- [ ] T014 [P] [US2] Test: Album-Detail-JSON mit `assets` → `[Asset]` (id/type), Request an `GET /api/albums/{id}`, in `Packages/ImmichClient/Tests/ImmichClientTests/AssetTests.swift`. (FR-004)
- [ ] T015 [P] [US2] Test: leeres Album (`assets: []`) → `[]`, kein Fehler, in `AssetTests.swift`. (SC-005, INV-5)

### Implementation for User Story 2

- [ ] T016 [US2] `Asset`-Modell (`id`, `type`, `Codable`, `Sendable`) + Album-Detail-Decodier-Hülle in `Packages/ImmichClient/Sources/ImmichClient/Models.swift`.
- [ ] T017 [US2] `assets(albumID:)` in `ImmichClient.swift`: `GET /api/albums/{albumID}`, `assets` extrahieren, leeres Array korrekt. Tests T014/T015 grün.

**Checkpoint**: US1 + US2 unabhängig funktionsfähig.

---

## Phase 5: User Story 3 - Vorschaubild laden (Priority: P2)

**Goal**: `preview(assetID:)` liefert herunterskalierte Bilddaten (nicht das Original).

**Independent Test**: MockTransport mit Bilddaten für eine Asset-ID → diese `Data`; Request an `…/thumbnail?size=preview`.

### Tests for User Story 3 (zuerst schreiben, MUSS rot sein) ⚠️

- [ ] T018 [P] [US3] Test: `preview(assetID:)`-Request an `GET /api/assets/{id}/thumbnail?size=preview` mit `x-api-key`, Antwort-`Data` wird durchgereicht, in `Packages/ImmichClient/Tests/ImmichClientTests/PreviewTests.swift`. (FR-005)

### Implementation for User Story 3

- [ ] T019 [US3] `preview(assetID:)` in `ImmichClient.swift`: Thumbnail-Request mit `size=preview` bauen, `Data` zurückgeben. Test T018 grün.

**Checkpoint**: Alle Stories funktionsfähig.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Fehler-Mapping (storyübergreifend), Endabsicherung.

- [ ] T020 [P] Test: 401-Response → `ImmichError.unauthorized` in `Packages/ImmichClient/Tests/ImmichClientTests/ErrorTests.swift`. (SC-003, INV-3) — zuerst rot.
- [ ] T021 [P] Test: `URLError(.timedOut)` aus Transport → `ImmichError.unreachable` in `ErrorTests.swift`. (SC-004, INV-4) — zuerst rot.
- [ ] T022 [P] Test: non-2xx (≠401) / undekodierbare JSON → `ImmichError.invalidResponse` in `ErrorTests.swift`. (INV-6) — zuerst rot.
- [ ] T023 Zentrales Fehler-Mapping in `ImmichClient.swift` (HTTP-Status & gefangene `URLError` → `ImmichError`) für alle drei Methoden; Tests T020–T022 grün. Sicherstellen: API-Key wird nie geloggt. (Konstitution III)
- [ ] T024 Refactor + `quickstart.md`-Validierung: gesamte Suite grün über XcodeBuildMCP; SC-001…SC-006 abgedeckt.
- [ ] T025 App-Target „Immich Slideshow" bindet das lokale Paket `Packages/ImmichClient` als Abhängigkeit ein (nur Verknüpfung, kein UI). Build der App grün.

---

## Dependencies & Execution Order

- **Setup (Phase 1)**: ohne Abhängigkeit, zuerst.
- **Foundational (Phase 2)**: nach Setup; blockiert alle Stories. T004/T005/T006 [P] parallel; T007 nach T006; T008 nach T004–T006.
- **US1 (Phase 3)**: nach Foundational. MVP.
- **US2 (Phase 4)**: nach Foundational; unabhängig von US1 (teilt nur Request-Hilfe aus T013 — sonst eigenständig).
- **US3 (Phase 5)**: nach Foundational; unabhängig.
- **Polish (Phase 6)**: Fehler-Tests können nach T008 geschrieben werden; T023 nach den Story-Methoden; T025 zuletzt.

### Within Each Story (TDD)

- Tests zuerst schreiben und **rot** sehen → minimale Implementierung → grün → Refactor.
- Modelle vor Methoden; eine Story komplett vor der nächsten Priorität.

### Parallel Opportunities

- T004, T005, T006 parallel (verschiedene Dateien).
- Test-Tasks je Story mit [P] parallel schreibbar.
- Nach Foundational können US1/US2/US3 parallel bearbeitet werden (verschiedene Testdateien).

---

## Implementation Strategy

### MVP First (User Story 1)

1. Phase 1 Setup → 2. Phase 2 Foundational → 3. Phase 3 US1 → 4. **STOP & VALIDATE** `albums()` gegen Mock → optional Integrationstest gegen echte Instanz.

### Incremental Delivery

Setup+Foundational → US1 (MVP) → US2 → US3 → Polish/Fehler-Mapping. Jede Story bricht keine vorherige.

---

## Notes

- Jeder Task: roter Test zuerst (außer reine Setup-/Refactor-Tasks), dann minimale Implementierung, dann Refactor. Commit nach jedem Task oder logischer Gruppe.
- Tests laufen über XcodeBuildMCP, ohne echten Server (MockTransport).
- **⚠️ Vor/while T012/T017/T019**: API-Pfade gegen die laufende Immich-Instanz prüfen (`/api/server/version`, `/api/openapi.json`) — siehe research.md, Konstitution IV.
- Kein Logging des API-Keys (Konstitution III).
