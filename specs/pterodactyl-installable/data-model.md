# Data Model – Pterodactyl SPK Installability
**Date**: 2025-11-13  
**Spec**: `specs/pterodactyl-installable/spec.md`

## Purpose
Capture the key configuration/state entities that the Synology package manages so that tasks can reason about ownership, persistence, and upgrade behaviour.

## Entities

### 1. `PanelConfig`
- **Location**: `/var/packages/pterodactyl/var/panel.env`
- **Fields** (subset):
  - `APP_ENV`, `APP_URL`, `APP_KEY`, `APP_TIMEZONE`
  - DB credentials: `DB_HOST`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`, `DB_ROOT_PASSWORD`
  - Redis settings: `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`
  - Mailer: `MAIL_DRIVER`, `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_PASSWORD`
  - Docker images/ports: `PANEL_IMAGE`, `WINGS_IMAGE`, `PANEL_HTTP_PORT`, `WINGS_DAEMON_PORT`
  - Runtime helpers: `COMPOSE_PROJECT`, `PACKAGE_TARGET`, `PACKAGE_DATA`
- **Constraints**: File must be owned by `sc-pterodactyl`, `chmod 600`. Generated from `panel.env.example` and customized by operator. Preserved across upgrades (`service_preupgrade/service_postupgrade` copies it to temp folder and back).

### 2. `WingsConfig`
- **Location**: `/var/packages/pterodactyl/var/data/wings/config.yml`
- **Fields**:
  - `system.data`, `system.archives`
  - API server: `api.host`, `api.port`, TLS cert/key paths
  - Panel linkage: `panel.url`, `panel.token_id`, `panel.token`
  - Docker integration: `docker.socket`, `docker.network.name`
  - SFTP settings, allowed mounts
- **Constraints**: Owned by `sc-pterodactyl`, `chmod 640`. Created from `wings.config.example.yml`. Requires operator to insert real tokens from panel.

### 3. `DockerStack`
- **Location**: `spk/pterodactyl/src/docker-compose.yml` -> runtime copy under `/var/packages/pterodactyl/target/share/docker/docker-compose.yml`
- **Services**:
  - `panel` (Apache + PHP 8.1/8.2 upstream container, but panel requires php83 CLI for artisan tasks; php83 SPK on host handles CLI usage)
  - `panel-db` (MariaDB 10.11) with volume `/var/packages/pterodactyl/var/data/database`
  - `panel-redis` with volume `/var/packages/pterodactyl/var/data/redis`
  - `wings` (Go binary) consuming `/var/packages/pterodactyl/var/data/wings`
- **Constraints**: Compose environment uses values from `panel.env`. Ports 8080 (panel) and 8081 (wings) mapped to host; TLS handled separately. Operator can override DB/Redis hosts by editing env file.

### 4. `ServiceState`
- **Location**: `/var/packages/pterodactyl/var/pterodactyl.log`, `/var/packages/pterodactyl/var/pterodactyl.pid`, `/var/packages/pterodactyl/var/logs/`
- **Fields**:
  - Log entries appended by `dsm-control.sh` and docker-compose.
  - PID file storing the supervising script PID.
- **Constraints**: Logs directory `chmod 750`, same ownership. `verify-perms.sh` validates structure. Not shipped across upgrades except log file retention policy.

### 5. `BuildArtifacts`
- **Location**: `dist/pterodactyl_*.spk`, `.sha256`, `build/logs/*`
- **Fields**:
  - SPK metadata (INFO, conf files)
  - Checksums for release verification
- **Constraints**: Generated via `make package`/CI, must be published with release notes. Not part of runtime but referenced for reproducibility.

## Relationships

```text
PanelConfig ──(env vars)──► DockerStack.panel / panel-db / panel-redis / wings
PanelConfig ──(credentials)──► MariaDB data volume / Redis data volume
WingsConfig ──(token/link)──► Panel API (inside DockerStack.panel)
DockerStack volumes ──(persist)──► /var/packages/pterodactyl/var/data/{panel,wings,database,redis}
ServiceState ──(monitors)──► DockerStack lifecycle
BuildArtifacts ──(deploy)──► DSM synopkg install
```

## Data Lifecycle Notes
- **Creation**: `service-setup.sh` seeds panel env and wings config templates, creates directories, sets permissions.
- **Update**: Operators edit `panel.env` / `wings.config.yml`; upgrades copy them to temp folder and back.
- **Backup**: Documented procedure should tar `/var/packages/pterodactyl/var` (excluding logs) and database volume.
- **Deletion**: `service_postuninst` removes docker group membership but intentionally leaves `/var/packages/pterodactyl/var` so users can back up data; manual removal documented.

## Outstanding Questions (for completeness)
- Do we need to snapshot docker volumes separately during upgrade? (Current script uses `rsync -a data/`.)
- Should logs be rotated or integrated with DSM Log Center? (Future enhancement.)
