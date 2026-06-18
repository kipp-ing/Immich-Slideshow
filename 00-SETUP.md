# Setup — Immich Slideshow (Claude Code + XcodeBuildMCP + Spec Kit)

Reihenfolge zum Loslegen auf dem Mac. Alles, was hier steht, läuft *dort* — nicht im Chat.

## Voraussetzungen (dein Stand)
- Dev-Account vorhanden ✓
- Immich-Server per HTTPS mit **gültigem** Zertifikat ✓ (lokale Downgrades/self-signed kommen später)
- MQTT-Broker mit **TLS** vorhanden ✓
- Xcode 26.3+ (für Apple Xcode-MCP + Agent-Previews)
- Node (für `npx`), Python `uv` (für Spec Kit)

## 1. Xcode-Projekt anlegen
In Xcode: neues App-Projekt, SwiftUI, Ziel **iPadOS** (iPhone optional). Name z.B. `ImmichSlideshow`.
Minimum Deployment auf das Target setzen, das in `CLAUDE.md` steht (Default iOS/iPadOS 18).
Projekt schließen — ab hier arbeitet Claude Code im Terminal.

## 2. Claude Code im Projektordner starten
```
cd ~/Developer/ImmichSlideshow
claude
```

## 3. XcodeBuildMCP anbinden (autonome Builds/Tests)
```
claude mcp add --transport stdio XcodeBuildMCP --scope project \
  --env INCREMENTAL_BUILDS_ENABLED=true \
  --env XCODEBUILDMCP_DYNAMIC_TOOLS=true \
  -- npx -y xcodebuildmcp@latest
```
Optional zusätzlich Apples nativer Xcode-MCP (ab Xcode 26.3) für SwiftUI-Preview-Verifikation —
prüfe den exakten `xcrun mcpbridge`-Befehl in deiner Xcode-Version, der ändert sich noch.

## 4. Dateien aus diesem Bundle ins Projekt kopieren
- `CLAUDE.md` → Projekt-Root
- `docs/` → Projekt-Root/docs/

`CLAUDE.md` wird von Claude Code beim Start automatisch geladen.

## 5. Spec Kit initialisieren
```
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
specify init --here --ai claude
```
Das legt `.specify/` (Konstitution, Templates) + die Claude-Skills an.
**Nicht** von Hand nachbauen — Spec Kit verwaltet das selbst.

## 6. Konstitution + erste Spec einspielen
Inhalte aus diesem Bundle in die Spec-Kit-Commands einfügen:
- `docs/constitution-input.md` → Inhalt für `/speckit.constitution`
- `docs/spec-input-immichclient.md` → Inhalt für `/speckit.specify` (erstes Feature)

Dann der Spec-Kit-Loop:
`constitution → specify → clarify → checklist → plan → tasks → analyze → implement`

## 7. Reihenfolge der Features (= Reihenfolge der Specs)
1. **ImmichClient** (Server verbinden, Albumliste, Assets laden) ← Machbarkeits-Test
2. **SlideshowView** (Vollbild, Timer, Fade)
3. **Onboarding** (3 Schritte, Keychain)
4. **PowerManager** (Idle-Timer, Helligkeit)
5. **Theme-Settings**
6. **HAControl** (MQTT/TLS, Discovery) ← größter Brocken, zuletzt

Erst wenn 1+2 grün laufen, lohnt der Rest. Siehe `docs/tdd-workflow.md`.
