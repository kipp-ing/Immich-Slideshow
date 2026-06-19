# Feature Specification: Broker-Setup (MQTT-Verbindungsdaten einrichten)

**Feature Branch**: `006-broker-setup`

**Created**: 2026-06-19

**Status**: Draft

**Input**: Voraussetzung für HAControl (005): Eingabe/Persistenz der MQTT-Broker-Verbindungsdaten, damit
die Fernsteuerung überhaupt einen Broker hat. Ohne dieses Feature ist der HAControl-Pfad inert (keine
Credentials → keine Verbindung)."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Broker-Verbindung einrichten (Priority: P1) 🎯 MVP

Der Nutzer öffnet in der App eine Einstellungsmöglichkeit für die MQTT-Broker-Verbindung und gibt
Host, Port, Benutzername und Passwort seines vorhandenen Brokers ein. Nach dem Speichern stehen diese
Daten der Fernsteuerung (Feature 005) zur Verfügung; Passwort und Benutzername liegen sicher im
Keychain, Host/Port als nicht-geheime Einstellungen.

**Why this priority**: Ohne hinterlegte Broker-Daten kann sich die App nirgends verbinden — die
HAControl-Fernsteuerung bleibt funktionslos. Das ist der minimale Schnitt, der den MQTT-Pfad „scharf"
schaltet.

**Independent Test**: Broker-Daten eingeben und speichern → die persistierte Konfiguration ist über die
Bereitstellungs-Schnittstelle (BrokerConfigStore) vollständig und korrekt abrufbar (Host/Port/User/Pass
+ stabile Geräte-ID); das Passwort liegt im Keychain, nicht in UserDefaults.

**Acceptance Scenarios**:

1. **Given** keine Broker-Daten sind hinterlegt, **When** der Nutzer gültige Daten (Host, Port,
   Benutzername, Passwort) eingibt und speichert, **Then** ist eine vollständige Broker-Konfiguration
   abrufbar und die Fernsteuerung kann sie nutzen.
2. **Given** der Nutzer gibt eine ungültige Eingabe ein (leerer Host, Port außerhalb 1–65535), **When**
   er zu speichern versucht, **Then** wird das Speichern abgelehnt/verhindert und ein Hinweis gezeigt;
   es wird keine unvollständige Konfiguration persistiert.
3. **Given** Broker-Daten wurden gespeichert, **When** die Persistenz inspiziert wird, **Then** liegt
   das Passwort (und der Benutzername) im Keychain und niemals in UserDefaults/Logs/committeten Dateien.
4. **Given** Broker-Daten wurden gespeichert, **When** die App neu gestartet wird, **Then** sind die
   Daten weiterhin abrufbar (persistente Ablage).

---

### User Story 2 - Broker-Verbindung ändern oder entfernen (Priority: P2)

Der Nutzer kann bestehende Broker-Daten einsehen (ohne dass das Passwort im Klartext aufgedrängt wird),
ändern und wieder vollständig entfernen. Nach dem Entfernen versucht die App keine Verbindung mehr.

**Why this priority**: Korrektur/Abschaltung ist wichtig für die Praxis, aber nachgelagert zum
erstmaligen Einrichten.

**Independent Test**: Gespeicherte Daten ändern → die neue Konfiguration ist abrufbar; Entfernen →
keine Konfiguration mehr abrufbar (Fernsteuerung wird inert).

**Acceptance Scenarios**:

1. **Given** Broker-Daten sind hinterlegt, **When** der Nutzer Host/Port/User/Passwort ändert und
   speichert, **Then** spiegelt die abrufbare Konfiguration die neuen Werte (altes Passwort im Keychain
   überschrieben).
2. **Given** Broker-Daten sind hinterlegt, **When** der Nutzer „Entfernen" wählt, **Then** ist keine
   Broker-Konfiguration mehr abrufbar und das Keychain-Geheimnis ist gelöscht.
