# Implementation Plan: Broker-Setup (MQTT-Verbindungsdaten einrichten)

**Branch**: `006-broker-setup` | **Date**: 2026-06-19 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/006-broker-setup/spec.md`

## Summary

Ein kleiner Einrichtungs-Schnitt, der die MQTT-Broker-Verbindungsdaten (Host, Port, Benutzername,
Passwort) entgegennimmt, validiert und persistiert — Credentials im Keychain, Host/Port als
nicht-geheime Einstellung — und sie der Fernsteuerung (Feature 005) über das bestehende
`BrokerConfigStore`-Protokoll bereitstellt. Erst damit ist der HAControl-Pfad „scharf".

Technischer Ansatz: ein neues lokales SPM-Paket `BrokerSetupKit` mit host-testbarer Logik:
- `BrokerSettings` (Wertmodell) + Validierung (Host nicht leer, Port 1–65535, User/Pass nicht leer).
- `BrokerSettingsStore` (Protokoll) zum Speichern/Laden/Löschen der Eingaben; reale Impl splittet
  Host/Port → UserDefaults und Benutzername/Passwort → Keychain (atomar, idempotentes Überschreiben).
- `BrokerConfigProvider` konformiert das in **HAControlKit (005)** definierte `BrokerConfigStore`-
  Protokoll: liefert ein vollständiges `BrokerConfig` (inkl. **injizierter** stabiler Geräte-ID) oder
  `nil`, wenn keine vollständige Konfiguration vorliegt. So bleibt `BrokerSetupKit` die einzige Stelle,
  die Eingabe-Persistenz und 005-Bereitstellung verbindet.

Die reale Keychain-/UserDefaults-Persistenz und die SwiftUI-Eingabemaske liegen im App-Target und
werden auf dem Simulator verifiziert (Keychain braucht den Simulator, analog zu OnboardingKit). Die
stabile Geräte-ID (`identifierForVendor`) wird im App-Target erzeugt und in den `BrokerConfigProvider`
injiziert. Logik per Host-Tests (Swift Testing, In-Memory-Fake-Store); Persistenz/Form auf dem
Simulator.

## Technical Context

**Language/Version**: Swift 6

**Primary Dependencies**: SwiftUI/Observation/Foundation; Security (Keychain) in der realen Store-Impl;
intern `HAControlKit` (005) für `BrokerConfig`/`BrokerConfigStore`. Keine Drittbibliotheken.

**Storage**: Host/Port (nicht geheim) in UserDefaults; Benutzername/Passwort im **Keychain**
(Konstitution III). Kein weiterer persistenter Speicher.

**Testing**: Swift Testing (`@Test`). Validierung + `BrokerConfigProvider`-Bridge als Host-Tests
(`swift test`) mit In-Memory-Fake-`BrokerSettingsStore` und injizierter Geräte-ID. Reale Keychain-/
UserDefaults-Persistenz + Eingabemaske app-gehostet auf dem iPad-Simulator (XcodeBuildMCP).

**Target Platform**: iPadOS 18+. `BrokerSetupKit`-Logik host-testbar; Keychain-Persistenz/Form nur
App-Target/Simulator.

**Project Type**: Mobile-App-Feature — lokales SPM-Paket `BrokerSetupKit` + reale Persistenz und
SwiftUI-Setup-View im App-Target.

**Performance Goals**: Nicht latenzkritisch (einmalige Einrichtung). Keine Dauerlast.

**Constraints**: Credentials nie in UserDefaults/Logs/Cache/committeten Dateien (Konstitution III).
Keine versteckten Singletons — `BrokerSettingsStore` und Geräte-ID injiziert (Konstitution II). Nie
unvollständig persistieren (atomar). Ruhiger Default bleibt — das Setup ist eine unaufdringliche
Einstellungsmöglichkeit (Konstitution VII). TLS-Entscheidungen liegen bei 005 (hier nicht berührt,
Konstitution IV).

**Scale/Scope**: Ein Broker, ein Gerät. Ein Wertmodell + Validierung + Store + Provider; reale
Persistenz (~1 Datei) + eine SwiftUI-Form + Menü-Einstieg.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Prinzip | Bewertung | Status |
|---------|-----------|--------|
| I. Test-First (NON-NEGOTIABLE) | TDD: rote Tests für Validierung (gültig/ungültig je Feld) und `BrokerConfigProvider` (vollständig→`BrokerConfig`, unvollständig→`nil`, Geräte-ID gesetzt) **vor** Implementierung; Keychain-Persistenz auf dem Simulator. | ✅ |
| II. Modulare Isolation | `BrokerSettingsStore` + Geräte-ID injiziert; Logik ohne echten Keychain testbar (In-Memory-Fake). | ✅ |
| III. Keine Secrets im Klartext (NON-NEGOTIABLE) | Benutzername/Passwort nur im Keychain; nie in UserDefaults/Logs/Cache/committeten Dateien. Form maskiert das Passwort, drängt es nicht im Klartext auf (FR-009). | ✅ |
| IV. Sicherheit der Transportschicht | Nicht berührt (kein Verbindungsaufbau hier; TLS in 005). | ✅ (n/a) |
| V. Plattformgrenzen respektieren | Nicht betroffen (reine Einrichtung). | ✅ (n/a) |
| VI. Verifizierbare Akzeptanzkriterien | Spec liefert messbare SC-001…SC-006; quickstart.md mappt sie auf Host-/Sim-Tests. | ✅ |
| VII. Schlicht und hell als Default | Setup ist eine unaufdringliche Einstellungsmöglichkeit; kein Aufdrängen, kein Bruch des ruhigen Defaults. | ✅ |

**Ergebnis: PASS — keine Verletzungen, keine Komplexitäts-Ausnahmen nötig.**

## Project Structure

### Documentation (this feature)

```text
specs/006-broker-setup/
├── plan.md  research.md  data-model.md  quickstart.md  contracts/  tasks.md
```

### Source Code (repository root)

```text
Packages/
├── … bestehend …
└── BrokerSetupKit/                       # NEU
    ├── Package.swift                      # Swift 6; dep: HAControlKit (für BrokerConfig/BrokerConfigStore)
    ├── Sources/BrokerSetupKit/
    │   ├── BrokerSettings.swift           # Wertmodell + Validierung (host/port/user/pass)
    │   ├── BrokerSettingsStore.swift      # Protokoll + reale UserDefaults+Keychain-Impl (atomar)
    │   └── BrokerConfigProvider.swift     # konformiert HAControlKit.BrokerConfigStore (load()->BrokerConfig?)
    └── Tests/BrokerSetupKitTests/
        ├── Fakes.swift                    # InMemoryBrokerSettingsStore
        ├── BrokerSettingsTests.swift      # Validierung gültig/ungültig je Feld
        └── BrokerConfigProviderTests.swift# vollständig->BrokerConfig (mit Geräte-ID); unvollständig->nil

