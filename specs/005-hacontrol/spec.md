# Feature Specification: HAControl (Fernsteuerung über MQTT/Home Assistant)

**Feature Branch**: `005-hacontrol`

**Created**: 2026-06-19

**Status**: Draft

**Input**: User description: "HAControl: Fernsteuerung der Slideshow-App über MQTT von Home Assistant aus … MVP: TLS-Verbindung + Verfügbarkeit + Pause/Play-Schalter; später Helligkeit (light) und Album (select). MQTT-Transport hinter injizierbarem Protokoll; konkreter Client aus SPM-Bibliothek (bewusste Ausnahme); TLS nicht deaktivieren. Out of scope: Cloud ohne lokalen Broker, Mehr-Geräte, HA-Automationen, Broker-Onboarding-UI."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Pause/Play aus Home Assistant + Verfügbarkeit (Priority: P1) 🎯 MVP

Die App verbindet sich beim Start der Diashow über eine gesicherte Verbindung mit dem vorhandenen
MQTT-Broker und erscheint in Home Assistant automatisch als ein Gerät mit einem Pause/Play-Schalter
sowie einer Online-/Offline-Anzeige. Schaltet der Nutzer den Schalter in Home Assistant, pausiert bzw.
startet die laufende Diashow auf dem iPad. Ändert sich der Zustand in der App (oder durch HA), spiegelt
Home Assistant immer den echten Zustand. Bricht die Verbindung ab, zeigt Home Assistant das Gerät als
offline.

**Why this priority**: Ist der kleinste durchgängige Schnitt, der die gesamte Kette beweist —
gesicherte Verbindung, Credentials aus sicherer Ablage, HA-Discovery, Verfügbarkeit (LWT) und eine
echte, rückgemeldete Steuerung. Ohne ihn gibt es keine Fernsteuerung.

**Independent Test**: Mit einem Test-Doppel des MQTT-Transports (kein echter Broker): Diashow starten →
es werden eine Discovery-Konfiguration für einen Schalter und eine „online"-Verfügbarkeit
veröffentlicht; ein eingehender Schaltbefehl „pause"/„play" pausiert/startet die Diashow und führt zu
einer rückgemeldeten Zustandsnachricht; ein simulierter Verbindungsabbruch führt zur „offline"-
Verfügbarkeit (LWT).

**Acceptance Scenarios**:

1. **Given** gültige Broker-Daten liegen in der sicheren Ablage, **When** die Diashow startet, **Then**
   verbindet sich die App gesichert, veröffentlicht eine HA-Discovery-Konfiguration für einen
   Pause/Play-Schalter und meldet sich als „online".
2. **Given** die App ist verbunden und die Diashow läuft, **When** in Home Assistant „pause" geschaltet
   wird, **Then** pausiert die Diashow und die App meldet den Zustand „pausiert" zurück.
3. **Given** die Diashow ist pausiert, **When** in Home Assistant „play" geschaltet wird, **Then** läuft
   die Diashow weiter und die App meldet „läuft" zurück.
4. **Given** der Nutzer pausiert die Diashow lokal in der App, **When** sich der Zustand ändert, **Then**
   spiegelt Home Assistant den neuen Zustand (Rückmeldung, kein Auseinanderlaufen).
5. **Given** die App ist verbunden, **When** die Verbindung unerwartet abbricht, **Then** zeigt Home
   Assistant das Gerät über das Last-Will-and-Testament als „offline".
6. **Given** die App war offline/getrennt, **When** sie sich (wieder) verbindet, **Then** wird erneut
   „online" gemeldet und die Discovery-Konfiguration ist (weiterhin) vorhanden.

---

### User Story 2 - Helligkeit aus Home Assistant setzen (Priority: P2)

Home Assistant zeigt die App zusätzlich als dimmbares Licht. Der Nutzer kann die Bildschirmhelligkeit
des iPads fern setzen; die App wendet den Wert über den bestehenden PowerManager an und meldet den
aktuellen Helligkeitswert zurück.

**Why this priority**: Erweitert die Fernsteuerung um den zweithäufigsten Wunsch (nachts dimmen), baut
direkt auf P1 (Verbindung/Discovery) und dem vorhandenen PowerManager auf, ist aber nicht nötig, damit
Fernsteuerung überhaupt funktioniert.

**Independent Test**: Mit Test-Transport: Diashow starten → Discovery für ein „light" wird
veröffentlicht; ein eingehender Helligkeitsbefehl führt dazu, dass die App die Helligkeit (über den
PowerManager) auf den geklemmten Zielwert setzt und den Wert zurückmeldet.

**Acceptance Scenarios**:

1. **Given** die App ist verbunden, **When** die Diashow startet, **Then** wird eine HA-Discovery-
   Konfiguration für ein dimmbares Licht veröffentlicht.
