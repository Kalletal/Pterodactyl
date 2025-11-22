<!--
old_version: 1.2.0
new_version: 1.3.0 (minor — rewritten pillars + synced templates)
pillars: renamed to Synology Build Integrity / Pterodactyl Fidelity / Security & Isolation / Resource & Observability Discipline / Support & Upgrade Path
sections: updated Implementation Directives (added Documentation & Release Workflow)
templates: plan-template.md ✅ | spec-template.md ✅ | tasks-template.md ✅ | checklist-template.md ✅
todos: none
-->
# Pterodactyl Synology SPK Constitution

## Mission
Deliver a first-party-quality Pterodactyl panel + wings experience for Synology DS920+ owners by
shipping reproducible `.spk` packages built with **spksrc**, hardened for DSM 7.x, and fully
operable through the artifacts, scripts, and documentation stored in this repository.

## Guiding Pillars

### 1. Synology Build Integrity
- `make package` MUST succeed locally and in CI (GitHub Actions using
  `synologytoolkit/dsm7.2:7.2-64570`) via the provided `scripts/package/*` and `Makefile`, targeting
  `ARCH=geminilake` / `TCVERSION=7.2 (geminilake)`.
- `scripts/package/bootstrap.sh` SHALL clone/sync upstream **spksrc** and mirror our
  `cross/`, `native/`, and `spk/` overlays; deviations require documenting why spksrc cannot be used
  and must include a follow-up task to re-align.
- Each build SHALL emit `.spk`, `.sha256`, and build logs under `dist/`; releases must attach these
  artifacts verbatim so DS920+ owners can verify provenance.
- `cross/pterodactyl-panel` and `cross/wings` definitions MUST pin upstream versions with matching
  `digests`, while `spk/pterodactyl/Makefile` remains the single source of truth for INFO metadata,
  dependencies (`php83`, Docker), firewall ports, and `POST_STRIP_TARGET` staging.

### 2. Pterodactyl Fidelity
- Panel and Wings MUST follow upstream tagged releases (currently Panel `1.11.6`, Wings `1.11.5`);
  any Synology patch lives under `synology/patches/**` with a justification linked in CHANGELOG and
  upstream issues.
- `spk/pterodactyl/src/panel.env.example`, `wings.config.example.yml`, and `docker-compose.yml` MUST
  mirror upstream defaults except where DSM paths/ports demand overrides, which must be called out in
  docs and wizard text.
- `cross/` packages SHALL stay architecture-agnostic unless a feature cannot run on DS920+; in that
  case, the spec must record the limitation and CI skips.
- Operators MUST be able to reuse upstream documentation: renamed env keys, API changes, or Wings
  behaviour shifts require migration snippets in `docs/` and release notes.

### 3. Security & Isolation
- The service account `sc-pterodactyl` is the only user allowed to own `/var/packages/pterodactyl/*`;
  `service-setup.sh` MUST enforce ownership and `chmod 600` for `panel.env`, Wings tokens, and any
  secret-bearing files. Docker group membership is only granted via explicit reasoning in specs.
- Start/stop scripts (`src/dsm-control.sh`) SHALL refuse to run if Docker is unavailable, log all
  lifecycle transitions to `/var/packages/pterodactyl/var/pterodactyl.log`, and never expose
  credentials via stdout.
- Firewall `.sc` files and DSM certificate bindings MUST be updated whenever ports or TLS flows
  change. By default, panel and wings bind to internal ports (8080/8081) and rely on DSM reverse
  proxy/TLS for exposure.
- Secrets management and TLS expectations MUST appear in wizard text + operator docs, and every PR
  touching secrets MUST extend `spk/scripts/verify-perms.sh` to cover the new layout.

### 4. Resource & Observability Discipline
- Baseline runtime (panel + wings + MariaDB + Redis) MUST stay below 2 GB RAM and 70 % aggregate
  CPU on a stock DS920+; specs altering docker-compose settings must include new measurements or a
  mitigation plan.
- Logging paths (`/var/packages/pterodactyl/var/pterodactyl.log`, container logs, DSM Log Center
  integration) MUST remain discoverable and documented. New daemons require log rotation guidance.
- Backup & restore instructions SHALL cover panel DB snapshots, docker volumes under
  `/var/packages/pterodactyl/var/data/**`, `.env`, and Wings configs; features touching these assets
  must define how backups are affected.
