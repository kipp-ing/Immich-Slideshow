# Implementation Plan: Onboarding (Ersteinrichtung)

**Branch**: `002-onboarding` | **Date**: 2026-06-18 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-onboarding/spec.md`

## Summary

Onboarding führt den Nutzer beim ersten Start in drei Schritten durch Server-URL → API-Key → Album
und erzeugt eine gültige App-Konfiguration. Technischer Ansatz: ein neues lokales SPM-Paket
`OnboardingKit` enthält die testbare Logik — Persistenz hinter `ConfigStore` (UserDefaults für
URL + Album-ID), Secret hinter `KeychainStore` (API-Key), ein `@Observable OnboardingViewModel`,
das den Schritt-Fluss und die Validierung über das bestehende `ImmichAPI`-Protokoll steuert, sowie
ein `StartupGate`, das beim Start Onboarding vs. Hauptscreen entscheidet. Die SwiftUI-Views und die
App-Verdrahtung liegen im App-Target „Immich Slideshow". Logik wird per Host-Tests (Swift Testing,
Mocks) abgesichert; UI-Fluss und die echte Keychain-Anbindung werden auf dem iPad-Simulator über
XcodeBuildMCP verifiziert. Die Server-Erreichbarkeit (Schritt 1, vor dem Key) nutzt einen
unauthentifizierten Versions-Endpunkt, der als kleine Erweiterung zu `ImmichClient` ergänzt wird.

## Technical Context

**Language/Version**: Swift 6

**Primary Dependencies**: SwiftUI, Observation (`@Observable`), Foundation, Security (Keychain);
intern das bestehende Paket `ImmichClient`. Keine Drittbibliotheken.

**Storage**: UserDefaults für Server-URL und gewählte Album-ID (nicht-geheim); iOS-Keychain für den
API-Key (Konstitution III). Beides hinter Protokollen (`ConfigStore`, `KeychainStore`).

**Testing**: Swift Testing (`@Test`). Logik des Pakets als Host-Tests (`swift test`, Fakes);
UI-Fluss + reale Keychain-Anbindung als app-gehostete Tests auf dem iPad-Simulator über
XcodeBuildMCP (`test_sim`).

**Target Platform**: iPadOS 18+ (SwiftUI). Paketlogik plattformneutral (iOS + macOS-Host) testbar,
außer der realen Keychain-Impl (iOS/Simulator).

**Project Type**: Mobile-App-Feature — lokales SPM-Paket `OnboardingKit` + Views/Wiring im App-Target.

**Performance Goals**: Nicht latenzkritisch. Reaktive UI; Netzaufrufe (Version, albums()) asynchron
mit sichtbarem Lade-/Fehlerzustand. Erstsetup-Ziel < 2 Min (SC-001).

**Constraints**: Keine TLS-Ausnahme (Konstitution IV). API-Key nie in UserDefaults/Logs/Klartext
(Konstitution III). Keine versteckten Singletons; alle Abhängigkeiten injiziert (Konstitution II).
Unvollständiges Setup gibt den Hauptscreen nicht frei (FR-011).

**Scale/Scope**: Ein Server, ein Nutzer, ein gewähltes Album. ~4 SwiftUI-Schritt-Views + Routing.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Prinzip | Bewertung | Status |
|---------|-----------|--------|
| I. Test-First (NON-NEGOTIABLE) | Tasks strikt TDD: roter Test (ViewModel/Stores/Reachability) vor Implementierung; UI-Verifikation auf dem Simulator. | ✅ |
| II. Modulare Isolation | `ConfigStore`, `KeychainStore`, `ImmichAPI` als Protokolle; `OnboardingViewModel` bekommt sie injiziert; keine Singletons. | ✅ |
| III. Keine Secrets im Klartext (NON-NEGOTIABLE) | API-Key ausschließlich über `KeychainStore`; nie UserDefaults/Logs; Reset löscht den Key. | ✅ |
| IV. Sicherheit der Transportschicht | Standard-URLSession über HTTPS via `ImmichClient`; keine TLS-Ausnahme; nur HTTPS-URLs akzeptiert. | ✅ |
| V. Plattformgrenzen respektieren | Kein Display-/Idle-/Helligkeitsbezug in diesem Feature. | ✅ (n/a) |
| VI. Verifizierbare Akzeptanzkriterien | Spec liefert messbare SC-001…SC-006; quickstart.md mappt sie auf Tests. | ✅ |
| VII. Schlicht und hell als Default | Onboarding schlicht, hell, ohne Schnickschnack; Standard-SwiftUI-Formulare. | ✅ |

**Ergebnis: PASS — keine Verletzungen, keine Komplexitäts-Ausnahmen nötig.**

## Project Structure

### Documentation (this feature)

```text
specs/002-onboarding/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (ConfigStore / KeychainStore / ViewModel / Reachability)
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
Packages/
├── ImmichClient/                       # bestehend; kleine Erweiterung:
│   └── Sources/ImmichClient/
│       └── ImmichClient.swift          # + serverVersion() (unauth. Erreichbarkeit, Schritt 1)
│       └── ImmichAPI.swift             # + serverVersion() im Protokoll
└── OnboardingKit/                      # NEU
    ├── Package.swift                   # Swift 6, iOS 18 + macOS-Host; depends ImmichClient
    ├── Sources/OnboardingKit/
    │   ├── AppConfiguration.swift      # baseURL + selectedAlbumID (Wertmodell)
    │   ├── ConfigStore.swift           # Protokoll + UserDefaultsConfigStore
    │   ├── KeychainStore.swift         # Protokoll + KeychainAPIKeyStore (Security)
    │   ├── OnboardingStep.swift        # enum: server / apiKey / album / done
    │   ├── OnboardingViewModel.swift   # @Observable; Schrittfluss + Validierung + Fehler-Mapping
    │   └── StartupGate.swift           # entscheidet onboarding vs. main beim Start
    └── Tests/OnboardingKitTests/
        ├── Fakes.swift                 # InMemoryConfigStore, InMemoryKeychainStore (+ MockTransport aus ImmichClientTestSupport)
        ├── StartupGateTests.swift      # US2/US3: skip / unvollständig / reset
        ├── ConfigStoreTests.swift      # Persistenz URL + Album-ID
        ├── KeychainStoreContractTests.swift # gegen das Protokoll (Fake); reale Impl auf Sim
        └── OnboardingViewModelTests.swift   # US1 happy path + Fehlerzweige (401/timeout/leer)

