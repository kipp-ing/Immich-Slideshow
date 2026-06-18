# Feature Specification: SlideshowView (Vollbild-Diashow)

**Feature Branch**: `003-slideshow`

**Created**: 2026-06-18

**Status**: Draft

**Input**: User description: "SlideshowView — Vollbild-Diashow für ein Immich-Album. Zeigt ein Asset zur Zeit im Vollbild, automatischer Timer-Vorlauf mit Fade-Übergang, Prefetch der nächsten 1–2 Bilder, begrenzter Bild-Cache. Datenquelle: das im Onboarding gewählte Album über ImmichClient (Album-Assets + Asset-Preview-Thumbnail)."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Album als Vollbild-Diashow ansehen (Priority: P1) 🎯 MVP

Nach abgeschlossenem Onboarding öffnet die App direkt die Diashow des gewählten Albums. Die Bilder
des Albums erscheinen nacheinander, jeweils einzeln im Vollbild. Nach einer festen Anzeigedauer
wechselt die App automatisch zum nächsten Bild mit einem sanften Überblend-Übergang. Ist das letzte
Bild erreicht, beginnt die Diashow wieder von vorn (Endlosschleife) — die App ist als dauerhaft
laufender Bilderrahmen gedacht.

**Why this priority**: Dies ist der eigentliche Zweck der App. Ohne die laufende Diashow liefert die
abgeschlossene Einrichtung keinen Nutzen. Das ist das MVP dieses Features.

**Independent Test**: Mit einer gemockten Datenquelle (Album mit mehreren Bildern) die Diashow
starten und prüfen, dass das erste Bild im Vollbild erscheint, nach Ablauf der Anzeigedauer das
zweite Bild gezeigt wird und nach dem letzten Bild wieder das erste folgt.

**Acceptance Scenarios**:

1. **Given** ein gewähltes Album mit mindestens einem Bild, **When** die Diashow startet, **Then** wird das erste Bild des Albums formatfüllend im Vollbild angezeigt.
2. **Given** ein angezeigtes Bild, **When** die feste Anzeigedauer abläuft, **Then** wird mit einem Überblend-Übergang zum nächsten Bild des Albums gewechselt.
3. **Given** das letzte Bild des Albums wird angezeigt, **When** die Anzeigedauer abläuft, **Then** wird wieder das erste Bild des Albums angezeigt (Endlosschleife).
4. **Given** das Album enthält genau ein Bild, **When** die Anzeigedauer abläuft, **Then** bleibt dasselbe Bild ohne Fehler sichtbar.

---

### User Story 2 - Flüssiger Wechsel ohne Ladeflackern (Priority: P2)

Der Wechsel zwischen Bildern erfolgt ohne sichtbares Laden, Ruckeln oder leere Zwischenzustände.
Das jeweils nächste Bild (1–2 voraus) wird im Hintergrund vorgeladen, bevor es an der Reihe ist.
Bereits gezeigte Bilder werden begrenzt zwischengespeichert, damit der Speicher im Dauerbetrieb
nicht unbegrenzt wächst.

**Why this priority**: Eine Diashow, die bei jedem Wechsel kurz lädt oder flackert, wirkt unruhig
und widerspricht dem ruhigen Default (Konstitution VII). Setzt US1 voraus, ist aber unabhängig
testbar.

**Independent Test**: Mit einer gemockten, verzögerten Datenquelle prüfen, dass das nächste Bild
bereits geladen ist, wenn der Wechsel ausgelöst wird (kein Lade-Roundtrip im Moment des Wechsels),
und dass der Cache eine definierte Obergrenze nicht überschreitet.

**Acceptance Scenarios**:

1. **Given** eine laufende Diashow, **When** das aktuelle Bild angezeigt wird, **Then** ist das nächste Bild (mindestens das unmittelbar folgende) bereits vorab geladen.
2. **Given** der Wechsel zum nächsten Bild wird ausgelöst, **When** dieses Bild bereits vorgeladen ist, **Then** erscheint es ohne erneuten Ladevorgang sofort.
3. **Given** eine über viele Bilder laufende Diashow, **When** weiter geladen wird, **Then** überschreitet die Zahl der gleichzeitig im Speicher gehaltenen Bilder eine feste Obergrenze nicht (älteste Einträge werden verworfen).

