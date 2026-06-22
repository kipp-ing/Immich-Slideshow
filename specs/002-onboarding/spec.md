# Feature Specification: Onboarding (Ersteinrichtung)

**Feature Branch**: `002-onboarding`

**Created**: 2026-06-18

**Status**: Draft

**Input**: User description: "Onboarding (first-run setup) für die ImmichSlideshow-iPad-App: drei Schritte Server-URL → API-Key → Album, API-Key im Keychain, Konfiguration persistent, Onboarding bei vorhandener Konfiguration überspringen, Reset möglich, Fehlerbehandlung über ImmichError."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ersteinrichtung abschließen (Priority: P1)

Beim allerersten Start führt die App den Nutzer durch drei Schritte: Server-Adresse eingeben,
API-Key eingeben, ein Album auswählen. Nach erfolgreichem Abschluss ist die App verbunden,
kennt das gewählte Album und zeigt den Hauptscreen (vorerst Platzhalter).

**Why this priority**: Ohne Einrichtung hat die App keine Datenquelle und kann nichts anzeigen.
Dies ist der einzige Weg, die App überhaupt nutzbar zu machen — das MVP.

**Independent Test**: Mit einer gemockten Datenquelle die drei Schritte durchlaufen (gültige
Adresse, gültiger Key, Albumliste mit mindestens einem Eintrag) und prüfen, dass am Ende eine
gültige Konfiguration vorliegt und der Hauptscreen erscheint.

**Acceptance Scenarios**:

1. **Given** kein vorheriges Setup, **When** der Nutzer eine gültige Server-Adresse eingibt und bestätigt, **Then** wird die Erreichbarkeit geprüft und der Nutzer gelangt zum Schritt API-Key.
2. **Given** eine geprüfte Server-Adresse, **When** der Nutzer einen gültigen API-Key eingibt, **Then** wird der Key über einen echten Abruf validiert, sicher gespeichert und der Nutzer gelangt zur Albumauswahl.
3. **Given** ein gültiger API-Key, **When** die Albumauswahl geöffnet wird, **Then** erscheint die Liste der verfügbaren Alben des Nutzers.
4. **Given** eine angezeigte Albumliste, **When** der Nutzer ein Album wählt und bestätigt, **Then** wird die Auswahl gespeichert, das Onboarding ist abgeschlossen und der Hauptscreen erscheint.

---

### User Story 2 - Einrichtung beim erneuten Start überspringen (Priority: P2)

Startet der Nutzer die App erneut und es existiert bereits eine gültige Konfiguration, wird das
Onboarding übersprungen und der Hauptscreen direkt angezeigt.

**Why this priority**: Wiederkehrende Nutzung darf nicht jedes Mal eine Neueinrichtung verlangen;
die App ist für den Dauerbetrieb (Slideshow) gedacht.

**Independent Test**: Mit vorhandener, gültiger Konfiguration starten und prüfen, dass kein
Onboarding-Schritt erscheint, sondern direkt der Hauptscreen.

**Acceptance Scenarios**:

1. **Given** eine vollständige, gespeicherte Konfiguration (Adresse, Key, Album), **When** die App startet, **Then** wird kein Onboarding angezeigt und der Hauptscreen erscheint.
2. **Given** eine unvollständige Konfiguration (z. B. Key fehlt im sicheren Speicher), **When** die App startet, **Then** beginnt das Onboarding beim ersten fehlenden Schritt.

---

### User Story 3 - Einstellungen zurücksetzen / neu einrichten (Priority: P3)

Der Nutzer kann die gespeicherte Konfiguration zurücksetzen und das Onboarding erneut durchlaufen,
um Server, Key oder Album zu ändern.

**Why this priority**: Server-Adressen, Keys oder das gewünschte Album ändern sich gelegentlich;
ohne Reset müsste die App neu installiert werden.

**Independent Test**: Bei vorhandener Konfiguration den Reset auslösen und prüfen, dass danach das
Onboarding wieder bei Schritt 1 startet und der zuvor gespeicherte Key entfernt wurde.

**Acceptance Scenarios**:

1. **Given** eine vollständige Konfiguration, **When** der Nutzer "Zurücksetzen" auslöst, **Then** werden Adresse, Album und der sicher gespeicherte Key entfernt.
2. **Given** ein durchgeführter Reset, **When** die App den nächsten Schritt bestimmt, **Then** beginnt das Onboarding bei Schritt 1 (Server-Adresse).

