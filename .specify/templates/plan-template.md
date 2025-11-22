# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]  
**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

> This template is filled in by `/speckit.plan` and is tailored to the Synology DS920+ Pterodactyl SPK.

## Summary

[Primary requirement + intended technical approach from research.md in two sentences]

## Technical Context (Fill, do not delete fields)

- **Target DSM/Arch**: `DSM 7.2 / geminilake (x86_64)` unless feature dictates otherwise  
- **Build Toolchain**: `spksrc` via `scripts/package/*.sh` (note if Docker-in-Docker or bare-metal)  
- **Runtime Stack**: PHP 8.3 panel, Go Wings daemon, Docker Compose stack (panel, MariaDB, Redis)  
- **External Dependencies**: `Docker`, `php83` SPK, Synology SSL, `synopkg` APIs, [NEEDS CLARIFICATION if new]  
- **Storage Layout Impacted**: `/var/packages/pterodactyl/target`, `/var/packages/pterodactyl/var`, `/volume1/@appdata/pterodactyl`  
- **Testing Surface**: `spk/scripts/verify-perms.sh`, docker-compose smoke tests, `synopkg install --test` notes  
- **Performance / Resource Goals**: <2 GB RAM idle, <70% CPU on DS920+, I/O limited to NAS data share  
- **Constraints**: No network egress inside SPK, secrets locked to `panel.env` (600), wings limited to docker group

Replace any line with `NEEDS CLARIFICATION` if the spec fails to answer it.

## Constitution Check (All MUST be addressed before Phase 0)

- **Synology Build Integrity**: Describe how this work keeps `make package` reproducible (toolchain, scripts touched, artifact expectations).  
- **Pterodactyl Fidelity**: Confirm upstream tags/branches being targeted, migration/rollback story, and whether configs remain compatible with `panel.env` & `wings.config`.  
- **Security & Isolation**: Call out permission changes (service user, docker group, ACLs), TLS implications, and any new secrets or env vars.  
- **Resource & Observability**: Quantify load impact (CPU/RAM, storage), log/metrics touchpoints, and backup/restore hooks that need updates.  
- **Support & Upgrade Path**: Map the DSM builds, php83/Docker version assumptions, and how upgrades/uninstalls will be rehearsed (`service_pre*` hooks, docs).

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Repository Topology (update with the dirs this feature touches)

```text
scripts/package/         # bootstrap, build-php-runtime, build-wings, build-spk
cross/                   # cross tool defs (panel, wings, ...)
spk/pterodactyl/         # SPK metadata, service scripts, docker assets
spk/scripts/             # verification utilities (permissions, smoke)
dist/ & .build/          # generated artifacts (never commit)
docs/, specs/, .specify/ # process + operator guidance
```

Extend/adjust the tree to show new files or subdirectories you intend to add.

**Structure Decision**: [Summarize which directories/files will change and why]

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
