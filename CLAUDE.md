# ImmichSlideshow

iPad-Slideshow-App für Immich. Eigenständig, **kein Fork** der offiziellen Immich-App.
Immich dient nur als Datenquelle über die REST-API.

## Quick Reference
- Platform: iPadOS 18+ (iPhone optional)
- Language: Swift 6
- UI: SwiftUI
- Architektur: MVVM mit `@Observable`
- Package Manager: Swift Package Manager
- Test-Framework: Swift Testing (`@Test`), XCTest nur wo nötig

## XcodeBuildMCP
Dieses Projekt nutzt XcodeBuildMCP für Builds, Tests und Simulator.
- Builds/Tests über die MCP-Tools ausführen, **nicht** rohes `xcodebuild` parsen.
- Bei roten Tests: Fehler aus dem strukturierten MCP-Output lesen, gezielt fixen.
- SwiftUI-Previews zur visuellen Verifikation nutzen, wenn Apple-Xcode-MCP aktiv ist.

## Arbeitsweise (verbindlich)
- **TDD**: Test zuerst (rot), dann minimale Implementierung (grün), dann Refactor. Details in `tdd-workflow.md`.
- **SDD via Spec Kit**: Kein Feature-Code ohne vorherige Spec + Plan + Tasks. Siehe `.specify/`.
- Jedes Modul ist isoliert testbar (Protokolle + Dependency Injection, keine versteckten Singletons).
- Netzwerk hinter einem Protokoll (`ImmichAPI`), damit Tests ohne echten Server laufen (Mock/Stub).

## Orchestrierung: Claude orchestriert, Codex implementiert
Für nicht-triviale Implementierungsarbeit gilt ein Zwei-Modell-Workflow:

- **Claude (du) orchestriert und urteilt.** Aufgabe lesen, entscheiden was delegiert wird, Briefing
  schreiben, Codex' Diff reviewen, das Verifikations-Gate verantworten. Selbst möglichst wenig Code
  schreiben — die Implementierung wird delegiert.
- **Codex ist die Implementierungs-Armee.** Codex-Agenten (über die `codex-agent`-CLI des Plugins
  `codex-orchestrator`, oder `/codex:rescue` für kleine/schnelle Aufgaben) implementieren gegen ein
  Briefing, fahren ihre eigenen Unit-Tests und committen ihre Arbeit selbst.
- **Cross-Model-Review.** `/codex:review` bzw. `/codex:adversarial-review` für einen unabhängigen
  Blick — ein anderes Modell prüft Code, den es nicht selbst erzeugt hat.

### Wann delegieren
Gut umreißbare Implementierungsarbeit delegieren: eine Feature-Scheibe, ein Bugfix, ein Refactor mit
klarem Ziel. **Inline behalten:**
- Test-*Design* für geteilten/nebenläufigen Zustand, Races, Timing (z. B. SlideshowView-Timer)
- Sicherheitskritisches/Querschnittliches: Keychain, TLS, Onboarding-Verdrahtung, App-Entry
- SwiftUI/UI, die zur Verifikation den Simulator braucht (Codex testet nur Logik auf dem Host)
- Alles, was die 2-Runden-Grenze unten reißt — dann selbst zu Ende bringen

### Briefing-Workflow
Vor dem Delegieren:

    .claude/scripts/codex-brief.sh "<Task-Beschreibung>" <datei1> <datei2> ...

Das rendert ein Briefing nach stdout: Aufgabe, In-Scope-Dateien, aktueller `git status` /
`git diff --stat`, Verifikationsbefehl und die Hausregeln. `codex-agent start` nimmt seinen Prompt
als Positionsargument (nicht via stdin), also per Command-Substitution übergeben:

    codex-agent start "$(.claude/scripts/codex-brief.sh "..." Packages/ImmichClient/Sources/ImmichClient/ImmichClient.swift)" --map -s workspace-write

`--map` injiziert `docs/CODEBASE_MAP.md`. Diese Datei wird **bei jedem Session-Start automatisch lean
neu generiert** (`.claude/scripts/build-map.sh`, deterministisch, kein LLM — per `SessionStart`-Hook in
`.claude/settings.json`; die Datei ist git-ignored). Für die reichere, narrierte Variante bei Bedarf
manuell `/cartographer` laufen lassen (token-intensiv — Claude startet das nie selbst).
`--dry-run` zeigt den Prompt vorab, ohne einen Agenten zu starten.