---

### User Story 4 - Two connection modes: own server (API key) vs shared link (Priority: P2, seams now)

> Added 2026-06-22 from the feature interview. Decision: **design the seams now, build the shared-link
> path later.** The API-key flow is unchanged.

Onboarding abstracts over the **connection mode**: the existing "use my server (API key)" path, and a
future **"paste a shared link + password"** super-simple mode that needs no own Immich instance or API
key. The shared-link entry is present in the flow but **stubbed/disabled**; the abstraction (so the
second mode drops in without reworking onboarding or the client) is what ships now.

**Why this priority**: The super-simple mode meaningfully widens who can use the app; getting the seams
right now avoids a later rewrite. The full shared-link fetch is deferred.

**Independent Test**: The onboarding/auth layer abstracts over auth mode (API key vs shared-link token
+ password) such that the API-key flow works end-to-end and a shared-link mode can be added without
changing the flow's structure; the shared-link entry is visible but disabled.

**Acceptance Scenarios**:

1. **Given** the start of onboarding, **When** the user views connection options, **Then** "use my
   server (API key)" works as today and a "paste a shared link" option is present but stubbed.
2. **Given** the auth abstraction, **When** a shared-link mode is added later, **Then** it plugs into
   the existing flow and client without reworking the API-key path.

---

### Edge Cases

- **Ungültiges Adressformat**: Eingabe ist keine gültige HTTPS-URL → Hinweis vor jedem Netzaufruf, Schritt wiederholbar.
- **Server nicht erreichbar** (Timeout/keine Verbindung): klare Meldung "Server nicht erreichbar", Schritt 1 wiederholbar, ohne App-Neustart.
- **Falscher API-Key** (401): Meldung "Ungültiger API-Key", zurück zu Schritt 2, Eingabe wiederholbar.
- **Unerwartete Server-Antwort** (nicht dekodierbar / unerwarteter Status): allgemeine Meldung "Unerwartete Antwort vom Server", Schritt wiederholbar.
- **Keine Alben vorhanden**: Albumliste ist leer → Hinweis, dass kein Album gewählt werden kann, mit Möglichkeit, Schritt 1/2 zu korrigieren.
- **App-Abbruch während des Onboardings**: noch nicht abgeschlossene, unvollständige Konfiguration führt beim nächsten Start zurück in das Onboarding (kein halb-fertiger Zustand, der den Hauptscreen freigibt).
- **Nur-Lesen-Schreibfehler des sicheren Speichers**: schlägt das sichere Speichern des Keys fehl, wird der Schritt nicht als erfolgreich markiert und eine Meldung angezeigt.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Beim Start MUSS die App ermitteln, ob eine vollständige, gültige Konfiguration vorliegt, und bei Vorhandensein das Onboarding überspringen.
- **FR-002**: Liegt keine vollständige Konfiguration vor, MUSS die App das Onboarding beim ersten fehlenden Schritt beginnen.
- **FR-003**: Der Nutzer MUSS in Schritt 1 eine Server-Adresse eingeben können; die App MUSS deren Format prüfen und nur sichere (HTTPS-)Adressen akzeptieren.
- **FR-004**: Vor dem Weitergehen von Schritt 1 MUSS die App die Erreichbarkeit des Servers prüfen und bei Misserfolg eine verständliche, wiederholbare Fehlermeldung zeigen.
- **FR-005**: Der Nutzer MUSS in Schritt 2 einen API-Key eingeben können; die App MUSS den Key durch einen echten, authentifizierten Abruf validieren.
- **FR-006**: Der API-Key MUSS ausschließlich in einem sicheren Speicher abgelegt werden und DARF NICHT in ungesicherten Einstellungen, im Klartext, in Logs oder in committeten Dateien erscheinen.
- **FR-007**: Server-Adresse und gewählte Album-Kennung MÜSSEN dauerhaft gespeichert werden, sodass sie App-Neustarts überdauern.
- **FR-008**: Nach gültigem Key MUSS die App die Albumliste des Nutzers laden und zur Auswahl anbieten.
- **FR-009**: Der Nutzer MUSS genau ein Album auswählen; die Auswahl MUSS gespeichert werden und schließt das Onboarding ab.
- **FR-010**: Fehlerzustände (nicht erreichbar, ungültiger Key, unerwartete Antwort) MÜSSEN dem Nutzer in verständlicher Sprache gemeldet werden, mit der Möglichkeit, den betroffenen Schritt zu wiederholen.
- **FR-011**: Eine unvollständige (abgebrochene) Einrichtung DARF den Hauptscreen NICHT freigeben; der nächste Start MUSS das Onboarding fortsetzen bzw. neu beginnen.
- **FR-012**: Der Nutzer MUSS die Konfiguration zurücksetzen können; dabei MÜSSEN Adresse, Album und der sicher gespeicherte Key entfernt werden, und das Onboarding MUSS danach bei Schritt 1 beginnen.
- **FR-013**: Ist die Albumliste leer, MUSS die App dies verständlich melden, statt den Nutzer in einem Schritt ohne Auswahlmöglichkeit zu blockieren.

