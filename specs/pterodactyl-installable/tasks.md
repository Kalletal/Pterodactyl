# Tasks: Pterodactyl SPK Installability

**Inputs**: `spec.md`, `plan.md`, `research.md`, `data-model.md`, `quickstart.md`, `contracts/runtime.md`  
**Prereqs**: Constitution gates satisfied; spksrc overlay already mirrored.

> Format: `[ID] [P?] [Area] Description (file paths + acceptance)`

## Phase 0 – Planning & Toolchain Alignment

- [x] T000 [PLAN] Revalidate spec vs constitution (build integrity, fidelity, security, resource, support) and confirm upstream versions (Panel 1.11.6, Wings 1.11.5, MariaDB ≥10.2, Redis 7.2). Acceptance: checklist updated, spec references removed ambiguities (done).
- [x] T001 [PLAN] Confirm Synology toolchain availability: run `scripts/package/bootstrap.sh` to verify spksrc clone succeeds with `synologytoolkit/dsm7.2:7.2-64570`. Acceptance: log snippet showing clone + overlay sync.

## Phase 1 – Build System & Dependencies

- [x] T010 [P][BUILD] Update/verify `scripts/package/build-runtime-tools.sh` to check composer v2, git, curl, tar, unzip presence and record versions in `runtime-tools/manifest.json`. Acceptance: manifest includes composer version string “Composer version 2.x”.
- [x] T011 [BUILD] Ensure `cross/pterodactyl-panel` digests/PLIST align with Panel 1.11.6 tarball (re-run checksum if upstream changed). Acceptance: `cross/pterodactyl-panel/digests` matches `sha256sum panel.tar.gz`; documented command output.
- [x] T012 [BUILD] Ensure `cross/wings` digests align with Wings 1.11.5; confirm `go build` step uses vendor modules pinned via `go.sum`. Acceptance: rebuild log snippet showing successful compile.
- [x] T013 [BUILD] Verify `spk/pterodactyl/Makefile` `SPK_DEPENDS` explicitly notes php83 requirement and optional Docker mention in README. Acceptance: diff showing dependency string (already present, but confirm docs).

## Phase 2 – Runtime / Service Surfaces

- [x] T020 [RUNTIME] Update wizard text (`spk/pterodactyl/src/wizard/*`) to mention php83 extensions, Apache usage, MariaDB/Redis minima, and CLI tools. Acceptance: install wizard JSON reflects new copy.
- [x] T021 [RUNTIME] Ensure `spk/pterodactyl/src/docker-compose.yml` comments or docs clarify Apache server usage (panel container) and ports 8080/8081. Acceptance: doc snippet referencing Apache.
- [x] T022 [RUNTIME] Confirm `panel.env.example` lists all required env vars (including composer prerequisites, MariaDB ≥10.2 mention). Acceptance: env template contains comment lines referencing requirements.
- [x] T023 [SECURITY] Extend `spk/scripts/verify-perms.sh` to optionally check composer binary presence (if accessible) and confirm directories for database/redis exist. Acceptance: script passes existing tests and fails when directories missing.

## Phase 3 – Testing & Validation

- [x] T030 [TEST] Execute `make package` end-to-end; capture `build/logs/*`, `.spk`, `.sha256`. Acceptance: attach log summary + checksums to PR.
- [ ] T031 [TEST] Install SPK on DSM VM/DS920+, run `spk/scripts/verify-perms.sh` (or manual checks) to verify ownership/perms. Acceptance: screenshot/log snippet of `[PASS] Permission layout verified`.
- [ ] T032 [TEST] Smoke-test runtime: after configuring `panel.env`, run `synopkg start pterodactyl`, ensure docker containers healthy, log lines recorded, panel accessible at 8080 via Apache. Acceptance: `docker ps` output + panel web screenshot.

## Phase 4 – Documentation & Release Notes

- [ ] T040 [DOCS] Update README/operator docs (new section) describing prerequisites (php83 extensions, Docker, composer v2) and install steps referencing Quickstart. Acceptance: README diff with section link.
- [ ] T041 [DOCS] Update CHANGELOG/release notes summarizing new SPK features, DSM/php83/Docker requirements, and verification steps. Acceptance: CHANGELOG entry referencing version bump.
- [ ] T042 [DOCS] Prepare release checklist (using `.specify/templates/checklist-template.md`) with evidence for build, fidelity, security, resource, support pillars. Acceptance: generated checklist file with `[x]` items once validated.

## Completion Checklist

- [ ] Constitution pillars satisfied; references captured in plan/spec.
- [ ] All scripts linted/shellchecked where applicable.
- [ ] Artifacts + docs prepared for release tagging.