---

### User Story 3 - Robust gegenüber leeren Alben und Ladefehlern (Priority: P3)

Lässt sich ein einzelnes Bild nicht laden, überspringt die Diashow es und fährt fort, statt
anzuhalten oder abzustürzen. Ist das gewählte Album leer oder die Assetliste nicht abrufbar, zeigt
die App einen schlichten, verständlichen Hinweis statt eines leeren oder fehlerhaften Bildschirms.

**Why this priority**: Im unbeaufsichtigten Dauerbetrieb darf ein einzelner Fehler die Anzeige nicht
dauerhaft blockieren. Wichtig für Verlässlichkeit, aber nicht für den ersten funktionsfähigen
Durchlauf.

**Independent Test**: Mit einer gemockten Datenquelle, die für ein bestimmtes Bild einen Fehler
liefert, prüfen, dass dieses Bild übersprungen und das nächste angezeigt wird; mit einem leeren
Album prüfen, dass ein Hinweis statt eines leeren Vollbilds erscheint.

**Acceptance Scenarios**:

1. **Given** eine laufende Diashow, **When** ein einzelnes Bild nicht geladen werden kann, **Then** wird dieses Bild übersprungen und das nächst-ladbare Bild angezeigt.
2. **Given** ein leeres Album, **When** die Diashow startet, **Then** erscheint ein schlichter Hinweis (kein leerer Vollbildschirm, kein Absturz).
3. **Given** die Assetliste des Albums kann nicht abgerufen werden, **When** die Diashow startet, **Then** erscheint ein verständlicher Fehlerhinweis mit der Möglichkeit, es erneut zu versuchen.

---

### Edge Cases

- **Album enthält Videos oder nicht-Bild-Assets**: Solche Assets werden in v1 übersprungen; nur Standbilder werden angezeigt (siehe Assumptions).
- **Album mit sehr vielen Bildern**: Speicher bleibt durch den begrenzten Cache stabil; es werden nicht alle Bilder gleichzeitig gehalten.
- **Album wird leer, nachdem die Diashow lief** (alle Assets entfernt): Beim nächsten Durchlauf greift der Leer-Hinweis aus US3.
- **Sehr langsame Verbindung**: Der Wechsel hängt nicht an einem fehlenden Prefetch; ist das nächste Bild noch nicht bereit, wird der Übergang erst beim Vorliegen des Bildes vollzogen, ohne die laufende Anzeige einzufrieren.
- **App im Hintergrund / Rückkehr in den Vordergrund**: Der Timer-Vorlauf läuft nur im Vordergrund (Konstitution V); bei Rückkehr setzt die Diashow ihren Lauf fort.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Das System MUSS die Assetliste des im Onboarding gewählten Albums über die bestehende Datenquelle laden.
- **FR-002**: Das System MUSS jeweils genau ein Bild formatfüllend im Vollbild anzeigen.
- **FR-003**: Das System MUSS nach einer festen Anzeigedauer automatisch zum nächsten Bild wechseln.
- **FR-004**: Der Wechsel zwischen Bildern MUSS mit einem Überblend-Übergang (Fade) erfolgen.
- **FR-005**: Das System MUSS am Ende der Liste wieder beim ersten Bild fortsetzen (Endlosschleife).
- **FR-006**: Das System MUSS die jeweils nächsten 1–2 Bilder vorab laden, bevor sie angezeigt werden, sodass beim Wechsel kein sichtbarer Ladevorgang entsteht.
- **FR-007**: Das System MUSS die Zahl der gleichzeitig im Speicher gehaltenen geladenen Bilder auf eine feste Obergrenze begrenzen und älteste Einträge verwerfen.
- **FR-008**: Das System MUSS ein einzelnes nicht-ladbares Bild überspringen und mit dem nächsten fortfahren, ohne anzuhalten oder abzustürzen.
- **FR-009**: Das System MUSS bei leerem Album einen schlichten Hinweis anzeigen statt eines leeren Vollbilds.
- **FR-010**: Das System MUSS bei nicht abrufbarer Assetliste einen verständlichen Fehlerhinweis mit Wiederholmöglichkeit anzeigen.
- **FR-011**: Das System MUSS nicht-Bild-Assets (z. B. Videos) beim Aufbau der Diashow-Reihenfolge überspringen (nur Standbilder in v1).
- **FR-012**: Der Timer-Vorlauf MUSS nur im Vordergrund laufen; im Hintergrund pausiert er und wird bei Rückkehr fortgesetzt (Plattformgrenze, Konstitution V).
- **FR-013**: Die Diashow MUSS ohne Bedien-Overlays/Effekte als Default starten (ruhig und schlicht, Konstitution VII); Anzeigedauer und Übergänge werden zunächst über einen festen Default bestimmt (Konfigurierbarkeit ist Sache des späteren ThemeSettings-Moduls).

