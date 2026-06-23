#!/usr/bin/env bash
set -euo pipefail

# Renders a Codex implementation briefing: fixed template + embedded git
# status and diffstat.
#
# Usage: codex-brief.sh "<task description>" [file1] [file2] ...
# Listed files are the in-scope list. Everything else is out of scope.
#
# Optional: VERIFY_PACKAGE sets the Swift package to build/test
# (default: Packages/ImmichClient).

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 \"<task description>\" [file1] [file2] ..." >&2
  exit 1
fi

TASK="$1"
shift
FILES=("$@")
VERIFY_PACKAGE="${VERIFY_PACKAGE:-Packages/ImmichClient}"

cat <<EOF
# Codex Implementation Briefing

## Task

$TASK

## In-Scope Files

EOF

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "(none given — clarify scope with the orchestrator before editing)"
else
  for f in "${FILES[@]}"; do
    echo "- $f"
  done
fi

cat <<'EOF'

## Out of Scope

Everything not listed above. In particular do NOT touch:
- `.specify/**` and `specs/**` (constitution, spec/plan/tasks — governance artifacts)
- `*.xcodeproj/project.pbxproj` and schemes (project structure)
- Dependencies/versions in `Package.swift`, unless explicitly in scope
- `CLAUDE.md`, `.claude/**`, `tdd-workflow.md`
Do not add new third-party libraries unless explicitly requested.

## Current Repo State

### git status
EOF

git status --porcelain

echo
echo "### git diff --stat"
git diff --stat

cat <<EOF

## Verification (Codex: unit tests only, no simulator)

Run in the package directory \`$VERIFY_PACKAGE\` and confirm success:

    swift build
    swift test

The ImmichClient module is Foundation-only and runs without a simulator on the host.
No UI/integration tests that need a simulator or a real server/broker — the
orchestrator (Claude) covers those via XcodeBuildMCP.
EOF

cat <<'EOF'

## House Rules (non-negotiable)

- **TDD first (constitution, NON-NEGOTIABLE).** Write the failing test and see
  it red first, then the minimal implementation until green, then refactor.
  No implementation code without a previously red test.
- **Only touch files listed in the briefing.** If more files turn out to be
  needed, stop and report back instead of silently expanding scope.
- **No secrets in code/UserDefaults/logs.** The API key and MQTT credentials
  belong in the keychain. Never log the API key.
- **Don't disable TLS validation.** Standard URLSession over HTTPS; the
  server has a valid certificate.
- **Stage only with explicit paths:** `git add <path>` per changed file.
  Never `git add -A` or `git add .`.
- **If `.git/index.lock` exists:** leave the working tree uncommitted and
  report it — don't remove the lock and don't force the commit.
- **Unit tests only** (`swift test` on the host) — no integration/UI tests
  and no external services.
- **Hard 2-round limit.** One implement round + one fix round. If round two
  isn't green, the task was underspecified — finish it inline then, don't
  brief a third time.
EOF