2. **Given** das Licht ist in HA sichtbar, **When** ein Helligkeitswert gesetzt wird, **Then** setzt die
   App die Bildschirmhelligkeit auf den entsprechenden (geklemmten) Wert und meldet ihn zurück.
3. **Given** ein Helligkeitsbefehl außerhalb des gültigen Bereichs trifft ein, **When** er angewendet
   wird, **Then** wird der Wert auf den gültigen Bereich begrenzt (kein Fehler).
4. **Given** die App ist im Hintergrund, **When** ein Helligkeitsbefehl eintrifft, **Then** wird die
   Helligkeit nicht im Hintergrund erzwungen (Plattformgrenze; der PowerManager gated dies).

---

### User Story 3 - Album aus Home Assistant wechseln (Priority: P3)

Home Assistant zeigt die App als Auswahl (Dropdown) der verfügbaren Alben. Der Nutzer wählt fern ein
anderes Album; die Diashow wechselt auf das gewählte Album und meldet die aktuelle Auswahl zurück.

**Why this priority**: Komfortfunktion; nützlich, aber nachgelagert zu Verbindung/Steuerung und
Helligkeit.

**Independent Test**: Mit Test-Transport: Diashow starten → Discovery für eine Auswahl mit der Liste
der Albumnamen wird veröffentlicht; ein eingehender Auswahlbefehl führt zum Albumwechsel und einer
Rückmeldung der neuen Auswahl.

**Acceptance Scenarios**:

1. **Given** die App ist verbunden und die Albumliste ist bekannt, **When** die Diashow startet,
   **Then** wird eine HA-Discovery-Konfiguration für eine Albumauswahl (mit Optionen) veröffentlicht.
2. **Given** die Auswahl ist in HA sichtbar, **When** ein anderes Album gewählt wird, **Then** wechselt
   die Diashow auf dieses Album und meldet die neue Auswahl zurück.
3. **Given** ein Auswahlbefehl für ein unbekanntes/nicht mehr vorhandenes Album trifft ein, **When** er
   verarbeitet wird, **Then** bleibt die aktuelle Auswahl unverändert (kein Absturz, kein leerer
   Zustand) und der tatsächliche Zustand wird zurückgemeldet.

---

### User Story 4 - Display sleep/wake + presence from Home Assistant (Priority: P3)

> Added 2026-06-22 from the feature interview. The wake schedule/logic lives in Home Assistant; the
> app exposes the entities and reacts.

The app publishes a **sleep/wake** control to Home Assistant and accepts an inbound **presence /
occupancy** signal (e.g. from an HA motion sensor). On "sleep" / "no presence" the app dims to
near-black via the PowerManager sleep/wake seam (spec 004); on "wake" / "presence" it restores. The
schedule and the motion sensor live in Home Assistant.

**Why this priority**: Extends remote control toward an ambient, presence-aware frame, reusing the
existing MQTT/discovery and PowerManager; not required for basic remote control. Builds on P1.

**Independent Test**: With the test transport: on connect, a sleep/wake control is published via
discovery; an inbound "sleep" / no-presence message dims the display to near-black; "wake" / presence
restores it; state is reported back.

**Acceptance Scenarios**:

1. **Given** the app is connected, **When** it starts, **Then** a sleep/wake control is published via
   HA discovery alongside the existing entities.
2. **Given** an HA motion sensor reports no presence (or "sleep" is set), **When** the message
   arrives, **Then** the app dims the display to near-black and reports the state.
3. **Given** presence returns (or "wake" is set), **When** the message arrives, **Then** the app
   restores brightness and reports the state.

---

### Edge Cases

- **Broker nicht erreichbar / Verbindung scheitert**: Die Diashow läuft lokal normal weiter; die
  Fernsteuerung ist schlicht nicht verfügbar (kein Absturz, keine Blockade der Bildanzeige).
- **Fehlende/ungültige Credentials**: Ohne gültige Broker-Daten wird keine Verbindung versucht; die App
  funktioniert lokal weiter (Broker-Eingabe-UI ist out of scope/separat).
- **Verbindungsabbruch während des Betriebs**: LWT meldet „offline"; bei Wiederverbindung wird „online"
  und der aktuelle Zustand erneut gemeldet (Selbstheilung ohne Nutzeraktion).
- **App im Hintergrund**: Eingehende Befehle, die Vordergrund-Kontrolle brauchen (Helligkeit), werden
  nicht im Hintergrund erzwungen (Plattformgrenze, an PowerManager delegiert).
- **Widersprüchliche/schnelle Befehle**: Der zuletzt empfangene Befehl gewinnt; der zurückgemeldete
  Zustand entspricht immer dem tatsächlichen App-Zustand (keine Phantomzustände).
