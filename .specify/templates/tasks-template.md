---
description: "Task list template for Synology Pterodactyl SPK features"
---

# Tasks: [FEATURE NAME]

**Inputs**: `/specs/[###-feature-name]/` (spec.md, research.md, data-model.md, contracts/) and the constitution gates. 
**Prereqs**: plan.md approved, spec-level constitution check complete.

> Format: `[ID] [P?] [Area] Description (file paths + acceptance)`
>
> - `[P]` means safe to run in parallel (no overlapping files).
> - `[Area]` must be one of: `PLAN`, `BUILD`, `RUNTIME`, `SECURITY`, `TEST`, `DOCS`.
> - Every task references concrete repo paths (`spk/pterodactyl/...`, `scripts/package/...`, etc.).

## Phase 0 – Planning & Toolchain Alignment

- [ ] T000 [PLAN] Sync plan/spec with latest constitution decisions, note upstream versions & DSM scope.
- [ ] T001 [PLAN] Confirm whether `cross/` or `native/` packages need new digests or sources.
- [ ] T002 [BUILD] Verify `scripts/package/bootstrap.sh` + selected `SYNO_SDK_IMAGE` handle the feature (note Docker vs bare metal).

## Phase 1 – Build System & Dependencies

- [ ] T010 [P][BUILD] Update `scripts/package/*.sh` (bootstrap, build-php-runtime, build-wings, build-spk) for new toolchain or artifacts.
- [ ] T011 [BUILD] Adjust `cross/<pkg>/` or `native/<pkg>/` Makefiles, `PLIST`, `digests` for version pins / patches.
- [ ] T012 [BUILD] Update `spk/pterodactyl/Makefile` metadata (versions, deps, FW ports) and ensure `POST_STRIP_TARGET` copies new assets.

## Phase 2 – Runtime / Service Surfaces

- [ ] T020 [RUNTIME] Modify service scripts (`spk/pterodactyl/src/service-setup.sh`, `src/dsm-control.sh`) with clear acceptance notes (permissions, docker usage, hooks).
- [ ] T021 [RUNTIME] Add/adjust config assets (e.g., `panel.env.example`, `wings.config.example.yml`, docker compose, wizard UI files).
- [ ] T022 [SECURITY] Re-run ownership model: update `spk/scripts/verify-perms.sh`, ACL notes, and document any docker group changes.

## Phase 3 – Testing & Validation

- [ ] T030 [TEST] Run `make package` (or targeted `scripts/package/*`) and capture build logs + `.spk`/`.sha256` outputs in `dist/`.
- [ ] T031 [TEST] Execute `spk/scripts/verify-perms.sh` against staging tree (or DSM VM) and record results.
- [ ] T032 [TEST] Smoke-test docker-compose stack (panel + wings) or document why not applicable.

## Phase 4 – Documentation & Release Notes

- [ ] T040 [DOCS] Update operator docs (README, docs/*, spec appendices) describing new env vars, ports, backup steps.
- [ ] T041 [DOCS] Update CHANGELOG / release notes with DSM compatibility, version pins, and upgrade instructions.
- [ ] T042 [DOCS] Ensure `/specs/[###-feature]/quickstart.md` or equivalent references constitution gates (build, security, support).

## Completion Checklist

- [ ] Constitution pillars satisfied (Build Integrity, Fidelity, Security, Resource/Observability, Support/Upgrade).
- [ ] All touched files linted/validated, `git status` clean (excluding `dist/`, `.build/`).
- [ ] Release artifacts + documentation linked back to tasks.