### Codex-Coding-Session (Sollablauf)
1. **Map** — automatisch beim Session-Start (`build-map.sh`); sonst manuell `/cartographer`.
2. **Briefing** — `codex-brief.sh` rendern, `codex-agent start ... --map` (Map wird injiziert).
3. **Implementieren** — Codex gegen das Briefing (Hausregeln unten, 2-Runden-Grenze).
4. **Review** — am Ende `/codex:review` (Cross-Model). Optional als Stop-Gate via `/codex:setup`.

### Hausregeln (nicht verhandelbar)
- **TDD zuerst:** roter Test vor Implementierung (Konstitution, NON-NEGOTIABLE).
- **Nur die im Briefing gelisteten Dateien anfassen.** Sonst stoppen und zurückmelden.
- **Keine Secrets im Code/UserDefaults/Logs; TLS nicht deaktivieren** (Konstitution III/IV).
- **Nicht anfassen:** `.specify/**`, `specs/**`, `*.xcodeproj/project.pbxproj` — außer ausdrücklich in Scope.
- **Stagen nur mit expliziten Pfaden** (`git add <pfad>`), nie `-A`/`.`. Bei `.git/index.lock`: uncommitted lassen und melden.
- **Codex: nur Unit-Tests** (`swift test` auf dem Host) — keine Simulator-/Integrationstests.
- **Harte 2-Runden-Grenze:** eine Implement-Runde + eine Fix-Runde. Sonst inline fertigstellen.
- **Bulk-Lesen großer Codex-Diffs/Logs an einen `Explore`-Subagenten** delegieren, nicht direkt `Read`.

### Verifikations-Gate (von Claude verantwortet)
- Build + Tests über **XcodeBuildMCP** (Swift Testing) — der primäre Gate.
- Codex liefert grüne `swift build`/`swift test` (Host, Unit only); Claude verifiziert App-Target,
  Simulator und UI/Preview zusätzlich über XcodeBuildMCP.

## Module
1. **ImmichClient** — REST gegen Immich. Auth über Header `x-api-key`. Endpoints: Albumliste, Album-Assets, Asset-Preview-Thumbnail. URLSession.
2. **SlideshowView** — Vollbild, ein Asset, Timer, Fade. Prefetch der nächsten 1–2 Bilder. Begrenzter Bild-Cache.
3. **Onboarding** — 3 Schritte: Server-URL → API-Key → Album. API-Key im **Keychain**, nie UserDefaults.
4. **PowerManager** — `isIdleTimerDisabled` während Slideshow; `UIScreen.brightness` (0.0–1.0).
5. **ThemeSettings** — Übergang, Dauer, Ken-Burns, Hintergrund, Uhr-Overlay. In UserDefaults. Default: hell, ruhig, kein Overlay.
6. **HAControl** — MQTT über **TLS** zum vorhandenen Broker. HA-Discovery (light/select/switch + LWT-Availability). Steuert Helligkeit, Album, Pause/Play fern.

## Constraints (harte Grenzen, nicht dagegen anprogrammieren)
- iOS-App kann das Display **nicht physisch ausschalten** — nur Helligkeit ~0 dimmen.
- Helligkeit/Idle-Timer wirken **nur im Vordergrund**. Geht die App in den Hintergrund, gibt iOS die Kontrolle zurück.
- Aktueller Stand: Immich-Server hat **gültiges** Zertifikat → Standard-URLSession ohne TLS-Ausnahme. Self-signed/lokale Downgrades sind **bewusst nicht** im Scope (kommen später).
- API-Pfade gegen die OpenAPI-Spec der laufenden Immich-Version prüfen (`/api/server/version`). Nicht auf Pfade aus alten Tutorials verlassen.

## Verbote
- Keine Secrets im Code oder in UserDefaults. API-Key + MQTT-Credentials → Keychain.
- Keine TLS-Validierung deaktivieren (solange gültiges Zert vorhanden ist).
- Keine Abhängigkeit zur offiziellen Immich-Codebasis.

<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan:
`specs/009-connection-settings/plan.md`
<!-- SPECKIT END -->