3. **Given** ein bestehendes Passwort ist gespeichert, **When** der Nutzer das Eingabeformular öffnet,
   **Then** wird das Passwort nicht im Klartext vorbefüllt aufgedrängt (Maskierung/leeres Feld mit
   Hinweis „gesetzt").

---

### Edge Cases

- **Anonymer Broker**: Manche Broker erlauben Verbindungen ohne Credentials. Für dieses Feature werden
  Benutzername und Passwort als **erforderlich** behandelt (HA-Setups nutzen üblicherweise Auth);
  anonyme Broker sind nicht im MVP-Scope.
- **Port-Standard**: Wird kein Port eingegeben, wird der TLS-Standardport (8883) vorgeschlagen.
- **Whitespace/typos im Host**: Eingaben werden getrimmt; ein leerer Host nach Trimmen ist ungültig.
- **Teilweise gespeicherte Daten**: Es wird nie eine unvollständige Konfiguration persistiert (atomar:
  entweder vollständig gültig gespeichert oder gar nicht).
- **Geräte-ID**: Die für die Fernsteuerung nötige stabile Geräte-Kennung wird von der App abgeleitet
  (nicht vom Nutzer eingegeben) und ist über App-Neustarts stabil.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Der Nutzer MUSS Broker-Host, Port, Benutzername und Passwort eingeben können.
- **FR-002**: Eingaben MÜSSEN validiert werden: Host (nach Trimmen) nicht leer; Port im Bereich
  1–65535; Benutzername und Passwort nicht leer. Ungültige Eingaben verhindern das Speichern mit einem
  Hinweis.
- **FR-003**: Beim Speichern MÜSSEN Passwort und Benutzername im Keychain abgelegt werden; sie dürfen
  nie in UserDefaults, Logs, Cache oder committeten Dateien erscheinen (Konstitution III). Host/Port
  dürfen als nicht-geheime Einstellungen abgelegt werden.
- **FR-004**: Es DARF nie eine unvollständige Broker-Konfiguration persistiert werden (atomar:
  vollständig gültig oder gar nicht).
- **FR-005**: Die App MUSS eine vollständige Broker-Konfiguration (Host/Port/Benutzername/Passwort +
  abgeleitete, stabile Geräte-ID) über eine Bereitstellungs-Schnittstelle abrufbar machen, die die
  Fernsteuerung (Feature 005) konsumiert. Fehlt eine vollständige Konfiguration, MUSS die Schnittstelle
  „keine Konfiguration" liefern.
- **FR-006**: Gespeicherte Broker-Daten MÜSSEN über App-Neustarts erhalten bleiben.
- **FR-007**: Der Nutzer MUSS bestehende Broker-Daten ändern können; ein geändertes Passwort
  überschreibt das im Keychain hinterlegte. (P2)
- **FR-008**: Der Nutzer MUSS Broker-Daten vollständig entfernen können; danach liefert die
  Bereitstellungs-Schnittstelle „keine Konfiguration" und das Keychain-Geheimnis ist gelöscht. (P2)
- **FR-009**: Beim Anzeigen bestehender Daten DARF das gespeicherte Passwort nicht im Klartext
  aufgedrängt werden (Maskierung bzw. „gesetzt"-Hinweis statt Vorbefüllung). (P2)
- **FR-010**: Die stabile Geräte-Kennung MUSS von der App abgeleitet werden (nicht vom Nutzer
  eingegeben) und über Neustarts stabil sein.

### Key Entities *(include if feature involves data)*

- **Broker-Eingabe**: vom Nutzer eingegebene Werte (Host, Port, Benutzername, Passwort) vor Validierung.
- **Broker-Konfiguration**: validierte, persistierte Verbindungsdaten + abgeleitete Geräte-ID; das
  ist die Form, die die Fernsteuerung konsumiert (entspricht dem `BrokerConfig` aus Feature 005).
- **Validierungsergebnis**: gültig / ungültig (mit Grund), steuert ob gespeichert werden darf.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Nach Eingabe gültiger Daten und Speichern ist eine vollständige Broker-Konfiguration über
  die Bereitstellungs-Schnittstelle abrufbar (alle Felder + Geräte-ID).
- **SC-002**: Ungültige Eingaben (leerer Host, Port außerhalb 1–65535, leerer Benutzername/Passwort)
  führen nicht zu einer persistierten Konfiguration und werden dem Nutzer als Fehler angezeigt.
- **SC-003**: Das Passwort/der Benutzername erscheinen ausschließlich im Keychain — nicht in
  UserDefaults, Logs, Cache oder committeten Dateien.
- **SC-004**: Nach App-Neustart sind zuvor gespeicherte Broker-Daten weiterhin abrufbar.
- **SC-005** (P2): Nach „Entfernen" liefert die Bereitstellungs-Schnittstelle „keine Konfiguration" und
  das Keychain-Geheimnis ist gelöscht.
- **SC-006** (P2): Ein geändertes Passwort überschreibt das vorherige (kein verwaistes Alt-Geheimnis).

## Assumptions

- Der Broker hat ein gültiges TLS-Zertifikat (Annahme aus Feature 005); dieses Feature speichert nur
  die Verbindungsdaten und trifft keine TLS-Entscheidungen.
- Die eigentliche Verbindung/Discovery/Steuerung erfolgt in Feature 005 (HAControl); dieses Feature
  liefert nur die Konfiguration über die `BrokerConfigStore`-Schnittstelle (deren Protokoll in
  HAControlKit/005 definiert ist).
- Anonyme Broker (ohne Credentials) sind out of scope (Credentials erforderlich).
- Die Geräte-Kennung wird aus einer stabilen, geräteeigenen Kennung abgeleitet (über Neustarts stabil).
- Der Einstieg in das Broker-Setup erfolgt über eine bestehende, unaufdringliche
  Einstellungs-/Menü-Möglichkeit der App (ruhiger Default bleibt erhalten, Konstitution VII).

### Out of Scope

- Verbindungsaufbau, MQTT, Discovery, Fernsteuerung selbst (Feature 005).
- Anonyme Broker / Zertifikats-Pinning / Self-signed-Handling.
- Auto-Discovery des Brokers im Netzwerk; Mehr-Broker-/Mehr-Geräte-Verwaltung.
