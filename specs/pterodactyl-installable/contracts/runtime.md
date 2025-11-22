# Contracts – Pterodactyl SPK Runtime Interfaces

## 1. Service Lifecycle (DSM)

| Operation | Producer | Consumer | Payload | Notes |
|-----------|----------|----------|---------|-------|
| `synopkg start pterodactyl` | DSM control panel | `spk/pterodactyl/src/dsm-control.sh` | ENV vars (SYNOPKG_*, panel.env content) | Script must ensure Docker running, `docker compose up -d`, log to `/var/packages/pterodactyl/var/pterodactyl.log`. |
| `synopkg stop pterodactyl` | DSM control panel | `dsm-control.sh` | none | Runs `docker compose down`, cleans PID, logs action. |
| `service_postinst` hook | synopkg | `spk/pterodactyl/src/service-setup.sh` | wizard vars if any | Creates directories, seeds env/config templates, sets permissions, adds `sc-pterodactyl` to docker group (if exists). |
| `service_preupgrade/service_postupgrade` | synopkg upgrade flow | `service-setup.sh` | Path references (temp folder) | Pre hook copies panel.env, wings config, `data/`; post hook restores and resets ownership. |

## 2. Docker Stack Interfaces

| Interface | Direction | Details |
|-----------|-----------|---------|
| docker-compose environment | `panel.env` → `docker-compose.yml` | `panel`, `panel-db`, `panel-redis`, `wings` use env vars for images, ports, credentials. |
| MariaDB bootstrap | `spk/pterodactyl/src/bootstrap.sql` → MariaDB container | Creates DB/user; requires MariaDB image ≥10.2. |
| Wings ↔ Panel API | `wings.config.yml` (panel token) | Wings authenticates against panel API served via Apache inside container. |

## 3. Verification Script

| Script | Inputs | Outputs | Contract |
|--------|--------|---------|---------|
| `spk/scripts/verify-perms.sh` | `VERIFY_ROOT`, `VERIFY_USER/GROUP` envs | Exit 0/1, log lines | Must detect missing dirs/files, wrong ownership, or incorrect perms (panel.env 600, data dirs 770/750). CI/PR reviewers rely on it. |

## 4. External Prerequisites

| Dependency | Required Version | Contract |
|------------|------------------|----------|
| php83 SPK | 8.3.x with extensions openssl, gd, mysql, PDO, mbstring, tokenizer, bcmath, xml, curl, zip | Must be installed prior to running panel artisan/composer tasks. Document verification commands (`php83 -m`). |
| MariaDB | ≥10.2 | Provided via `mariadb:10.11` container by default; external DB must meet version requirement. |
| Redis | ≥5 (targeting 7.2) | Provided via docker container; external Redis must match spec. |
| Docker | DSM Docker package (compose plugin or docker-compose binary) | `dsm-control.sh` expects `docker compose` or `docker-compose`. |
| CLI tools | curl, tar, unzip, git, composer v2 | Provided inside docker containers and/or host environment; build scripts log composer version. |

## 5. Wizard Communication

| Step | Message | Contract |
|------|---------|----------|
| Prérequis Docker | “Docker + php83 doivent être installés et démarrés avant Pterodactyl” | Must mention php83 extensions, Apache usage, MariaDB/Redis minima. |
| Secrets | “Éditez /var/packages/pterodactyl/var/panel.env pour vos clés (APP_KEY, DB, Redis, mail)” | Operator must update file before exposing service. |

