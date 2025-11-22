# Feature Specification: Pterodactyl SPK Installability

**Feature Branch**: `[001-pterodactyl-installable]`  
**Created**: 2025-11-13  
**Status**: Draft  
**Input**: User description: "Je veux juste que tu rendes l'application pterodactyl (panel+wings) installable sur mon NAS DS920+."

> Specs must prove compliance with the Synology DS920+ constitution before tasks are generated.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Installer prêt à l'emploi (Priority: P1)

En tant que propriétaire d’un DS920+, je veux pouvoir installer un paquet `.spk` signé qui déploie panel + wings via DSM sans scripts manuels.

**Why this priority**: Sans paquet SPK, le NAS ne peut pas embarquer Pterodactyl; c’est la valeur principale.

**Independent Test**: Construire `dist/pterodactyl_x86_64-7.2.spk`, l’installer via DSM et vérifier que le service apparaît et démarre.

**Acceptance Scenarios**:

1. **Given** un DS920+ sous DSM 7.2 avec Docker et php83, **When** j’installe le SPK et ouvre DSM, **Then** l’application Pterodactyl apparaît avec un bouton de démarrage et crée `panel.env`.
2. **Given** le SPK installé, **When** je démarre le service, **Then** `docker ps` montre les conteneurs panel, wings, MariaDB et Redis en fonctionnement.

---

### User Story 2 - Configuration guidée et sécurisée (Priority: P2)

En tant qu’opérateur, je veux des fichiers d’exemple (`panel.env`, `wings.config`) et des scripts qui appliquent les bons droits pour ne pas exposer mes secrets.

**Why this priority**: La sécurité (env 600, service user) est exigée par la constitution.

**Independent Test**: Après installation, vérifier que `/var/packages/pterodactyl/var/panel.env` est créé à partir du template, possède `600`, et que `spk/scripts/verify-perms.sh` passe.

**Acceptance Scenarios**:

1. **Given** une installation fraîche, **When** je consulte `/var/packages/pterodactyl/var`, **Then** `panel.env`, `data/`, `logs/` appartiennent à `sc-pterodactyl` avec les permissions attendues.
2. **Given** l’install wizard, **When** je lis les étapes, **Then** les prérequis (Docker, rotation des secrets) sont explicitement listés.

---

### User Story 3 - Exploitabilité et mises à jour (Priority: P3)

En tant que mainteneur, je veux que `make package` fonctionne en local/CI avec spksrc, que les upgrades préservent les données et qu’un contrôle d’intégrité soit fourni.

**Why this priority**: Permettre un support durable (constitution Support & Upgrade Path).

**Independent Test**: Lancer `make package`, récupérer `.spk` + `.sha256`, émuler une mise à jour via `service_preupgrade/service_postupgrade` en conservant `panel.env`.

**Acceptance Scenarios**:

1. **Given** un build local, **When** j’exécute `scripts/package/build-spk.sh`, **Then** le script clone spksrc, compile wings, et produit l’artifact + checksum.
2. **Given** une installation existante avec données, **When** je mets à jour le SPK, **Then** mes conteneurs repartent avec les anciennes configs sans perte.

---

### Edge Cases

- Que se passe-t-il si Docker n’est pas installé ou démarré ? → Le script `dsm-control.sh` doit refuser de lancer le service avec un message clair.
- Comment le système gère-t-il un `panel.env` déjà présent contenant des secrets personnalisés ? → Les hooks d’upgrade doivent sauvegarder/restaurer sans écraser.
- Que se passe-t-il si la génération de clés (`openssl` absent) échoue ? → Fallback Python/urandom doit prendre le relai.

## Requirements *(mandatory)*

### Functional Requirements (panel, wings, DSM hooks)

- **FR-001**: SPK build MUST update `spk/pterodactyl/` metadata / service scripts to deliver panel + wings via DSM service management.
- **FR-002**: Runtime MUST write/read configuration through `/var/packages/pterodactyl/var` (panel.env, wings config) with correct ownership.
- **FR-003**: Docker stack MUST expose ports 8080 (panel) & 8081 (wings) and register them through `.sc` files / DSM firewall, while allowing reverse proxy overrides.
- **FR-004**: Upgrade/uninstall scripts (`service_preupgrade`, `service_postupgrade`, `service_postuninst`) MUST preserve user data, docker volumes, and secret files.
- **FR-005**: SECURITY: Secrets (DB creds, APP_KEY, wings tokens) MUST remain in files with `600` permission; wizard/docs must describe rotation.
- **FR-006**: System MUST handle Docker availability checks and log lifecycle events to `/var/packages/pterodactyl/var/pterodactyl.log`.

