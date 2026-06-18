#!/usr/bin/env bash
set -euo pipefail

# Rendert ein Codex-Implementierungs-Briefing: festes Template + eingebetteter
# git-Status und Diffstat.
#
# Benutzung: codex-brief.sh "<Task-Beschreibung>" [datei1] [datei2] ...
# Gelistete Dateien sind die In-Scope-Liste. Alles andere ist Out of Scope.
#
# Optional: VERIFY_PACKAGE setzt das zu bauende/testende Swift-Paket
# (Default: Packages/ImmichClient).

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 \"<Task-Beschreibung>\" [datei1] [datei2] ..." >&2
  exit 1
fi

TASK="$1"
shift
FILES=("$@")
VERIFY_PACKAGE="${VERIFY_PACKAGE:-Packages/ImmichClient}"

cat <<EOF
# Codex-Implementierungs-Briefing

## Aufgabe

$TASK

## In-Scope-Dateien

EOF

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "(keine angegeben — Scope vor dem Editieren mit dem Orchestrator klären)"
else
  for f in "${FILES[@]}"; do
    echo "- $f"
  done
fi

cat <<'EOF'

## Out of Scope

Alles, was oben nicht gelistet ist. Insbesondere NICHT anfassen:
- `.specify/**` und `specs/**` (Konstitution, Spec/Plan/Tasks — Governance-Artefakte)
- `*.xcodeproj/project.pbxproj` und Schemes (Projektstruktur)
- Abhängigkeiten/Versionen in `Package.swift`, sofern nicht ausdrücklich in Scope
- `CLAUDE.md`, `.claude/**`, `tdd-workflow.md`
Keine neuen Drittbibliotheken hinzufügen, sofern nicht explizit beauftragt.

## Aktueller Repo-Zustand

### git status
EOF

git status --porcelain

echo
echo "### git diff --stat"
git diff --stat

cat <<EOF

## Verifikation (Codex: nur Unit-Tests, kein Simulator)

Im Paketverzeichnis \`$VERIFY_PACKAGE\` ausführen und Erfolg bestätigen:

    swift build
    swift test

Das ImmichClient-Modul ist Foundation-only und läuft ohne Simulator auf dem Host.
Keine UI-/Integrationstests, die einen Simulator oder einen echten Server/Broker
brauchen — die deckt der Orchestrator (Claude) über XcodeBuildMCP ab.
EOF

cat <<'EOF'

## Hausregeln (nicht verhandelbar)

- **TDD zuerst (Konstitution, NON-NEGOTIABLE).** Erst den fehlschlagenden Test
  schreiben und rot sehen, dann die minimale Implementierung bis grün, dann
  Refactor. Kein Implementierungscode ohne vorher roten Test.
- **Nur die im Briefing gelisteten Dateien anfassen.** Werden weitere Dateien
  nötig, stoppen und zurückmelden statt den Scope stillschweigend auszuweiten.
- **Keine Secrets im Code/in UserDefaults/in Logs.** API-Key und
  MQTT-Credentials gehören in den Keychain. Den API-Key niemals loggen.
- **TLS-Validierung nicht deaktivieren.** Standard-URLSession über HTTPS; der
  Server hat ein gültiges Zertifikat.
- **Stagen nur mit expliziten Pfaden:** `git add <pfad>` je geänderter Datei.
  Niemals `git add -A` oder `git add .`.
- **Wenn `.git/index.lock` existiert:** Working Tree uncommitted lassen und
  zurückmelden — den Lock nicht entfernen und den Commit nicht erzwingen.
- **Nur Unit-Tests** (`swift test` auf dem Host) — keine Integrations-/UI-Tests
  und keine externen Dienste.
- **Harte 2-Runden-Grenze.** Eine Implement-Runde + eine Fix-Runde. Ist Runde
  zwei nicht grün, war die Aufgabe unterspezifiziert — dann inline zu Ende
  bringen, nicht ein drittes Mal briefen.
EOF
