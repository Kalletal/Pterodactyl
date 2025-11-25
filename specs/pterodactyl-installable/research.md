# Research Log – Pterodactyl SPK Installability
**Date**: 2025-11-13  
**Owner**: speckit research phase  
**Spec**: `specs/pterodactyl-installable/spec.md`

## Goals
- Validate upstream requirements (php83 extensions, Apache, MariaDB ≥10.2, Redis, composer v2, git/curl/tar/unzip).
- Confirm Synology build strategy using spksrc overlays already present in repo.
- Identify gaps for DSM-specific behaviour (wizard text, service scripts, docker-compose).

## Current State Snapshot

| Area | Evidence | Notes |
|------|----------|-------|
| Build tooling | `Makefile`, `scripts/package/common.sh`, `scripts/package/*.sh` | Already clones spksrc, builds php83, wings, SPK; ensures artifacts + checksums. |
| Cross packages | `cross/pterodactyl-panel`, `cross/wings` | Pin Panel 1.11.6 tarball, Wings 1.11.5 Go build with digests + PLIST. |
| SPK metadata | `spk/pterodactyl/Makefile` | Depends on cross packages, sets SERVICE_USER auto, binds port 8080, php83 dependency declared. |
| Runtime scripts | `spk/pterodactyl/src/service-setup.sh`, `src/dsm-control.sh` | Manage env creation, directory permissions, docker-compose start/stop, docker availability checks. |
| Config assets | `spk/pterodactyl/src/docker-compose.yml`, `panel.env.example`, `wings.config.example.yml`, wizard files | Compose stack currently uses official panel image (Apache by default) plus MariaDB 10.11, Redis 7.2, Wings image. Wizard informs about Docker + secrets. |
| Security verification | `spk/scripts/verify-perms.sh` | Ensures panel.env (600) and data directories (770/750) belong to service user. |
| Constitution | `.specify/memory/constitution.md` | Version 1.3.0 mandates reproducible builds, security, resource targets, doc updates. |

## External Requirements Validation

### PHP 8.3 + extensions
- Upstream Pterodactyl panel on DSM must rely on php83 SPK to run artisan/composer tasks.
- Required extensions list (CLI): openssl, gd, mysql, PDO, mbstring, tokenizer, bcmath, xml, curl, zip. php83 package from SynoCommunity typically bundles these; need to document verification step (php -m check).

### Web Server
- Official panel image runs Apache with PHP-FPM. Compose file already uses `ghcr.io/pterodactyl/panel` which bundles Apache. Need to mention Apache requirement in documentation and confirm no conflicting Nginx assumptions remain (spec previously referenced nginx; adjust docs to Apache).

### Database & Cache
- MariaDB ≥10.2 requirement satisfied by Compose service using `mariadb:10.11`. Need to highlight min version in wizard/operator docs.
- Redis requirement covered by `redis:7.2-alpine` service. Document enabling persistence and RAM considerations.

### CLI Utilities
- Composer v2, git, curl, tar, unzip required for panel maintenance tasks. `scripts/package/build-runtime-tools.sh` currently checks host for node/pnpm/go/composer/docker; add composer version check (already logs). Need to ensure runtime panel container has those tools (official image includes them). For DSM host, document prerequisites.

## Risks & Unknowns

| Risk | Impact | Mitigation |
|------|--------|-----------|
| php83 extension mismatch on NAS | Panel install commands fail | Document verification commands; include checklist item to run `php83 -m`. |
| Apache vs Nginx confusion | Users misconfigure reverse proxy | Update docs/wizard to say Apache is bundled; DSM reverse proxy handles HTTPS. |
| docker-compose resource usage | Could exceed DS920+ targets if MariaDB tuned poorly | Provide recommended resource settings and mention optional external DB/Redis. |
| Composer v2 availability in panel container | Upstream image should include; need confirmation | Exec into container post-install to confirm `composer --version`. If absent, add Docker build overlay or instruct manual install. |

## Open Questions

1. Do we need to vendor php83 CLI binaries inside the package or rely entirely on SynoCommunity php83 SPK? (Current plan: depend on php83 SPK; confirm DS920+ compatibility.)
2. Should we support external MariaDB/Redis instead of dockerized ones for advanced setups? (Out of scope for first release; document manual override via panel.env.)

## Next Actions

- Update spec/plan tasks to include verification of php83 extensions (`php83 -m`), composer v2 version check, Apache documentation.
- Ensure wizard copy mentions Apache + php83 + Docker prerequisites explicitly.
- Verify docker-compose logs + `spk/scripts/verify-perms.sh` as acceptance criteria in tasks phase.

---

## Research Update – 2025-11-25

### DSM 7 Docker Access for SPK Packages

**Problem identified**: SPK packages in DSM 7 cannot access Docker directly because:
1. Packages run as non-root user (`sc-<package>` or `<package>`)
2. The package user is not in the `docker` group
3. `sudo` is not available without terminal interaction
4. `run-as: root` is blocked for community packages in DSM 7.2

**Solution found**: Use the **Synology Docker Worker** instead of manual docker-compose execution.

### Synology Docker Worker

Reference: [Synology Developer Guide - Docker Package](https://help.synology.com/developer-guide/examples/compile_docker_package.html)

The Docker Worker is a DSM feature that:
- Automatically manages Docker containers for SPK packages
- Generates `docker-compose.yaml` from the `conf/resource` file
- Handles container lifecycle (create/start/stop/remove) during package install/uninstall
- Runs with appropriate privileges - **DSM handles Docker access, not the package**

#### Resource File Structure for Docker Worker

```json
{
  "docker": {
    "services": [
      {
        "service": "service-name",
        "image": "image-name",
        "container_name": "ContainerName",
        "tag": "version",
        "restart": "unless-stopped",
        "shares": [
          {"host_dir": "relative/path", "mount_point": "/container/path"}
        ],
        "ports": [
          {"host_port": "{{wizard_variable}}", "container_port": "80", "protocol": "tcp"}
        ],
        "environment": [
          {"key": "ENV_VAR", "value": "{{wizard_value}}"}
        ]
      }
    ]
  }
}
```

#### Key Benefits
- No need for the SSS script to call `docker compose` directly
- DSM manages permissions automatically
- Wizard variables can be injected via `{{wizard_variable}}` syntax
- Container lifecycle tied to package lifecycle

#### Limitations
- Less flexibility than raw docker-compose
- Environment variables must follow specific format
- Network configuration is limited
- Cannot use docker-compose advanced features (depends_on conditions, healthchecks, etc.)

### Wings Daemon Considerations

Wings cannot run inside Docker (it needs to manage Docker containers itself). Options:
1. Run Wings as native binary with limited functionality (no direct Docker access for game servers)
2. Document manual Wings installation separately
3. Use a wrapper that grants Docker access to Wings binary

**Current approach**: Include Wings binary but note that it requires manual Docker group configuration for full functionality.

### Package Dependencies

Add to Makefile:
```makefile
INSTALL_DEP_PACKAGES = ContainerManager
```

This ensures Container Manager (Docker) is installed before the package.

### Sources

- [Synology Developer Guide - Docker Package](https://help.synology.com/developer-guide/examples/compile_docker_package.html)
- [SynoCommunity spksrc - DSM 7 Support](https://github.com/SynoCommunity/spksrc/issues/4215)
- [SynoForum - Docker Worker Discussion](https://www.synoforum.com/threads/new-docker-worker-for-package-docker-integration.6090/)