- **Doppelte Discovery**: Wiederholtes Veröffentlichen der Discovery-Konfiguration führt in HA nicht zu
  Duplikaten (stabile, eindeutige Kennungen je Entität/Gerät).
- **Secret-Leck**: Broker-Passwort/Benutzername erscheinen nie in Logs, UserDefaults, Cache oder
  committeten Dateien.

## Requirements *(mandatory)*

### Functional Requirements

#### Verbindung & Sicherheit (P1)

- **FR-001**: Die App MUSS sich als MQTT-Client über eine TLS-gesicherte Verbindung mit dem
  konfigurierten Broker verbinden; die TLS-Validierung MUSS aktiv bleiben (Konstitution IV).
- **FR-002**: Broker-Host/Port und Credentials (Benutzername/Passwort) MÜSSEN aus der sicheren Ablage
  (Keychain) gelesen werden; sie dürfen NIE in UserDefaults, Logs, Cache oder committeten Dateien
  erscheinen (Konstitution III).
- **FR-003**: Liegen keine gültigen Broker-Daten vor oder scheitert die Verbindung, MUSS die App lokal
  normal weiterlaufen (Fernsteuerung nicht verfügbar, kein Absturz, keine Blockade der Diashow).
- **FR-004**: Die App MUSS beim Verbinden eine „online"-Verfügbarkeit veröffentlichen und ein
  Last-Will-and-Testament registrieren, sodass der Broker bei Verbindungsverlust automatisch „offline"
  publiziert (FR-... Verfügbarkeit).
- **FR-005**: Nach einem Verbindungsabbruch MUSS die App eine Wiederverbindung versuchen und bei Erfolg
  erneut „online" sowie den aktuellen Zustand melden (Selbstheilung).

#### Home-Assistant-Discovery & Pause/Play (P1)

- **FR-006**: Die App MUSS sich per Home-Assistant-MQTT-Discovery anmelden und dabei stabile,
  eindeutige Kennungen je Gerät/Entität verwenden, sodass wiederholtes Anmelden keine Duplikate
  erzeugt.
- **FR-007**: Die App MUSS eine Schalter-Entität (Pause/Play) per Discovery bereitstellen, deren
  Verfügbarkeit an die Online-/Offline-Anzeige gekoppelt ist.
- **FR-008**: Ein eingehender „pause"-Befehl MUSS die laufende Diashow pausieren; ein „play"-Befehl MUSS
  sie fortsetzen.
- **FR-009**: Die App MUSS den aktuellen Pause/Play-Zustand zurückmelden — sowohl nach einem
  Fernbefehl als auch nach einer lokalen Änderung in der App —, sodass Home Assistant den echten
  Zustand spiegelt.

#### Modularität & Testbarkeit (alle Stories)

- **FR-010**: Der MQTT-Transport MUSS hinter einem injizierbaren Protokoll gekapselt sein, sodass die
  HA-Logik (Discovery-Inhalte, Topic-Struktur, Zustandsabbildung, Verfügbarkeit, Befehlsverarbeitung)
  ohne echten Broker deterministisch testbar ist (Konstitution II).
- **FR-011**: Eingehende Befehle MÜSSEN robust verarbeitet werden: ungültige/unbekannte Nutzlasten
  führen nicht zu Absturz oder inkonsistentem Zustand; der zuletzt gültige Befehl bestimmt das
  Ergebnis, und der zurückgemeldete Zustand entspricht stets dem tatsächlichen App-Zustand.

#### Helligkeit (P2)

- **FR-012**: Die App MUSS eine dimmbare Licht-Entität per Discovery bereitstellen.
- **FR-013**: Ein eingehender Helligkeitsbefehl MUSS die Bildschirmhelligkeit über den bestehenden
  PowerManager setzen (geklemmt auf den gültigen Bereich) und den angewandten Wert zurückmelden;
  Vordergrund-Grenzen des PowerManagers bleiben gewahrt (Hintergrund erzwingt nichts).

#### Album (P3)

- **FR-014**: Die App MUSS eine Auswahl-Entität (Albumliste) per Discovery bereitstellen, deren Optionen
  den verfügbaren Albumnamen entsprechen.
- **FR-015**: Ein eingehender Auswahlbefehl für ein gültiges Album MUSS die Diashow auf dieses Album
  wechseln und die neue Auswahl zurückmelden; ein Befehl für ein unbekanntes Album MUSS den aktuellen
  Zustand unverändert lassen und korrekt zurückmelden.

#### Presence & Sleep/Wake (P3, added 2026-06-22)

- **FR-016**: The app MUST publish a **sleep/wake** control via Home-Assistant discovery; "sleep" MUST
  dim the display to near-black and "wake" MUST restore it, using the PowerManager sleep/wake seam
  (spec 004 FR-014).
