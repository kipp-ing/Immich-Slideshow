# Handover — ImmichSlideshow

**Date**: 2026-06-17
**Branch**: `001-immich-client` (feature branch, off `main`)
**Phase**: Spec Kit document loop **complete**; ready to start TDD implementation at task **T001**.

---

## TL;DR — what to do next

1. **Restart Claude Code** so the new MCP server + `/speckit-*` skills register
   (they were installed mid-session and aren't active in the current process).
2. Confirm **XcodeBuildMCP** connects, then build the package skeleton.
3. Start the TDD loop at **`specs/001-immich-client/tasks.md` → T001** (red → green → refactor).
   MVP = User Story 1 (`albums()`), tasks T001–T013.

---

## Environment state

| Item | State |
|------|-------|
| Xcode | **26.5** active (`xcode-select -p` → `/Applications/Xcode.app/Contents/Developer`) ✅ |
| xcodebuild | works (Build 17F42) ✅ |
| Node / npx | v26 / 11.12 ✅ |
| uv / specify CLI | installed ✅ |
| Spec Kit | initialized (`.specify/`, skills in `.claude/skills/speckit-*`) ✅ |
| XcodeBuildMCP | configured in `.mcp.json`; **failed to connect in this session** because the toolchain pointed at Command Line Tools. That's now fixed → should connect after a **Claude Code restart**. ⚠️ verify |
| Google Drive MCP | "needs authentication" — unrelated, ignore. |

**Important**: The `/speckit-*` commands are installed as **skills**, but skills added mid-session
don't register until restart. They were executed this session by **reading the SKILL.md and running
the workflow directly** — that's a valid fallback if they still don't appear after restart.

---

## What's done (Spec Kit loop)

All on branch `001-immich-client`:

- **Constitution** → `.specify/memory/constitution.md` (v1.0.0, German, 7 principles incl. two
  NON-NEGOTIABLE: Test-First, No-Plaintext-Secrets).
- **Feature 1 spec** → `specs/001-immich-client/`:
  - `spec.md` — 3 user stories (Albums P1, Assets P1, Preview P2), 10 FRs, SC-001…SC-006, out-of-scope.
  - `plan.md` — Swift 6 SPM module; **Constitution Check = PASS**.
  - `research.md` — Immich API path decisions (**see verification note below**).
  - `data-model.md` — `ServerConfig`, `Album`, `Asset`, `ImmichError`.
  - `contracts/ImmichAPI.md` — `ImmichAPI` + `HTTPTransport` protocols, invariants INV-1…INV-6.
  - `quickstart.md` — SC → test mapping.
  - `tasks.md` — **25 tasks, TDD-ordered** (the implementation backlog).
  - `checklists/requirements.md` — all items pass.
- `CLAUDE.md` SPECKIT marker updated to point at `specs/001-immich-client/plan.md`.

Optional steps skipped: `/speckit-clarify` (spec was clean, no open clarifications),
`/speckit-checklist`, `/speckit-analyze` (can run before implement if extra rigor wanted).
Optional `after_specify`/`after_plan` agent-context hooks: plan reference was updated manually.

---

## Architecture decision (baked into the plan)

Foundation-only **local SPM package** `Packages/ImmichClient/` (does not yet exist — created by T001).
Logic sits behind an `ImmichAPI` protocol with an **injectable `HTTPTransport`**, so the entire module
is tested against a `MockTransport` with **no real server** (satisfies Test-First + Modular Isolation).
App target wires the package in at the very end (T025), no UI in this feature.

Planned layout (created during implementation):
```
Packages/ImmichClient/
├── Package.swift
├── Sources/ImmichClient/{ServerConfig,Models,ImmichError,HTTPTransport,ImmichAPI,ImmichClient}.swift
└── Tests/ImmichClientTests/{MockTransport,AlbumTests,AssetTests,PreviewTests,ErrorTests}.swift
```

---

## Task backlog (`specs/001-immich-client/tasks.md`)

- **Phase 1 Setup** T001–T003 — SPM package skeleton, empty build green.
- **Phase 2 Foundational** T004–T008 — `ServerConfig`, `ImmichError`, `HTTPTransport`+`URLSessionTransport`, `MockTransport`, client/protocol skeleton.
- **Phase 3 US1 (P1, MVP)** T009–T013 — red tests → `albums()`, verify `x-api-key` header.
- **Phase 4 US2 (P1)** T014–T017 — `assets(albumID:)`, empty album → `[]`.
- **Phase 5 US3 (P2)** T018–T019 — `preview(assetID:)` via `thumbnail?size=preview`.
- **Phase 6 Polish** T020–T025 — error-mapping tests (401/timeout/invalid) + impl, quickstart validation, wire package into app target.

Per task: write the test, **run it red via XcodeBuildMCP**, minimal impl to green, refactor. Commit per task/group.

---

## ⚠️ Open items / cautions for the implementer

1. **Verify Immich API paths against the live server before T012/T017/T019.** research.md uses the
   current plural routes (`/api/albums`, `/api/albums/{id}`, `/api/assets/{id}/thumbnail?size=preview`,
   auth header `x-api-key`) but the constitution (Principle IV) **requires** checking
   `GET /api/server/version` + `/api/openapi.json` on the running instance. Do not guess; correct
   research.md if they differ.
2. **Never log the API key** (Constitution III, NON-NEGOTIABLE).
3. **No TLS exceptions** — standard URLSession only; server has a valid cert (Constitution IV).
4. **Nothing is committed yet.** All files (incl. `CLAUDE.md`, `.specify/`, `specs/`, the bundle docs)
   are untracked on `001-immich-client`. Decide whether to commit the spec artifacts before coding.
   Note: Spec Kit suggested adding `.claude/` to `.gitignore` (it can hold credentials).

---

## Open task list (tracker)

- [x] Fix xcode-select → Xcode.app
- [x] Initialize Spec Kit
- [x] Constitution
- [x] ImmichClient spec
- [x] Plan
- [x] Tasks
- [ ] **Verify XcodeBuildMCP build/test works** (after restart) — task #3
- [ ] **Implement ImmichClient via TDD** (T001…T025) — task #8
