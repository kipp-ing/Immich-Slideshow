<!--
SYNC IMPACT REPORT
==================
Version change: (template) → 1.0.0
Bump rationale: Initial ratification of the project constitution (MAJOR baseline).

Principles defined (7):
  I.   Test-First (NON-NEGOTIABLE)
  II.  Modulare Isolation
  III. Keine Secrets im Klartext (NON-NEGOTIABLE)
  IV.  Sicherheit der Transportschicht
  V.   Plattformgrenzen respektieren
  VI.  Verifizierbare Akzeptanzkriterien
  VII. Schlicht und hell als Default

Added sections:
  - Zusätzliche Constraints (Tech-Stack & Architektur)
  - Entwicklungs-Workflow (TDD-Loop & SDD via Spec Kit)
  - Governance

Removed sections: none (template baseline replaced)

Templates requiring updates:
  ✅ .specify/templates/plan-template.md   (reviewed — generic Constitution Check gate compatible)
  ✅ .specify/templates/spec-template.md   (reviewed — requirements/acceptance sections align)
  ✅ .specify/templates/tasks-template.md  (reviewed — TDD task ordering align)

Follow-up TODOs: none
-->

# ImmichSlideshow Constitution

ImmichSlideshow ist eine eigenständige iPad-App, die Immich ausschließlich als Datenquelle
über dessen REST-API nutzt. Sie ist **kein Fork** der offiziellen Immich-App und unterhält
keine Abhängigkeit zur offiziellen Immich-Codebasis. Die folgenden Prinzipien sind verbindlich.

## Core Principles

### I. Test-First (NON-NEGOTIABLE)
Jede Funktionalität beginnt mit einem fehlgeschlagenen Test. Es wird KEIN Implementierungscode
geschrieben, bevor ein zugehöriger Test existiert und nachweislich rot ist. Der Zyklus
Red → Green → Refactor wird strikt eingehalten: zuerst der rote Test, dann die minimale
Implementierung bis grün, danach Refactor bei grün bleibenden Tests.

**Rationale:** Ein Test, der nie rot war, beweist nichts. Test-First erzwingt überprüfbares
Verhalten und verhindert nachträglich angepasste Scheinabsicherung.

### II. Modulare Isolation
Jedes Modul ist über ein Protokoll von seinen Abhängigkeiten entkoppelt — insbesondere Netzwerk
(`ImmichAPI`), Keychain (`KeychainStore`), MQTT (`MQTTTransport`) und Zeit/Timer. Tests laufen
ohne echten Server, Broker oder Keychain gegen Mocks/Fakes. Versteckte Singletons sind untersagt;
Abhängigkeiten werden injiziert.

**Rationale:** Isolation macht jedes Modul deterministisch testbar und hält die Suite schnell und
unabhängig von externer Infrastruktur.

### III. Keine Secrets im Klartext (NON-NEGOTIABLE)
Immich-API-Key und MQTT-Credentials liegen ausschließlich im Keychain. Sie erscheinen niemals in
UserDefaults, im Quellcode, in Logs oder in committeten Dateien.

**Rationale:** Secrets im Klartext sind ein dauerhaftes Leck-Risiko, das durch keinen späteren Fix
heilbar ist; der Keychain ist die einzige zulässige Ablage.

### IV. Sicherheit der Transportschicht
TLS-Validierung wird nicht deaktiviert. Der Immich-Server hat ein gültiges Zertifikat (Standard-
URLSession ohne TLS-Ausnahme); MQTT läuft über TLS. Self-signed- oder Klartext-Verbindungen sind
ausdrücklich außerhalb des aktuellen Scopes und werden nicht durch Umgehung der Validierung
nachgebaut.

**Rationale:** Eine einmal deaktivierte TLS-Prüfung untergräbt die Sicherheit aller Verbindungen;
solange ein gültiges Zertifikat vorliegt, gibt es keinen Grund dafür.

### V. Plattformgrenzen respektieren
Die App entwirft keine Features gegen die Grenzen von iOS/iPadOS an. Sie schaltet das Display nicht
physisch aus (nur Helligkeit gegen ~0 dimmen) und steuert Helligkeit sowie Idle-Timer nur im
Vordergrund; geht die App in den Hintergrund, gibt iOS die Kontrolle zurück.

**Rationale:** Gegen Plattformgrenzen programmierter Code ist fragil und erzeugt falsche Erwartungen;
Features werden innerhalb der real verfügbaren Kontrolle entworfen.

### VI. Verifizierbare Akzeptanzkriterien
Jede Spec endet mit prüfbaren Kriterien: konkrete Eingaben/Ausgaben und explizite Fehlerfälle,
nicht vage Qualitätswünsche. Jedes Kriterium muss durch einen Test abbildbar sein.

**Rationale:** Nur überprüfbare Kriterien lassen sich abnehmen; vage Wünsche erzeugen Streit statt
einer roten oder grünen Anzeige.

### VII. Schlicht und hell als Default
UI-Voreinstellungen sind ruhig und hell. Zusatzfunktionen (Übergänge, Ken-Burns, Overlays) sind
opt-in und werden nicht aufgedrängt. Default: hell, ruhig, kein Overlay.

**Rationale:** Eine Slideshow soll zuerst die Bilder zeigen; Effekte sind Würze, kein Grundzustand.

## Zusätzliche Constraints (Tech-Stack & Architektur)

- Plattform: iPadOS 18+ (iPhone optional). Sprache: Swift 6. UI: SwiftUI. Architektur: MVVM mit
  `@Observable`. Package Manager: Swift Package Manager.
- Test-Framework: Swift Testing (`@Test`); XCTest nur, wo zwingend nötig.
- Builds und Tests laufen über XcodeBuildMCP; roher `xcodebuild`-Output wird nicht von Hand geparst.
- API-Pfade werden gegen die OpenAPI-Spec der laufenden Immich-Version geprüft
  (`/api/server/version`), nicht aus alten Tutorials übernommen.

## Entwicklungs-Workflow (TDD & SDD)

- **SDD via Spec Kit:** Kein Feature-Code ohne vorherige Spec + Plan + Tasks. Der Loop lautet
  constitution → specify → clarify → checklist → plan → tasks → analyze → implement.
- **TDD pro Task:** Red → Green → Refactor (siehe `tdd-workflow.md`). Kein Sprung über mehrere Tasks.
- **Definition of Done pro Task:** Tests grün über XcodeBuildMCP; keine Secrets im Code; Constraints
  aus `CLAUDE.md` eingehalten; bei UI rendert die Preview ohne Crash.

## Governance

Diese Konstitution hat Vorrang vor allen anderen Praktiken. Änderungen erfordern eine dokumentierte
Begründung im Sync Impact Report und eine Versionsanpassung nach SemVer:

- **MAJOR:** rückwärtsinkompatible Entfernung oder Neudefinition von Prinzipien/Governance.
- **MINOR:** neues Prinzip/neuer Abschnitt oder materiell erweiterte Vorgaben.
- **PATCH:** Klarstellungen, Wortlaut, Tippfehler, nicht-semantische Verfeinerungen.

Jede Spec, jeder Plan und jeder Review prüft die Einhaltung dieser Prinzipien. Abweichungen müssen
explizit begründet werden; eine NON-NEGOTIABLE-Verletzung blockiert den Merge. Laufende
Entwicklungs-Leitlinien stehen in `CLAUDE.md` und `tdd-workflow.md`.

**Version**: 1.0.0 | **Ratified**: 2026-06-17 | **Last Amended**: 2026-06-17