- **FR-017**: The app MUST accept an inbound **presence/occupancy** signal (e.g. from an HA motion
  sensor) that drives sleep/wake; the wake **schedule and sensor live in Home Assistant** (no in-app
  scheduler). Invalid/unknown payloads MUST be ignored safely (per FR-011).

### Key Entities *(include if feature involves data)*

- **Broker-Verbindungsdaten**: Host, Port, Benutzername, Passwort (aus dem Keychain); plus die
  Information, ob eine gültige Konfiguration vorliegt.
- **Geräte-Identität**: stabile, eindeutige Kennung des iPads als HA-Gerät, an die alle Entitäten und
  die Verfügbarkeit gebunden sind.
- **HA-Entität**: eine fernsteuerbare Fähigkeit (Schalter Pause/Play, Licht Helligkeit, Auswahl Album)
  mit Discovery-Konfiguration, Befehls-Eingang, Zustands-Rückmeldung und Verfügbarkeits-Kopplung.
- **Fernsteuerungs-Zustand**: der gespiegelte App-Zustand (läuft/pausiert, aktuelle Helligkeit,
  aktuelles Album), der nach jeder Änderung zurückgemeldet wird.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Nach Start der Diashow mit gültigen Broker-Daten erscheint die App in Home Assistant als
  Gerät mit einem Pause/Play-Schalter und einer Online-Anzeige (Verfügbarkeit „online").
- **SC-002**: Ein in Home Assistant ausgelöster „pause"-Befehl pausiert die Diashow, ein „play"-Befehl
  setzt sie fort; der gemeldete Zustand entspricht jeweils dem tatsächlichen App-Zustand.
- **SC-003**: Eine lokale Pause/Play-Änderung in der App wird innerhalb kurzer Zeit in Home Assistant
  als passender Zustand sichtbar (kein dauerhaftes Auseinanderlaufen).
- **SC-004**: Ein simulierter/realer Verbindungsabbruch führt dazu, dass Home Assistant das Gerät als
  „offline" anzeigt; nach Wiederverbindung wieder „online".
- **SC-005**: Wiederholtes Anmelden (Discovery) erzeugt in Home Assistant keine doppelten Geräte/
  Entitäten.
- **SC-006**: Bei nicht erreichbarem Broker oder fehlenden Credentials läuft die Diashow lokal
  unverändert weiter (kein Absturz, keine sichtbare Beeinträchtigung der Bildanzeige).
- **SC-007**: Das Broker-Passwort/der Benutzername erscheinen in keinem Log, keiner UserDefaults-Ablage,
  keinem Cache und keiner committeten Datei.
- **SC-008** (P2): Ein ferngesetzter Helligkeitswert wird auf dem iPad angewandt (geklemmt) und
  zurückgemeldet.
- **SC-009** (P3): Eine ferngewählte Albumauswahl wechselt die Diashow auf das gewählte Album und wird
  zurückgemeldet; eine ungültige Auswahl lässt den Zustand unverändert.

## Assumptions

- Es existiert ein erreichbarer MQTT-Broker mit gültigem TLS-Zertifikat (analog zur Annahme beim
  Immich-Server; Self-signed/Klartext sind bewusst out of scope).
- Die Broker-Verbindungsdaten liegen bereits im Keychain vor; die UI/Onboarding-Schritt zur Eingabe der
  Broker-Daten ist **separat/out of scope** dieses Features. Für Tests und MVP wird angenommen, dass
  eine gültige Konfiguration injiziert/bereitgestellt werden kann.
- Home Assistant ist mit aktivierter MQTT-Integration und MQTT-Discovery vorhanden (Standard-
  Discovery-Konvention).
- Der konkrete MQTT-Client stammt aus einer SPM-Bibliothek (bewusste, dokumentierte Ausnahme von „keine
  Drittbibliotheken", begrenzt auf die Transportschicht); die HA-Logik bleibt im eigenen
  host-testbaren Modul hinter dem `MQTTTransport`-Protokoll.
- Helligkeit (P2) nutzt den bestehenden PowerManager (Feature 004); Albumwechsel (P3) nutzt die
  bestehende Diashow-/Album-Quelle (Feature 003/001).
- Die Fernsteuerung wirkt, während die App im Vordergrund läuft; Vordergrund-Grenzen (Helligkeit/Idle)
  entsprechen Konstitution V.

### Out of Scope

- Cloud-/Remote-Steuerung ohne lokalen Broker; Mehr-Geräte-Setups.
- HA-Automationen/Szenen (die baut der Nutzer in HA selbst auf Basis der bereitgestellten Entitäten).
- Onboarding-/Einstellungs-UI zur Eingabe der Broker-Daten (separates Feature).
- Self-signed/Klartext-MQTT (keine TLS-Ausnahme, Konstitution IV).
