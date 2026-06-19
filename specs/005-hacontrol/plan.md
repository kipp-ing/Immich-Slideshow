# Implementation Plan: HAControl (Fernsteuerung über MQTT/Home Assistant)

**Branch**: `005-hacontrol` | **Date**: 2026-06-19 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/005-hacontrol/spec.md`

## Summary

Die App verbindet sich während der Diashow als MQTT-Client über TLS mit dem vorhandenen Broker,
meldet sich per Home-Assistant-MQTT-Discovery als Gerät an, veröffentlicht Verfügbarkeit über ein
Last-Will-and-Testament und stellt fernsteuerbare Entitäten bereit: Pause/Play (Schalter, P1),
Helligkeit (Licht, P2), Album (Auswahl, P3) — jeweils mit Zustands-Rückmeldung, sodass HA den echten
App-Zustand spiegelt.

Technischer Ansatz: ein neues lokales SPM-Paket `HAControlKit` mit **host-testbarer** Logik hinter
injizierten Nähten:
- `MQTTTransport` (Protokoll) kapselt Verbinden/Publizieren/Abonnieren/Will/Verbindungszustand —
  damit ist die HA-Logik ohne echten Broker deterministisch testbar (Konstitution II).
- `RemoteControlling` (Protokoll) ist die Steuerfläche der App (pause/resume, setBrightness,
  selectAlbum, aktuelle Zustände) — so hängt `HAControlKit` **nicht** direkt an `SlideshowKit`/
  `PowerKit`; das App-Target verdrahtet die echten Objekte.
- `BrokerConfigStore` (Protokoll) liefert die Broker-Daten aus dem Keychain (Konstitution III).
- `HAControlCoordinator` (`@MainActor @Observable`) orchestriert: verbinden → Discovery publizieren →
  Command-Topics abonnieren → eingehende Befehle auf `RemoteControlling` abbilden → Zustand/
  Verfügbarkeit zurückmelden; robust gegen ungültige Nutzlasten und Verbindungsabbrüche (LWT +
  Reconnect).
- Reine Funktionen für Discovery-Payloads (`HADiscovery`) und Topic-Struktur (`HATopics`) — stabil,
  eindeutig, host-testbar.

Der konkrete MQTT-Client kommt aus der SPM-Bibliothek **`mqtt-nio`** (TLS über NIO) in einem **eigenen,
dünnen** Paket-Target `HAControlMQTT` (`NIOMQTTTransport: MQTTTransport`). So bleibt das Kern-Target
`HAControlKit` abhängigkeitsfrei und schnell host-testbar; nur das App-Target zieht den realen
Transport. Das App-Target stellt zudem den Keychain-`BrokerConfigStore` und verdrahtet
`RemoteControlling` an das laufende `SlideshowViewModel` + `PowerManager`. Logik per Host-Tests (Swift
Testing, Fake-`MQTTTransport` + Fake-`RemoteControlling`); echte TLS-Verbindung/HA-Sichtbarkeit
optional manuell gegen einen echten Broker (out of CI).

## Technical Context

**Language/Version**: Swift 6

**Primary Dependencies**: SwiftUI/Observation/Foundation für Verdrahtung; **neue SPM-Abhängigkeit
`mqtt-nio`** (`swift-server/mqtt-nio`) ausschließlich für die Transportschicht (TLS über
SwiftNIO/NIOSSL bzw. NIOTransportServices). Intern: bestehende Pakete `SlideshowKit` (Pause/Resume,
Albumliste/-wechsel) und `PowerKit` (Helligkeit) — angebunden **nur** über das `RemoteControlling`-
Protokoll im App-Target, nicht als Paket-Abhängigkeit von `HAControlKit`.

**Storage**: Kein neuer persistenter Speicher. Broker-Host/Port/Credentials liegen im **Keychain**
(über `BrokerConfigStore`); die Eingabe-/Onboarding-UI dafür ist out of scope. Flüchtiger
Verbindungs-/Entitätszustand im Coordinator.

**Testing**: Swift Testing (`@Test`). Kern-Logik (`HAControlKit`) als Host-Tests (`swift test`):
Fake-`MQTTTransport` zeichnet publizierte Topics/Payloads auf und speist eingehende Befehle ein;
Fake-`RemoteControlling` zeichnet aufgerufene Aktionen auf. Discovery-Payloads/Topics werden als reine
Funktionen geprüft. Echte TLS-Verbindung und HA-Discovery-Sichtbarkeit werden manuell gegen einen
realen Broker verifiziert (nicht im CI; `mqtt-nio`-Wrapper ohne Unit-Netz-Test).

**Target Platform**: iPadOS 18+ (SwiftUI). `HAControlKit`-Kern plattformneutral (iOS + macOS-Host)
testbar; `HAControlMQTT` (mqtt-nio) ebenfalls host-lauffähig, im CI aber nicht gegen echten Broker
getestet.

**Project Type**: Mobile-App-Feature — lokales SPM-Paket `HAControlKit` (+ Target `HAControlMQTT`) und
Verdrahtung (Keychain-Store, `RemoteControlling`-Adapter, Lebenszyklus) im App-Target.

**Performance Goals**: Fernbefehle wirken zeitnah (gefühlt sofort, < ~1 s im LAN). Zustands-
Rückmeldung folgt jeder Änderung. Keine Dauerlast außer der MQTT-Keepalive-Verbindung; Reconnect mit
Backoff.

**Constraints**: TLS-Validierung NICHT deaktivieren (Konstitution IV) — `mqtt-nio` mit TLS. Broker-
Credentials nie in Logs/UserDefaults/Cache/committeten Dateien (Konstitution III); nur injiziert aus
dem Keychain. Keine versteckten Singletons — `MQTTTransport`, `RemoteControlling`, `BrokerConfigStore`
injiziert (Konstitution II). Helligkeit (P2) bleibt foreground-gated über den PowerManager
(Konstitution V). Fehlender/abgebrochener Broker darf die Diashow nie blockieren (FR-003). Ruhiger
Default unverändert — Fernsteuerung ist UI-unsichtbar (Konstitution VII).

**Scale/Scope**: Ein Gerät, ein Broker, eine HA-Instanz. Drei Entitäten (Schalter/Licht/Auswahl) +
Verfügbarkeit. Ein Coordinator + Nähte + Discovery/Topics; reale Transport-Impl (~1 Wrapper) und
App-Verdrahtung.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Prinzip | Bewertung | Status |
|---------|-----------|--------|
| I. Test-First (NON-NEGOTIABLE) | TDD: rote Tests für Discovery-Payloads/Topics, Command→Aktion-Mapping, Zustands-Rückmeldung, Verfügbarkeit/Reconnect und robuste Nutzlast-Verarbeitung — alle über Fake-`MQTTTransport`/Fake-`RemoteControlling`, **vor** Implementierung. | ✅ |
| II. Modulare Isolation | `MQTTTransport`, `RemoteControlling`, `BrokerConfigStore` als injizierte Protokolle; Kern-Target ohne externe/Slideshow-/Power-Abhängigkeit; realer Transport isoliert in `HAControlMQTT`. | ✅ |
| III. Keine Secrets im Klartext (NON-NEGOTIABLE) | Broker-Credentials nur aus dem Keychain über `BrokerConfigStore`; erscheinen nie in Logs/UserDefaults/Cache. Coordinator/Discovery loggen keine Credentials. | ✅ |
| IV. Sicherheit der Transportschicht | `mqtt-nio` mit TLS; Validierung bleibt aktiv; keine Self-signed-/Klartext-Ausnahme (out of scope). | ✅ |
| V. Plattformgrenzen respektieren | Helligkeit über den PowerManager (nur Vordergrund); Hintergrund/Verbindungsverlust → LWT „offline" (korrektes Verhalten, kein Erzwingen). | ✅ |
| VI. Verifizierbare Akzeptanzkriterien | Spec liefert messbare SC-001…SC-009; quickstart.md mappt sie auf Host-Tests (+ manuelle Broker-Verifikation). | ✅ |
| VII. Schlicht und hell als Default | Keine UI-Änderung; Fernsteuerung unsichtbar, drängt nichts auf. | ✅ |

**Dokumentierte Abweichung (keine Konstitution-Verletzung):** Die Projekt-*Konvention* „keine
Drittbibliotheken" (bislang in Feature-Plänen) wird hier **bewusst** für die MQTT-Transportschicht
durchbrochen (`mqtt-nio`). Die Konstitution selbst verbietet Drittbibliotheken nicht; das bindende
Verbot ist „keine Abhängigkeit zur offiziellen Immich-Codebasis" (eingehalten). Begründung in
Complexity Tracking.

**Ergebnis: PASS — keine Verletzungen; eine begründete, isolierte Dependency-Ausnahme.**

## Project Structure

### Documentation (this feature)

```text
specs/005-hacontrol/
├── plan.md              # This file
├── research.md          # Phase 0 (MQTT-Lib-Wahl, TLS, HA-Discovery-Konvention, LWT, Reconnect, Nähte)
├── data-model.md        # Phase 1 (Entitäten + Zustände/Topics)
├── quickstart.md        # Phase 1 (SC-Mapping auf Tests)
├── contracts/           # Phase 1 (MQTTTransport / RemoteControlling / BrokerConfigStore / Coordinator)
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
Packages/
├── ImmichClient/ OnboardingKit/ SlideshowKit/ PowerKit/   # bestehend; unverändert
└── HAControlKit/                                           # NEU
    ├── Package.swift                # Swift 6; Target HAControlKit (keine ext. Deps);
    │                                #   Target HAControlMQTT (dep: mqtt-nio + HAControlKit);
    │                                #   Test-Target HAControlKitTests (dep: HAControlKit)
    ├── Sources/HAControlKit/        # KERN (abhängigkeitsfrei, host-testbar)
    │   ├── MQTTTransport.swift      # Protokoll: connect/publish/subscribe/will/Verbindungszustand
    │   ├── RemoteControlling.swift  # Protokoll: pause/resume, setBrightness, selectAlbum, Zustände
    │   ├── BrokerConfigStore.swift  # Protokoll + BrokerConfig (host/port/user/pass) aus Keychain
    │   ├── HATopics.swift           # Topic-Struktur (deviceID-basiert, stabile unique IDs)
    │   ├── HADiscovery.swift        # reine Discovery-Payload-Builder (switch/light/select + availability)
    │   ├── HAEntityState.swift      # Wertmodelle (Pause/Play, Brightness, Album-Auswahl)
    │   └── HAControlCoordinator.swift # @MainActor @Observable; Orchestrierung P1→P3
    ├── Sources/HAControlMQTT/       # REALER TRANSPORT (zieht mqtt-nio)
    │   └── NIOMQTTTransport.swift   # MQTTTransport über mqtt-nio mit TLS + LWT + Reconnect
    └── Tests/HAControlKitTests/
        ├── Fakes.swift             # FakeMQTTTransport (zeichnet Publishes auf, speist Commands ein), FakeRemoteControl
        ├── HADiscoveryTests.swift  # Payload-/Topic-Form, stabile unique IDs (SC-005)
        └── HAControlCoordinatorTests.swift # connect/discovery/availability, command→action, state-echo, reconnect, robust payloads

