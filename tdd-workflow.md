# TDD-Workflow

Verbindlicher Loop für jedes Feature. Claude Code fährt ihn pro Task aus `tasks.md`.

## Red → Green → Refactor
1. **Red** — Test schreiben, der das gewünschte Verhalten beschreibt. Über XcodeBuildMCP ausführen → muss **fehlschlagen** (sonst testet er nichts).
2. **Green** — minimale Implementierung, bis der Test grün ist. Nicht mehr als nötig.
3. **Refactor** — aufräumen, Tests bleiben grün. Erst dann zum nächsten Task.

Keine Implementierung ohne vorher fehlgeschlagenen Test. Kein Sprung über mehrere Tasks.

## Teststufen
- **Unit** (Schwerpunkt): Logik pro Modul, isoliert. Netzwerk/MQTT/Keychain hinter Protokollen mocken.
- **Integration** (wenige, gezielt): echter Immich-Server / echter Broker. Nur lokal, nicht in jedem Lauf.
- **UI/Preview**: SwiftUI-Previews zur visuellen Kontrolle (Apple-Xcode-MCP), keine Pflicht-Assertions.

## Testbarkeit erzwingen
- `ImmichAPI`-Protokoll → Live-Impl (URLSession) + Mock-Impl (feste Antworten) für Tests.
- `KeychainStore`-Protokoll → echtes Keychain + In-Memory-Fake.
- `MQTTTransport`-Protokoll → echter Client + Fake, der published Nachrichten aufzeichnet.
- Zeit/Timer injizierbar (kein `Date()` direkt in der Logik), damit Slideshow-Timing deterministisch testbar ist.

## Pro Modul: was zuerst getestet wird
- **ImmichClient**: Album-JSON → Modelle parsen; Auth-Header gesetzt; Fehlerfälle (401, Timeout).
- **SlideshowView (ViewModel)**: Reihenfolge, Mischen, Vorwärtsschalten nach Intervall, Prefetch-Auslösung.
- **Onboarding**: Schritt-Validierung; Verbindungstest-Resultat → richtiger Folgeschritt; Key landet im Keychain.
- **PowerManager**: Helligkeit clamped auf 0…1; Idle-Timer an/aus bei Start/Stop.
- **ThemeSettings**: Persistenz round-trip; Defaults korrekt.
- **HAControl**: Discovery-Payload korrekt aufgebaut; eingehender Command → richtige Aktion ausgelöst; LWT gesetzt.

## Definition of Done (pro Task)
- Test(s) grün über XcodeBuildMCP.
- Keine Secrets im Code.
- Constraints aus `CLAUDE.md` eingehalten.
- Bei UI: Preview rendert ohne Crash.