#### Connection modes (P2, added 2026-06-22)

- **FR-014**: Onboarding MUST abstract over the **connection/auth mode** (server + API key now; shared
  link + password later) so a second mode can be added without reworking the flow.
- **FR-015**: A **shared-link** entry MUST be present in the flow but MAY be **stubbed/disabled**;
  implementing the actual shared-link connection/fetch is **deferred** (seam only). Secrets handling
  (FR-006) applies equally to a shared-link password.

### Key Entities *(include if feature involves data)*

- **Server-Konfiguration**: repräsentiert die Verbindungsziel-Daten — Server-Adresse und gewählte Album-Kennung (nicht-geheim, dauerhaft gespeichert).
- **Zugangs-Geheimnis (API-Key)**: das geheime Token zur Authentifizierung; ausschließlich im sicheren Speicher, nie im Klartext.
- **Album**: eine wählbare Sammlung aus der Immich-Instanz — Kennung und Anzeigename.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Ein neuer Nutzer kann mit gültiger Server-Adresse und gültigem Key in unter 2 Minuten vom Start bis zum gewählten Album gelangen.
- **SC-002**: Bei einem ungültigen API-Key sieht der Nutzer innerhalb von 5 Sekunden eine klare Fehlermeldung und kann die Eingabe ohne App-Neustart wiederholen.
- **SC-003**: Bei nicht erreichbarem Server sieht der Nutzer eine klare Fehlermeldung und kann den Schritt ohne App-Neustart erneut versuchen.
- **SC-004**: Beim erneuten Start mit vorhandener gültiger Konfiguration erreicht der Nutzer den Hauptscreen ohne erneute Eingabe (0 zusätzliche Schritte).
- **SC-005**: Der API-Key ist in keiner ungesicherten Ablage und in keinem Log auffindbar (durch Inspektion verifizierbar).
- **SC-006**: Nach einem Reset durchläuft der Nutzer das Onboarding wieder vollständig ab Schritt 1, und der zuvor gespeicherte Key ist nicht mehr vorhanden.

## Assumptions

- Die App nutzt das bestehende ImmichClient-Modul als Datenquelle (Albumliste, Authentifizierung über `x-api-key`); dessen Fehlerfälle (unauthorized, unreachable, invalidResponse) bilden die Grundlage der Nutzer-Meldungen.
- Der sichere Speicher ist der iOS-Keychain (Konstitution III); Adresse und Album-Kennung liegen in den App-Einstellungen (UserDefaults).
- Der Immich-Server besitzt ein gültiges Zertifikat; TLS-Validierung wird nicht deaktiviert (Konstitution IV). Self-signed/Klartext ist außerhalb des Scopes.
- Die Erreichbarkeitsprüfung in Schritt 1 erfolgt über einen leichten Endpunkt der laufenden Immich-Instanz (z. B. Server-Version); konkrete Routen werden in der Planungsphase gegen die laufende API geprüft (Konstitution IV).
- Genau ein Album wird ausgewählt (Mehrfachauswahl ist nicht im Scope dieser Iteration).
- Der Reset-Einstieg ist vom Hauptscreen aus erreichbar; die genaue Platzierung ist Gestaltungssache der Umsetzung.
- Zielplattform iPadOS 18+; der Hauptscreen nach Abschluss ist vorerst ein Platzhalter (die echte Slideshow ist ein separates Feature).
