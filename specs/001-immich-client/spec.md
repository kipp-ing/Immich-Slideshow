# Feature Specification: ImmichClient — Datenanbindung

**Feature Branch**: `001-immich-client`

**Created**: 2026-06-17

**Status**: Draft

**Input**: User description (aus `spec-input-immichclient.md`): "Als Nutzer möchte ich, dass die App
sich mit meinem Immich-Server verbindet und die Bilder eines von mir gewählten Albums laden kann,
damit die Slideshow Inhalte hat."

## User Scenarios & Testing *(mandatory)*

Dieses Feature umfasst **nur die Datenanbindung** — keine UI, keine Slideshow-Darstellung. Die
folgenden User Stories beschreiben die Daten-Fähigkeiten, die spätere Features (SlideshowView,
Onboarding) konsumieren.

### User Story 1 - Alben des Nutzers abrufen (Priority: P1)

Mit einer gültigen Server-URL und einem API-Key kann der Nutzer die Liste seiner Alben abrufen, um
daraus eines für die Slideshow auszuwählen.

**Why this priority**: Ohne Albumliste gibt es nichts auszuwählen und keine Inhalte zu laden — dies
ist der erste Machbarkeits-Test gegen den echten Server und die Grundlage aller weiteren Features.

**Independent Test**: Gegen einen Mock-Transport mit gültiger Album-JSON-Antwort liefert der Abruf
eine Liste von Alben mit Name und ID; ohne echten Server vollständig prüfbar.

**Acceptance Scenarios**:

1. **Given** eine gültige Server-URL und ein gültiger API-Key, **When** die Albumliste abgerufen
   wird, **Then** wird eine Liste von Alben mit jeweils Name und ID zurückgegeben.
2. **Given** eine gültige Album-JSON-Antwort des Servers, **When** sie verarbeitet wird, **Then**
   wird sie korrekt in Album-Modelle übersetzt (kein Datenverlust bei Name und ID).
3. **Given** jeder beliebige Abruf, **When** die Anfrage an den Server geht, **Then** trägt sie den
   API-Key im Header `x-api-key`.

---

### User Story 2 - Bild-Assets eines Albums abrufen (Priority: P1)

Nach Wahl eines Albums kann der Nutzer dessen Bild-Assets (IDs + nötige Metadaten) abrufen, damit
die Slideshow weiß, welche Bilder es gibt.

**Why this priority**: Ein Album ohne abrufbare Assets liefert keine Inhalte; zusammen mit Story 1
bildet dies das Minimum für eine funktionsfähige Datenquelle.

**Independent Test**: Gegen einen Mock mit Album-Assets-Antwort liefert der Abruf eine Liste von
Assets mit IDs und Metadaten; ein leeres Album liefert eine leere, gültige Liste ohne Fehler.

**Acceptance Scenarios**:

1. **Given** ein gewähltes Album mit Bildern, **When** dessen Assets abgerufen werden, **Then**
   wird eine Liste von Assets mit IDs und den für die Anzeige nötigen Metadaten zurückgegeben.
2. **Given** ein gewähltes Album **ohne** Assets, **When** dessen Assets abgerufen werden, **Then**
   wird eine leere, gültige Liste zurückgegeben (kein Fehler, kein Crash).

---

### User Story 3 - Vorschaubild eines Assets laden (Priority: P2)

Für ein Asset kann ein herunterskaliertes Vorschaubild (nicht das Original) geladen werden, das zur
Anzeige geeignet ist.

**Why this priority**: Notwendig, damit die spätere Slideshow Bilder anzeigen kann, ohne große
Originale zu übertragen; baut auf Story 1+2 auf.

**Independent Test**: Gegen einen Mock, der Bilddaten für eine Asset-ID liefert, gibt der Abruf die
Vorschaudaten dieses Assets zurück.

**Acceptance Scenarios**:

1. **Given** eine gültige Asset-ID, **When** das Vorschaubild abgerufen wird, **Then** werden
   Bilddaten einer herunterskalierten Vorschau (nicht des Originals) zurückgegeben.

---

### Edge Cases

- **Falscher/abgelaufener API-Key (401)**: Der Fehler ist klar als „nicht autorisiert" erkennbar
  und unterscheidbar von einem generischen Fehler.
- **Server nicht erreichbar / Timeout**: Der Fehler ist klar als „nicht erreichbar" erkennbar und
  unterscheidbar von einem Autorisierungsfehler.
