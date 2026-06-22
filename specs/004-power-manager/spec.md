# Feature Specification: PowerManager (Display wach halten & Helligkeit steuern)

**Feature Branch**: `004-power-manager`

**Created**: 2026-06-19

**Status**: Draft

**Input**: User description: "PowerManager: Während die Diashow im Vordergrund läuft, soll das Display nicht automatisch dunkel werden oder sich sperren (Idle-Timer deaktiviert), damit das iPad als Dauer-Bilderrahmen funktioniert. Zusätzlich soll die App die Bildschirmhelligkeit setzen können (0.0–1.0), inkl. weichem Dimmen auf nahe 0 als „Display aus"-Ersatz (iOS kann das Display nicht physisch ausschalten). Idle-Timer und Helligkeit wirken nur im Vordergrund; geht die App in den Hintergrund, gibt iOS die Kontrolle zurück und der vorherige Zustand wird nicht erzwungen. Beim Verlassen/Beenden der Slideshow wird der Idle-Timer wieder normal aktiviert und eine zuvor geänderte Helligkeit auf den Ausgangswert zurückgesetzt. Out of scope: Fernsteuerung der Helligkeit (HAControl #6), Zeitpläne/Automationen, Theme-Einstellungen."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Display bleibt während der Diashow wach (Priority: P1) 🎯 MVP

Während die Diashow im Vordergrund läuft, darf das iPad nicht automatisch abdunkeln oder sich
sperren. So funktioniert das Gerät als Dauer-Bilderrahmen, ohne dass der Bildschirm nach der
System-Leerlaufzeit ausgeht.

**Why this priority**: Ohne wach gehaltenes Display erfüllt die App ihren Kernzweck (dauerhafter
Bilderrahmen) nicht — nach wenigen Minuten würde der Bildschirm dunkel. Das ist der unmittelbar
wertstiftende Kern des Moduls.

**Independent Test**: Diashow starten und über die System-Leerlaufzeit hinaus laufen lassen → der
Bildschirm bleibt an. Diashow verlassen → der normale Leerlauf-/Sperrmechanismus ist wieder aktiv.

**Acceptance Scenarios**:

1. **Given** die Diashow läuft im Vordergrund, **When** die System-Leerlaufzeit überschritten wird,
   **Then** bleibt das Display an und das Gerät sperrt nicht.
2. **Given** die Diashow läuft mit deaktiviertem Leerlauf-Timer, **When** die Diashow verlassen oder
   beendet wird, **Then** ist der Leerlauf-/Sperrmechanismus wieder im Normalzustand.
3. **Given** die Diashow hält das Display wach, **When** die App in den Hintergrund geht, **Then**
   gibt das Modul die Kontrolle an iOS zurück und erzwingt keinen Wach-Zustand mehr.
4. **Given** die App war im Hintergrund, **When** sie wieder in den Vordergrund kommt und die Diashow
   weiterläuft, **Then** wird das Display erneut wach gehalten.

---

### User Story 2 - Helligkeit setzen und sanft dimmen (Priority: P2)

Die App kann die Bildschirmhelligkeit auf einen Wert zwischen 0.0 und 1.0 setzen und sanft dorthin
überblenden. Ein Dimmen auf nahe 0 dient als „Display aus"-Ersatz (z. B. nachts), da iOS das Display
nicht physisch abschalten kann.

**Why this priority**: Die Helligkeitssteuerung macht den Bilderrahmen alltagstauglich (z. B. nachts
herunterdimmen), ist aber nicht nötig, damit die Diashow überhaupt dauerhaft sichtbar ist. Sie baut
auf US1 auf.

**Independent Test**: Eine Zielhelligkeit setzen → die Bildschirmhelligkeit nähert sich diesem Wert
an. Auf nahe 0 dimmen → der Bildschirm wird sehr dunkel, bleibt aber technisch an.

**Acceptance Scenarios**:

1. **Given** die Diashow läuft im Vordergrund, **When** eine Zielhelligkeit im Bereich 0.0–1.0
   gesetzt wird, **Then** entspricht die Bildschirmhelligkeit anschließend diesem Zielwert.
2. **Given** eine Zielhelligkeit außerhalb 0.0–1.0 wird angefragt, **When** sie angewendet wird,
   **Then** wird der Wert auf den gültigen Bereich begrenzt (geklemmt) statt einen Fehler zu erzeugen.
3. **Given** ein weiches Dimmen ist angefordert, **When** die Zielhelligkeit gesetzt wird, **Then**
   ändert sich die Helligkeit graduell (kein harter Sprung) bis zum Zielwert.
4. **Given** auf nahe 0 gedimmt wurde, **When** wieder hochgedimmt wird, **Then** erreicht die
   Helligkeit den neuen Zielwert; der Bildschirm war durchgehend technisch an.

---

### User Story 3 - Helligkeit beim Verlassen zurücksetzen (Priority: P3)

Beim Verlassen/Beenden der Diashow wird eine zuvor durch die App geänderte Helligkeit auf den
Ausgangswert (den vor Beginn der Diashow gemessenen Systemwert) zurückgesetzt, und der Leerlauf-Timer
wird normalisiert. So hinterlässt die App keinen dauerhaft verstellten Gerätezustand.

**Why this priority**: Verhindert, dass das Gerät nach dem Beenden in einem unerwartet dunklen/hellen
Zustand verbleibt. Wichtig für Sauberkeit, aber nachgelagert zur eigentlichen Steuerung (US1/US2).

**Independent Test**: Ausgangshelligkeit merken, Diashow starten, Helligkeit ändern, Diashow
verlassen → die Helligkeit entspricht wieder dem Ausgangswert und der Leerlauf-Timer ist normal.

**Acceptance Scenarios**:

1. **Given** die App hat die Helligkeit während der Diashow verändert, **When** die Diashow verlassen
   oder beendet wird, **Then** wird die Helligkeit auf den vor Diashow-Beginn gemessenen Wert
   zurückgesetzt.
2. **Given** die App hat die Helligkeit nicht verändert, **When** die Diashow verlassen wird,
   **Then** bleibt die Helligkeit unverändert (kein unnötiges Zurücksetzen).
3. **Given** die App geht in den Hintergrund, **When** der Nutzer außerhalb der App die Helligkeit
   ändert, **Then** überschreibt die App diesen Wert nicht im Hintergrund (Plattformgrenze).

---

### User Story 4 - Presence-driven wake/sleep (schedule delegated) (Priority: P3)

> Added 2026-06-22 from the feature interview. The app does **not** implement an in-app time
> scheduler; night/wake logic is delegated to Home Assistant (spec 005), and the module instead
> exposes a presence-driven sleep/wake seam.

Beyond manual/remote brightness, the module exposes a **display sleep/wake** capability: on "sleep" it
dims to near-black (the "display off" stand-in), on "wake" it restores brightness — driven by an
external **presence** signal. The presence source is abstracted: **Home Assistant / MQTT now** (an HA
motion sensor drives it), with **on-device camera motion detection a later option behind the same
abstraction**. No in-app schedule.

**Why this priority**: Makes the frame ambient-aware (dim when nobody's around) while keeping the
scheduling/sensor concerns out of the app. Builds on US2/US3 (brightness + restore).

**Independent Test**: With a test double for the presence/command source: send "sleep" → brightness
ramps to near-black; send "wake" → it restores to the prior value; the source is injected (no real
sensor needed), proving HA-now / camera-later are interchangeable.

**Acceptance Scenarios**:

1. **Given** the slideshow runs, **When** a "sleep" presence/command arrives, **Then** the display
   ramps to near-black without stopping playback.
2. **Given** the display is asleep, **When** a "wake" presence/command arrives, **Then** brightness
   restores to the prior value.
3. **Given** the presence abstraction, **When** the source is HA/MQTT or (later) on-device camera,
   **Then** either drives the same sleep/wake behavior without engine changes.

---

### Edge Cases

- **Hintergrund während des Dimmens**: Geht die App mitten in einer weichen Helligkeitsänderung in
  den Hintergrund, wird die laufende Änderung gestoppt und nicht im Hintergrund fortgesetzt; iOS
  übernimmt die Kontrolle.
- **Schnell aufeinanderfolgende Zielwerte**: Wird eine neue Zielhelligkeit gesetzt, während eine
  weiche Änderung noch läuft, gilt der neue Zielwert (die alte Animation wird abgelöst, kein
  „Aufstauen").
- **Ausgangswert nicht ermittelbar**: Lässt sich der Ausgangswert nicht zuverlässig lesen, wird beim
  Verlassen kein erzwungener Wert gesetzt (lieber nichts verändern als einen falschen Wert erzwingen).
- **App-Beendigung statt geordnetem Verlassen**: Wird die App hart beendet, kann der Ausgangswert
  nicht durch die App wiederhergestellt werden — das ist eine akzeptierte Plattformgrenze, kein
  Fehlerfall der App.
- **Mehrfaches Aktivieren/Deaktivieren**: Wiederholtes Wach-halten/Freigeben (z. B. mehrere
  Vordergrund-/Hintergrund-Wechsel) führt zu einem konsistenten Endzustand ohne „hängenden"
  deaktivierten Leerlauf-Timer.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Während die Diashow im Vordergrund aktiv ist, MUSS das System den automatischen
  Leerlauf-/Abdunkel-/Sperrmechanismus unterdrücken (Display bleibt an).
- **FR-002**: Beim Verlassen oder Beenden der Diashow MUSS der Leerlauf-/Sperrmechanismus wieder in
  den Normalzustand versetzt werden (keine dauerhafte Deaktivierung).
- **FR-003**: Das Wach-halten MUSS ausschließlich im Vordergrund wirken; beim Wechsel in den
  Hintergrund MUSS die Kontrolle an das Betriebssystem zurückgegeben werden.
- **FR-004**: Beim Rückkehr in den Vordergrund (laufende Diashow) MUSS das Wach-halten erneut
  aktiviert werden.
- **FR-005**: Das System MUSS eine Zielhelligkeit im Bereich 0.0–1.0 setzen können; die
  Bildschirmhelligkeit MUSS sich diesem Zielwert angleichen.
- **FR-006**: Angeforderte Helligkeitswerte außerhalb 0.0–1.0 MÜSSEN auf den gültigen Bereich
  geklemmt werden (kein Fehler, kein Über-/Unterlauf).
- **FR-007**: Das System MUSS ein weiches Dimmen unterstützen, bei dem sich die Helligkeit graduell
  (ohne harten Sprung) bis zum Zielwert verändert.
- **FR-008**: Ein Dimmen auf nahe 0 MUSS möglich sein; es dient als „Display aus"-Ersatz, ohne das
  Display physisch abzuschalten (das kann iOS nicht — Plattformgrenze).
- **FR-009**: Helligkeitsänderungen MÜSSEN ausschließlich im Vordergrund wirken; im Hintergrund
  ändert die App die Helligkeit nicht.
- **FR-010**: Vor der ersten von der App ausgelösten Helligkeitsänderung MUSS der aktuelle
  Helligkeits-Ausgangswert erfasst werden.
- **FR-011**: Beim Verlassen/Beenden der Diashow MUSS eine zuvor von der App geänderte Helligkeit auf
  den erfassten Ausgangswert zurückgesetzt werden; hat die App die Helligkeit nicht verändert, MUSS
  sie unverändert bleiben.
- **FR-012**: Eine laufende weiche Helligkeitsänderung MUSS abgelöst werden, wenn ein neuer Zielwert
  gesetzt wird (der neueste Zielwert gewinnt); bei Wechsel in den Hintergrund MUSS sie gestoppt
  werden.
- **FR-013**: Das Modul MUSS hinter einer injizierbaren Schnittstelle gekapselt sein (kein verstecktes
  Singleton), sodass das Verhalten ohne echtes Display/echte Hardware deterministisch testbar ist.

#### Presence-driven sleep/wake (P3, added 2026-06-22)

- **FR-014**: The module MUST expose a **display sleep/wake** capability behind the injectable
  interface — "sleep" dims to near-black (reusing the soft-dim of FR-007/FR-008), "wake" restores the
  prior brightness (FR-010/FR-011).
- **FR-015**: Sleep/wake MUST be drivable by an **external presence source** that is source-agnostic
  (Home Assistant / MQTT now per spec 005; on-device camera motion later) — the module MUST NOT embed
  a time scheduler (delegated to Home Assistant).

### Key Entities *(include if feature involves data)*

- **Power-Zustand**: Repräsentiert, ob das Display aktuell wach gehalten wird, ob die App die
  Helligkeit verändert hat, und den erfassten Helligkeits-Ausgangswert (für die Wiederherstellung).
- **Helligkeits-Ziel**: Ein angefragter Zielwert (geklemmt auf 0.0–1.0) plus die Angabe, ob hart oder
  weich (graduell) dorthin gewechselt wird.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Bei laufender Diashow im Vordergrund bleibt der Bildschirm auch nach Überschreiten der
  System-Leerlaufzeit an (kein Abdunkeln/Sperren).
- **SC-002**: Nach Verlassen der Diashow ist der Leerlauf-/Sperrmechanismus wieder normal aktiv
  (Display dunkelt nach Leerlaufzeit wieder ab).
- **SC-003**: Eine gesetzte Zielhelligkeit im Bereich 0.0–1.0 wird mit dem Endwert erreicht; Werte
  außerhalb des Bereichs werden auf 0.0 bzw. 1.0 geklemmt.
- **SC-004**: Ein weiches Dimmen erreicht den Zielwert über mehrere Zwischenschritte (mindestens ein
  beobachtbarer Zwischenwert zwischen Start und Ziel), nicht in einem einzigen harten Sprung.
- **SC-005**: Nach Verlassen der Diashow entspricht die Helligkeit wieder dem vor Diashow-Beginn
  erfassten Ausgangswert, sofern die App sie verändert hatte.
- **SC-006**: Im Hintergrund nimmt die App keine Helligkeits- oder Leerlauf-Timer-Änderungen vor (ein
  vom Nutzer im Hintergrund gesetzter Wert bleibt unangetastet).

## Assumptions

- Das Wach-halten und die Helligkeit beziehen sich auf das Gerät, auf dem die App im Vordergrund
  läuft; eine Mehr-Geräte- oder Fernsteuerung ist nicht Teil dieses Features (→ HAControl #6).
- Der „Ausgangswert" der Helligkeit ist der unmittelbar vor der ersten App-Änderung gemessene
  Systemwert; nutzergesteuerte Änderungen außerhalb der App (Kontrollzentrum) im Hintergrund werden
  respektiert und nicht überschrieben.
- Die Diashow (Feature 003) liefert die Lebenszyklus-Signale (Start/Verlassen, Vordergrund/
  Hintergrund), an die sich der PowerManager anhängt; dieses Feature führt keine eigene
  Szenenerkennung jenseits dieser Signale ein.
- „Weiches Dimmen" bedeutet eine kurze, ruckelfreie Übergangsanimation; konkrete Dauer/Schritte sind
  feste, ruhige v1-Defaults und nicht nutzerkonfigurierbar (Konfiguration → ThemeSettings #5).
- Die App läuft auf iPadOS 18+; Helligkeit und Leerlauf-Timer sind nur im Vordergrund kontrollierbar
  (Plattformgrenze, Konstitution V).

### Out of Scope

- Fernsteuerung der Helligkeit / Pause / Album über externe Systeme (→ HAControl #6).
- Zeitpläne/Automationen (z. B. „nachts automatisch dimmen nach Uhrzeit") und Theme-/Einstellungs-UI
  (→ ThemeSettings #5).
- Physisches Abschalten des Displays (von iOS nicht möglich — nur Dimmen auf nahe 0).
