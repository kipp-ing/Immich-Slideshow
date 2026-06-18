# Implementation Plan: ImmichClient — Datenanbindung

**Branch**: `001-immich-client` | **Date**: 2026-06-17 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-immich-client/spec.md`

## Summary

ImmichClient ist die reine Datenanbindung an einen Immich-Server: Albumliste abrufen, Assets eines
Albums abrufen, Vorschaubild eines Assets laden — jeweils authentifiziert per `x-api-key`-Header
über HTTPS. Technischer Ansatz: ein Swift-6-Modul als lokales SPM-Paket, dessen Logik hinter einem
`ImmichAPI`-Protokoll liegt und einen injizierten `HTTPTransport` nutzt. Tests laufen gegen einen
Mock-Transport ohne echten Server (TDD, Swift Testing).

## Technical Context

**Language/Version**: Swift 6

**Primary Dependencies**: Foundation (URLSession). Keine Drittbibliotheken.

**Storage**: N/A (API-Key wird von außen übergeben; Persistenz/Keychain ist Sache des Onboarding-Features)

**Testing**: Swift Testing (`@Test`), ausgeführt über XcodeBuildMCP

**Target Platform**: iPadOS 18+ (Modul selbst Foundation-only, plattformunabhängig testbar)

**Project Type**: Mobile-App-Modul (lokales SPM-Paket, später vom App-Target konsumiert)

**Performance Goals**: Nicht latenzkritisch in diesem Feature; Vorschaubilder statt Originale halten
Transfer klein. Konkrete Timing-Ziele gehören zur SlideshowView (späteres Feature).

**Constraints**: Keine TLS-Ausnahme (gültiges Zertifikat vorausgesetzt). Kein Logging von API-Key.
Gesamte Logik ohne echten Server testbar.

**Scale/Scope**: Ein Server, ein Nutzer, Alben/Assets in üblicher Privatnutzer-Größenordnung.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Prinzip | Bewertung | Status |
|---------|-----------|--------|
| I. Test-First (NON-NEGOTIABLE) | Tasks sind strikt TDD-geordnet: roter Test vor Implementierung. | ✅ |
| II. Modulare Isolation | `ImmichAPI`-Protokoll + injizierter `HTTPTransport`; keine Singletons. | ✅ |
| III. Keine Secrets im Klartext (NON-NEGOTIABLE) | API-Key nur übergeben, nie geloggt/persistiert hier. | ✅ |
| IV. Sicherheit der Transportschicht | Standard-URLSession über HTTPS, keine TLS-Ausnahme. | ✅ |
| V. Plattformgrenzen respektieren | Kein Display-/Idle-/Helligkeits-Bezug in diesem Feature. | ✅ (n/a) |
| VI. Verifizierbare Akzeptanzkriterien | Spec liefert messbare SC-001…SC-006. | ✅ |
| VII. Schlicht und hell als Default | Keine UI in diesem Feature. | ✅ (n/a) |

**Ergebnis: PASS — keine Verletzungen, keine Komplexitäts-Ausnahmen nötig.**

## Project Structure

### Documentation (this feature)

```text
specs/001-immich-client/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (ImmichAPI- & HTTPTransport-Protokollverträge)
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
Packages/
└── ImmichClient/
    ├── Package.swift
    ├── Sources/ImmichClient/
    │   ├── ServerConfig.swift       # Basis-URL + API-Key
    │   ├── Models.swift             # Album, Asset
    │   ├── ImmichError.swift        # unauthorized / unreachable / invalidResponse
    │   ├── HTTPTransport.swift      # Transport-Protokoll (für Mocking) + URLSession-Impl
    │   ├── ImmichAPI.swift          # Protokoll: albums(), assets(albumID:), preview(assetID:)
    │   └── ImmichClient.swift       # Live-Impl: baut Requests, setzt x-api-key, parst, mappt Fehler
    └── Tests/ImmichClientTests/
        ├── MockTransport.swift      # zeichnet Requests auf, liefert feste Antworten
        ├── AlbumTests.swift         # Story 1
        ├── AssetTests.swift         # Story 2
        ├── PreviewTests.swift       # Story 3
        └── ErrorTests.swift         # 401 / Timeout / leeres Album / ungültige JSON
```

**Structure Decision**: Lokales Swift Package `Packages/ImmichClient`, Foundation-only und damit
isoliert und schnell testbar — entspricht „Modulare Isolation". Das App-Target („Immich Slideshow")
bindet das Paket als lokale Abhängigkeit ein (separater Task, sobald ein UI-Konsument existiert).
Tests werden über XcodeBuildMCP ausgeführt. Begründung gegen die Default-`src/`-Single-Project-
Struktur: Swift/SPM-Konventionen und die bestehende Xcode-Projektstruktur.

## Complexity Tracking

> Keine Constitution-Verletzungen — Abschnitt leer.