Immich Slideshow/                          # App-Target
├── Immich_SlideshowApp.swift              # BrokerConfigProvider (mit identifierForVendor) an HAControl(005) reichen
└── Slideshow/
    ├── BrokerSetupView.swift              # SwiftUI-Form: host/port/user/pass, speichern/entfernen, Passwort maskiert
    └── (Einstieg) über das bestehende Long-Press-Menü in SlideshowView (neben Reset)
```

**Structure Decision**: Host-testbare Logik (Validierung, Provider-Bridge) in `Packages/BrokerSetupKit`
— analog zu den bestehenden Paketen. Die reale Keychain-/UserDefaults-Persistenz liegt in der Paket-
Impl, wird aber (wie OnboardingKits Keychain) app-gehostet auf dem Simulator verifiziert; die
host-testbaren Tests nutzen einen In-Memory-Fake. Die stabile Geräte-ID kommt aus dem App-Target
(`identifierForVendor`) und wird injiziert, damit das Paket UIKit-frei bleibt. `BrokerSetupKit` hängt
an `HAControlKit` (005), um dessen `BrokerConfigStore` zu konformieren — saubere Schichtung
(006 liefert, 005 konsumiert).

## Complexity Tracking

> Keine Constitution-Verletzungen — Abschnitt leer.