- **Leeres Album**: Liefert eine leere, aber gültige Liste — kein Fehler.
- **Unerwartete/fehlerhafte JSON-Antwort**: Wird als Parsing-/Antwortfehler behandelt, nicht als
  Crash.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Das System MUSS eine Server-Basis-URL (HTTPS) und einen API-Key als Konfiguration
  entgegennehmen.
- **FR-002**: Das System MUSS jede ausgehende Anfrage über den API-Key im Header `x-api-key`
  authentifizieren.
- **FR-003**: Das System MUSS die Liste der Alben des Nutzers abrufen können (je Album mindestens
  Name und ID).
- **FR-004**: Das System MUSS zu einem gewählten Album dessen Bild-Assets abrufen können (IDs plus
  die für die Anzeige nötigen Metadaten).
- **FR-005**: Das System MUSS für ein Asset ein herunterskaliertes Vorschaubild laden können (nicht
  das Original).
- **FR-006**: Das System MUSS eine 401-Antwort als „nicht autorisiert" erkennbaren Fehler melden,
  unterscheidbar von einem generischen Fehler.
- **FR-007**: Das System MUSS einen Timeout / nicht erreichbaren Server als „nicht erreichbar"
  erkennbaren Fehler melden, unterscheidbar von einem Autorisierungsfehler.
- **FR-008**: Das System MUSS ein leeres Album als leere, gültige Liste liefern (kein Fehler).
- **FR-009**: Das System MUSS gültige Album-JSON-Antworten verlustfrei in Album-Modelle übersetzen.
- **FR-010**: Die gesamte Logik MUSS gegen einen Mock-Transport testbar sein, ohne echten Server.

### Key Entities *(include if feature involves data)*

- **Album**: Repräsentiert ein Foto-Album des Nutzers. Schlüsselattribute: ID (eindeutig), Name.
- **Asset**: Repräsentiert ein einzelnes Bild in einem Album. Schlüsselattribute: ID (eindeutig),
  Anzeige-Metadaten (z. B. Typ/Orientierung, soweit für die Darstellung nötig).
- **ServerConfig**: Verbindungsdaten — Basis-URL (HTTPS) und API-Key.
- **Fehlerkategorien**: mindestens unterscheidbar „nicht autorisiert" (401), „nicht erreichbar"
  (Timeout/Netzwerk) und „ungültige Antwort" (Parsing).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100 % der Abrufe tragen den `x-api-key`-Header (in Tests verifizierbar über den
  Mock-Transport).
- **SC-002**: Eine gültige Album-JSON-Antwort wird zu 100 % verlustfrei in Album-Modelle übersetzt
  (jeder Name und jede ID erhalten).
- **SC-003**: Eine 401-Antwort führt in 100 % der Fälle zu einem als „nicht autorisiert"
  erkennbaren Fehler, nie zu einem generischen.
- **SC-004**: Ein Timeout führt in 100 % der Fälle zu einem als „nicht erreichbar" erkennbaren
  Fehler.
- **SC-005**: Das Laden eines Albums ohne Assets liefert in 100 % der Fälle eine leere Liste ohne
  Fehler.
- **SC-006**: Die gesamte Feature-Logik ist ohne echten Server lauffähig getestet (Mock-Transport
  deckt alle Akzeptanzszenarien ab).

## Assumptions

- Der Immich-Server hat ein **gültiges** TLS-Zertifikat; Standard-HTTPS ohne TLS-Ausnahme genügt.
  Self-signed-Zertifikate und lokale Klartext-Verbindungen sind ausdrücklich außerhalb des Scopes.
- Der API-Key wird diesem Feature von außen übergeben; die sichere Ablage (Keychain) ist Sache des
  späteren Onboarding-Features, nicht dieses Features.
- Die konkreten Immich-API-Pfade werden gegen die OpenAPI-Spec der laufenden Server-Version geprüft
  (`/api/server/version`), nicht aus alten Tutorials übernommen.
- „Nötige Metadaten" eines Assets meint die für die spätere Anzeige minimal erforderlichen Felder;
  der genaue Umfang wird im Plan/bei der Implementierung gegen die Server-Antwort festgelegt.

## Out of Scope (bewusst)

- Self-signed-Zertifikate und lokale Klartext-Verbindungen.
- Caching-Strategie und Offline-Modus.
- Jegliche UI und die Slideshow-Darstellung selbst.
- Sichere Persistenz des API-Keys (Keychain) — Teil des Onboarding-Features.