- **FR-007**: Panel MUST exposer uniquement HTTP interne (port 8080) et laisser DSM gérer TLS via reverse proxy/certificats; aucune terminaison HTTPS directe n’est prévue dans le conteneur.
- **FR-008**: Le scope initial se limite à l’architecture Synology **geminilake** (DS920+) ; aucun artefact ARM ne sera produit tant que la demande n’existe pas et que les dépendances (Docker, php83) ne sont pas disponibles sur ces plateformes.

### Synology-Specific Requirements

- **SR-001**: `scripts/package/*.sh` MUST bootstrap spksrc (`synologytoolkit/dsm7.2:7.2-64570`) and log the toolchain versions used.
- **SR-002**: `cross/pterodactyl-panel` & `cross/wings` MUST pin upstream tags (Panel 1.11.6 / Wings 1.11.5) with SHA256 digests and PLIST entries.
- **SR-003**: `spk/scripts/verify-perms.sh` MUST validate ownership/perms for `panel.env`, `data/*`, `logs/`, and fail installations that drift.
- **SR-004**: Documentation/wizard MUST instruct users to install/start Docker + php83 before running the package and to edit `panel.env`.
- **SR-005**: Resource plan MUST confirm CPU/RAM budget (<2 GB / 70 % CPU) and disk usage for DS920+; update docs if docker-compose changes these numbers.

### Key Entities / Artifacts

- **Artifact: Pterodactyl SPK** — Package produced under `dist/` combining panel assets, wings binary, docker-compose, wizard data, and scripts.
- **Artifact: panel.env / wings config** — Secrets + configuration templates living under `/var/packages/pterodactyl/var` with enforced permissions.

## Synology Constraints & Security Notes

- **Service User / Permissions**: `SERVICE_USER=auto` → `sc-pterodactyl`. Script must add the user to `docker` group only when the group exists, remove on uninstall, and enforce ownership via `chown -R sc-pterodactyl`.
- **Secrets**: `panel.env` holds APP_KEY/DB creds; `wings.config.yml` holds daemon tokens. Both must be `600/640` with the service user as owner and documented rotation steps.
- **Networking**: Panel binds to DSM host on 8080 (HTTP). Wings API port 8081. DSM firewall `.sc` (app/pterodactyl.sc) must include both, with expectation that TLS is terminated by DSM reverse proxy.
- **Compliance**: Package depends on `php83` SPK and Docker package. Any new dependencies (e.g., Container Manager) must be declared in spec + release notes.

## Success Criteria *(mandatory)*

### Measurable Outcomes (tie back to constitution)

- **SC-001**: Build reproducibility – `make package` succeeds locally + CI with documented SYNO_SDK_IMAGE hash; resulting `.spk` + `.sha256` uploaded.
- **SC-002**: Runtime smoke – After installation, docker-compose stack reports healthy containers; `spk/scripts/verify-perms.sh` returns `[PASS]`.
- **SC-003**: Security – No world-readable secrets; wizard/docs instruct on TLS and secret rotation; lint/checklist complete with evidence.
- **SC-004**: Upgrade – `synopkg upgrade` preserves `panel.env`, docker volumes, and logs; manual review confirms rollback steps documented.

## Upgrade & Support Considerations

- **DSM Compatibility**: Target DSM 7.2 (geminilake). Future DSM versions require explicit validation before release.
- **Upgrade Steps**: Hooks must snapshot `panel.env`, `wings.config`, and `data/` into `SYNOPKG_TEMP_UPGRADE_FOLDER`, then restore after package update. Document necessary commands for operators.
- **Rollback Plan**: Keep previous `.spk` and `.sha256`; instruct users to reinstall prior version, ensuring `panel.env` backups remain intact.
- **Docs to Update**: README/operator guide for install steps, CHANGELOG for version bump, release notes with DSM/php83/Docker requirements, wizard text for prerequisites.