Immich Slideshow/                    # App-Target
├── Immich_SlideshowApp.swift        # HAControlCoordinator bauen: NIOMQTTTransport + Keychain-Store + RemoteControl-Adapter; Lebenszyklus
└── Slideshow/
    ├── KeychainBrokerConfigStore.swift  # NEU: BrokerConfigStore über den bestehenden Keychain
    └── SlideshowRemoteControlAdapter.swift # NEU: RemoteControlling → SlideshowViewModel + PowerManager
```

**Structure Decision**: Kern-Logik in `Packages/HAControlKit` (abhängigkeitsfrei, schnell host-testbar,
„Modulare Isolation") — analog zu den bestehenden Paketen. Der reale MQTT-Transport liegt isoliert im
Ziel-Target `HAControlMQTT`, damit nur dort die `mqtt-nio`-Abhängigkeit anfällt und der Kern (samt
Tests) sauber und schnell bleibt. Die Anbindung an Slideshow/Power erfolgt über `RemoteControlling`
im App-Target (kein Paket-Kreuz-Bezug). Der Keychain-Zugriff für Broker-Daten ist hinter
`BrokerConfigStore` injiziert. Begründung gegen Default-`src/`: Swift/SPM-Konventionen und bestehende
Projektstruktur.

## Complexity Tracking

| Violation / Abweichung | Why Needed | Simpler Alternative Rejected Because |
|------------------------|------------|--------------------------------------|
| Neue Drittbibliothek `mqtt-nio` (bricht die bisherige „pure Foundation"-Konvention) | MQTT 3.1.1/5 über TLS samt Keepalive, LWT, Reconnect und Paket-Framing von Hand auf `Network.framework` nachzubauen ist umfangreich, fehleranfällig und sicherheitskritisch (TLS). Eine erprobte Bibliothek (TLS über NIOSSL) minimiert Risiko und Zeit. | Hand-Roll auf `Network.framework` verworfen: hoher Aufwand, hohe Fehler-/Sicherheitsrisiken; kein Mehrwert gegenüber einer etablierten Lib. Die Konstitution verbietet Drittbibliotheken nicht; Isolation im eigenen Target hält den Kern dependency-frei. |