- Monitoring hooks (health endpoints, Wings heartbeat, docker metrics) MUST remain scriptable so
  operators can automate alerts; features introducing new failure modes must add detection guidance.

### 5. Support & Upgrade Path
- Every change MUST declare DSM build compatibility, php83/Docker requirements, and whether a
  Synology package upgrade, restart, or operator action is needed; undocumented requirements block
  releases.
- Upgrade hooks (`service_preupgrade`, `service_postupgrade`) MUST keep user data intact; if manual
  commands are required, list them in spec + docs and add a checklist item.
- Physical DS920+ testing (or the documented DSM VM equivalent) MUST precede stable releases; if a
  hotfix skips hardware validation, a follow-up issue with owner/date is mandatory.
- SemVer applies to both the SPK and this constitution: breaking behaviour requires a MAJOR bump,
  additive constraints a MINOR bump, clarifications a PATCH.

## Implementation Directives

### Build & Packaging Flow
- `scripts/package/common.sh` governs toolchain detection, dockerized builds, rsync overlays, and
  artifact collection; features modifying build flow MUST update this script plus any new helper.
- `scripts/package/build-php-runtime.sh`, `build-runtime-tools.sh`, `build-wings.sh`, and
  `build-spk.sh` SHALL remain idempotent, clearly log the versions they build, and fail loudly when
  host prerequisites (`node`, `pnpm`, `go`, `composer`, `docker`) are missing.
- All new binaries/configs must be staged via `POST_STRIP_TARGET` in `spk/pterodactyl/Makefile` so
  the generated `spksrc` installer handles them. Hand-copied files outside staging are forbidden.
- Digests (`cross/*/digests`) MUST be regenerated whenever upstream tarballs change; PRs must include
  the checksum source (command/log) in their description.

### Configuration & Data Management
- Mutable state lives under `/var/packages/pterodactyl/var`: `var/data/**` for docker volumes,
  `var/panel.env`, `var/data/wings/config.yml`, `var/pterodactyl.log`. Specs introducing new paths
  must cover permissions, backups, and verify scripts.
- `docker-compose.yml` is the authoritative runtime topology. Changing services, ports, or volumes
  requires updating wizard guidance, env templates, and documentation about reverse proxies/TLS.
- `panel.env.example` is the single env template; any new env vars or defaults must be added there,
  described in docs, and surfaced via install wizard copy.
- `wizard/*` screens SHALL alert operators about prerequisites (Docker, secrets rotation, backups)
  whenever behaviours change. If wizard UX cannot surface a requirement, spec must document the
  alternative communication channel.

### Testing & Validation
- Minimum regression suite per PR: `make package` (or targeted script), `spk/scripts/verify-perms.sh`
  against staging tree, and a docker-compose smoke test (panel reachable, wings registers) unless the
  change is doc-only.
- CI logs (build + verify) MUST be attached to PRs. Failures cannot be waived without filing an
  issue capturing root cause, workaround, and owner.
- Manual QA matrix for releases: DSM VM install → configure DB/Redis via `panel.env` → create game
  server → wings heartbeat → backup/restore → uninstall. Results feed into release notes.

### Documentation & Release Workflow
- Every behavioural change requires doc updates (README/operator guide/spec appendices, CHANGELOG,
  release notes). PRs lacking doc references cannot merge.
- Release PRs MUST include a dependency matrix (DSM, Docker, php83), upgrade steps, rollback plan,
  and links to build artifacts. Hotfixes must note what was skipped and schedule completion tasks.
- Exceptions to this constitution must be recorded in `docs/exceptions.md` with expiry and owner.

## Governance & Compliance
- This constitution governs all work in this repo. Amendments require maintainer consensus via PR
  that cites the trigger (DSM update, upstream change, security incident), updates impacted templates,
  and bumps the version per SemVer rules.
- Compliance is checked during plan/spec review, PR review, and again before signing an SPK. Missing
  gates block merge/release unless a time-bound exception (with mitigation) is documented.
- Ratified text lives in `.specify/memory/constitution.md`; templates under `.specify/templates/**`
  must stay in sync with the latest principles.

**Version**: 1.3.0 | **Ratified**: 2025-11-13 | **Last Amended**: 2025-11-13