### Key Entities *(include if feature involves data)*

- **Album-Asset**: Ein einzelnes Bild des gewählten Albums, identifiziert über seine Asset-ID; Quelle für das im Vollbild dargestellte Vorschaubild. Reihenfolge entspricht der vom Album gelieferten Reihenfolge.
- **Diashow-Zustand**: Aktueller Index/aktuelles Bild, Lauf/Pause-Zustand und die Reihenfolge der anzuzeigenden Bilder.
- **Bild-Cache**: Begrenzte Menge bereits geladener Bilder samt Verdrängung der ältesten Einträge.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Nach Start der Diashow erscheint das erste Bild des gewählten Albums im Vollbild, ohne dass ein weiterer Bedienschritt nötig ist.
- **SC-002**: Über mindestens einen vollständigen Durchlauf des Albums hinweg wechselt jedes Bild nach der festen Anzeigedauer automatisch zum nächsten und setzt nach dem letzten beim ersten fort.
- **SC-003**: Beim Wechsel zum nächsten Bild ist kein leerer Zwischenzustand und kein Ladeflackern sichtbar (das nächste Bild ist vorgeladen).
- **SC-004**: Im Dauerbetrieb über viele Bildwechsel überschreitet die Zahl der gleichzeitig gehaltenen Bilder die festgelegte Obergrenze nicht.
- **SC-005**: Ein einzelnes nicht-ladbares Bild führt nicht zum Stillstand: die Diashow zeigt das nächste ladbare Bild.
- **SC-006**: Bei leerem Album bzw. nicht abrufbarer Assetliste erscheint ein verständlicher Hinweis statt eines leeren oder abgestürzten Bildschirms.

## Assumptions

- **Datenquelle**: Die Diashow nutzt die bestehende `ImmichAPI`-Datenquelle (Album-Assets + Asset-Preview-Thumbnail) und das im Onboarding gewählte Album. Vollauflösende Originale sind in v1 nicht erforderlich — das Preview-Thumbnail genügt für die Vollbildanzeige auf dem iPad.
- **Reihenfolge**: Bilder werden in der vom Album gelieferten Reihenfolge angezeigt (keine Zufallswiedergabe). Shuffle ist Sache des späteren ThemeSettings-Moduls.
- **Anzeigedauer & Übergang**: Ein fester Default (einige Sekunden pro Bild, sanftes Fade) gilt für v1. Konfigurierbarkeit (Dauer, Ken-Burns, Hintergrund, Uhr-Overlay) liegt im ThemeSettings-Modul (#5) und ist nicht Teil dieses Features.
- **Asset-Typen**: Nur Standbilder. Videos und sonstige nicht-Bild-Assets werden in v1 übersprungen.
- **Bediensteuerung**: Manuelle Bedienung (Tippen für Pause/Vor/Zurück) ist in v1 nicht im Scope; Pause/Play und Albumwechsel aus der Ferne sind Sache des späteren HAControl-Moduls (#6). Helligkeit/Idle-Timer sind Sache des PowerManager-Moduls (#4).
- **Plattform**: Vordergrund-Betrieb auf iPadOS 18+; Hintergrundverhalten folgt den iOS-Grenzen (Konstitution V).
- **Voraussetzung**: Abgeschlossenes Onboarding (Feature 002) liefert Server-URL, API-Key (Keychain) und Album-ID. ImmichClient (Feature 001) liefert Assetliste und Preview-Bilder.