Immich Slideshow/                       # App-Target
├── Immich_SlideshowApp.swift           # Root-Routing: StartupGate → Onboarding oder Platzhalter
├── ContentView.swift                   # bleibt vorerst Platzhalter-Hauptscreen
└── Onboarding/                         # SwiftUI-Views (auf dem Simulator verifiziert)
    ├── OnboardingFlowView.swift        # Container, schaltet Schritt-Views
    ├── ServerStepView.swift            # Schritt 1
    ├── APIKeyStepView.swift            # Schritt 2
    └── AlbumStepView.swift             # Schritt 3

Immich SlideshowTests/                  # app-gehostete Tests (Simulator)
└── OnboardingFlowTests.swift           # reale KeychainAPIKeyStore-Anbindung + Gate end-to-end
```

**Structure Decision**: Testbare Logik in `Packages/OnboardingKit` (Foundation/Observation, schnell
host-testbar, „Modulare Isolation"); SwiftUI-Views im App-Target, weil sie zur Verifikation den
Simulator brauchen (CLAUDE.md). Das App-Target bindet `OnboardingKit` (und transitiv `ImmichClient`)
ein. Die reale Keychain-Implementierung wird app-gehostet auf dem Simulator getestet; die Logik
gegen Fakes auf dem Host. Begründung gegen Default-`src/`: Swift/SPM-Konventionen und bestehende
Projektstruktur (wie `ImmichClient`).

## Complexity Tracking

> Keine Constitution-Verletzungen — Abschnitt leer.
