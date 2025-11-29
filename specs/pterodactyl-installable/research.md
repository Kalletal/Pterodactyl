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

---

## Research Update – 2025-11-28

### Audit de Conformité Synology

Suite à une analyse comparative avec le projet php84 et la documentation officielle Synology, plusieurs problèmes critiques ont été identifiés dans l'implémentation actuelle.

### Problèmes Critiques Identifiés

#### 1. Configuration Docker Worker Absente

**Problème** : Le fichier `spk/pterodactyl/src/conf/resource` actuel ne contient pas de configuration Docker :

```json
{
  "port-config": {
    "protocol-file": "app/pteropanel.sc"
  }
}
```

**Impact** : Les conteneurs Docker ne sont jamais démarrés automatiquement par DSM. Le commentaire dans `dsm-control.sh` ("Docker containers are managed by DSM Docker Worker") est incorrect.

#### 2. docker-compose.yml Inutilisé

**Problème** : Le fichier `docker-compose.yml` est copié dans le staging (`$(STAGING_DIR)/share/docker/`) mais aucun script ne l'exécute :
- `service-setup.sh` ne contient pas d'appel à `docker compose`
- `dsm-control.sh` ne lance pas les conteneurs

**Impact** : Le package s'installe mais les services Panel, MariaDB et Redis ne démarrent jamais.

#### 3. conf/privilege Insuffisant

**Problème** : Le fichier `conf/privilege` demande l'appartenance au groupe docker :
```json
{
  "defaults": { "run-as": "package" },
  "groupname": "docker"
}
```

**Impact** : Cela ne suffit pas dans DSM 7.2 pour exécuter `docker compose` manuellement depuis les scripts du package. Les Workers Synology sont la méthode officielle supportée.

### Solutions Recommandées

#### Option A : Docker Project Worker (Recommandée)

Le **Docker Project Worker** permet d'utiliser un fichier `compose.yaml` existant, offrant plus de flexibilité.

**Configuration conf/resource requise** :
```json
{
  "port-config": {
    "protocol-file": "app/pteropanel.sc"
  },
  "docker-project": {
    "projects": [{
      "name": "pteropanel",
      "path": "docker"
    }]
  }
}
```

**Structure de fichiers requise** :
```
target/
└── docker/
    └── compose.yaml    # Renommé depuis docker-compose.yml
```

**Avantages** :
- Supporte les fichiers compose.yaml standard
- Gestion multi-conteneurs native
- Supports `depends_on`, `networks`, etc.
- Le Worker gère le cycle de vie automatiquement

**Prérequis** :
- ContainerManager ≥1432 (DSM 7.2.1+)

**Référence** : [Docker Project Worker](https://help.synology.com/developer-guide/resource_acquisition/docker-project.html)

#### Option B : Docker Worker (JSON Natif)

Réécrire toute la configuration en JSON dans `conf/resource` :

```json
{
  "port-config": {
    "protocol-file": "app/pteropanel.sc"
  },
  "docker": {
    "services": [
      {
        "service": "panel",
        "image": "ghcr.io/pterodactyl/panel",
        "container_name": "pteropanel-panel",
        "tag": "latest",
        "restart": "unless-stopped",
        "shares": [
          {"host_dir": "panel", "mount_point": "/app/storage"},
          {"host_dir": "certs", "mount_point": "/etc/letsencrypt"}
        ],
        "ports": [
          {"host_port": "{{wizard_http_port}}", "container_port": "80", "protocol": "tcp"}
        ],
        "environment": [
          {"key": "APP_URL", "value": "{{wizard_app_url}}"},
          {"key": "DB_HOST", "value": "pteropanel-db"},
          {"key": "DB_DATABASE", "value": "pterodactyl"},
          {"key": "DB_USERNAME", "value": "pterodactyl"},
          {"key": "DB_PASSWORD", "value": "{{wizard_db_password}}"},
          {"key": "REDIS_HOST", "value": "pteropanel-redis"}
        ]
      },
      {
        "service": "panel-db",
        "image": "mariadb",
        "container_name": "pteropanel-db",
        "tag": "10.5",
        "restart": "unless-stopped",
        "shares": [
          {"host_dir": "database", "mount_point": "/var/lib/mysql"}
        ],
        "environment": [
          {"key": "MYSQL_ROOT_PASSWORD", "value": "{{wizard_db_root_password}}"},
          {"key": "MYSQL_DATABASE", "value": "pterodactyl"},
          {"key": "MYSQL_USER", "value": "pterodactyl"},
          {"key": "MYSQL_PASSWORD", "value": "{{wizard_db_password}}"}
        ]
      },
      {
        "service": "panel-redis",
        "image": "redis",
        "container_name": "pteropanel-redis",
        "tag": "alpine",
        "restart": "unless-stopped",
        "shares": [
          {"host_dir": "redis", "mount_point": "/data"}
        ]
      }
    ]
  }
}
```

**Limitations** :
- Pas de support `depends_on` avec conditions
- Pas de healthchecks configurables
- Pas de réseau bridge personnalisé (`pterodactyl`)
- Variables d'environnement limitées à la syntaxe wizard

### Comparaison avec le Projet php84

Le projet php84 utilise une approche différente :
- **Pas de Docker** : PHP s'exécute nativement sur DSM
- **conf/resource simple** : Uniquement `usr-local-linker` pour les binaires
- **Pas applicable directement** : Pterodactyl nécessite Docker pour ses services (Panel, DB, Redis)

**Leçon retenue** : Pour les packages utilisant Docker, il faut obligatoirement configurer `docker` ou `docker-project` dans `conf/resource`.

### Modifications Requises pour Corriger le Package

1. **Mettre à jour conf/resource** avec la configuration Docker Project Worker
2. **Renommer docker-compose.yml → compose.yaml** et le placer dans `target/docker/`
3. **Simplifier dsm-control.sh** : Retirer les commentaires incorrects, ne garder que la gestion de Wings
4. **Adapter le Makefile** : Changer le chemin d'installation du fichier compose
5. **Tester sur DSM 7.2.1+** avec ContainerManager ≥1432

### Prochaines Étapes

- [ ] Choisir entre Option A (Docker Project) ou Option B (Docker Worker JSON)
- [ ] Mettre à jour `conf/resource` selon l'option choisie
- [ ] Adapter la structure des fichiers
- [ ] Mettre à jour la documentation wizard
- [ ] Tester l'installation complète sur DSM réel

### Sources Additionnelles

- [Docker Project Worker](https://help.synology.com/developer-guide/resource_acquisition/docker-project.html)
- [Docker Worker](https://help.synology.com/developer-guide/resource_acquisition/docker.html)

---

## Research Update – 2025-11-28 (Suite)

### Comment Fonctionne Docker sur les NAS Synology

Cette section documente le fonctionnement de Docker/Container Manager sur Synology DSM, informations essentielles pour le développement du package Pterodactyl.

### Évolution : Docker → Container Manager

| Version DSM | Package | Docker Engine |
|-------------|---------|---------------|
| DSM 7.0-7.1 | Docker | 20.10.x |
| DSM 7.2+ | Container Manager | 20.10.23 → 24.0.2 |

**Changement majeur** : Avec DSM 7.2, Synology a renommé le package "Docker" en "Container Manager" avec une nouvelle interface utilisateur et le support natif de Docker Compose via l'onglet "Project".

### Container Manager - Versions Actuelles

| Version | Docker Engine | Date | Notes |
|---------|---------------|------|-------|
| 20.10.23-1437 | 20.10.23 | 2023 | Dernière version 20.x, ajout DS120j/DS220j |
| 24.0.2-1535 | 24.0.2 | 2025-02-11 | Sortie de beta |
| 24.0.2-1543 | 24.0.2 | 2025-07-02 | Corrections bugs réseau |

**Note importante** : Docker Engine 24.0 est en EOL depuis juin 2024. Synology est en retard sur les versions upstream (actuellement v27.x).

**Sources** :
- [Synology Docker 24.0.2 Beta](https://mariushosting.com/synology-docker-engine-version-24-0-2-available-as-beta/)
- [Container Manager 24.0.2-1535](https://www.blackvoid.club/container-manager-24-0-2-1535/)

### Modèles Supportés

Container Manager supporte **87+ modèles** Synology :

| Série | Exemples | Architecture |
|-------|----------|--------------|
| DS+ | DS920+, DS720+, DS1520+, DS1821+ | x86_64 (Intel/AMD) |
| DS (value) | DS220j, DS120j, DS124 | ARM64 (depuis CM 20.10.23) |
| RS | RS1221+, RS2421+, RS822+ | x86_64 |
| FS | FS6400, FS3600, FS2500 | x86_64 |

**DS920+ (cible du projet)** : Entièrement supporté avec processeur Intel Celeron J4125, jusqu'à 20GB RAM.

**Référence** : [Container Manager Package](https://www.synology.com/en-us/dsm/packages/ContainerManager)

### Architecture Réseau Docker sur Synology

#### Modes Réseau Disponibles

| Mode | Description | Cas d'usage |
|------|-------------|-------------|
| **bridge** (défaut) | Réseau isolé, ports mappés | Standard, recommandé pour Pterodactyl |
| **host** | Partage le réseau de l'hôte | Conflits de ports possibles |
| **macvlan** | Adresse MAC/IP distincte | Pi-hole, conflits port 80/443 |

#### Bridge Network (Recommandé pour Pterodactyl)

```yaml
# Dans compose.yaml
networks:
  pterodactyl:
    driver: bridge
```

- Les ports publiés sont accessibles depuis l'extérieur
- Isolation entre conteneurs et hôte
- Pas de conflit de ports avec DSM

#### Macvlan (À éviter pour ce projet)

- Nécessite configuration manuelle persistante
- Problème : l'hôte Synology ne peut pas communiquer directement avec les conteneurs macvlan
- Interfaces peuvent être `ovs_ethX` ou `ovs_bond0` selon la config Virtual Machine Manager

**Sources** :
- [Docker Macvlan on Synology](https://blog.differentpla.net/blog/2025/03/08/docker-macvlan/)
- [WunderTech Container Manager Guide](https://www.wundertech.net/container-manager-on-a-synology-nas/)

### Stockage et Volumes

#### Emplacements de Stockage

| Chemin | Description | Accessible File Station |
|--------|-------------|------------------------|
| `/volume1/@docker` | Données internes Docker (hidden) | Non |
| `/volume1/docker` | Dossier partagé recommandé | Oui |
| `/var/packages/Docker/target/docker` | Symlink vers @docker | Non |

**Best Practice** : Toujours utiliser `/volume1/docker/` (ou `/volumeX/docker/`) pour les bind mounts afin de :
- Permettre la sauvegarde via HyperBackup/Snapshots
- Accéder aux fichiers via File Station
- Faciliter la migration entre NAS

#### Syntaxe des Volumes dans Compose

```yaml
volumes:
  # Chemin absolu requis sur Synology
  - /volume1/docker/pterodactyl/panel:/app/storage
  - /volume1/docker/pterodactyl/database:/var/lib/mysql
```

**Important** : Ne pas utiliser de chemins relatifs. Toujours spécifier `/volumeX/`.

**Sources** :
- [Mapping Docker Volumes on Synology](https://tomwojcik.com/posts/2022-04-24/mapping-docker-volume-on-synology-nas/)
- [Docker Permissions on Synology](https://www.synoforum.com/threads/docker-permissions-how-and-where.5022/)

### Permissions : PUID et PGID

#### Concept

Les conteneurs Docker accèdent aux volumes avec un UID/GID spécifique. Sur Synology, il faut mapper ces IDs correctement.

#### Trouver les IDs

```bash
# Via SSH sur le NAS
id
# Résultat: uid=1026(dockeruser) gid=100(users) groups=100(users),101(administrators)
```

#### Configuration dans Compose

```yaml
environment:
  - PUID=1026
  - PGID=100
  - TZ=Europe/Paris
```

Ou avec la directive `user`:
```yaml
user: "1026:100"
```

#### Best Practice pour Pterodactyl

1. **Créer un utilisateur dédié** `dockeruser` sur le NAS
2. **Donner les permissions** sur `/volume1/docker/pterodactyl/`
3. **Utiliser cet UID/GID** dans les variables d'environnement des conteneurs

**Note** : L'image officielle Pterodactyl Panel gère ses propres permissions internes. Vérifier la documentation upstream.

**Sources** :
- [How to Find UID/GID on Synology](https://mariushosting.com/synology-how-to-find-uid-userid-and-gid-groupid/)
- [Docker User Permissions](https://drfrankenstein.co.uk/step-2-setting-up-a-restricted-docker-user-and-obtaining-ids/)

### Projets Docker Compose dans Container Manager

#### Fonctionnement

Depuis DSM 7.2, l'onglet **Project** permet de gérer des stacks Docker Compose directement depuis l'UI :

1. Créer un projet avec un nom
2. Spécifier le chemin du dossier contenant `compose.yaml`
3. Container Manager gère le cycle de vie (up/down/restart)

#### Structure Recommandée

```
/volume1/docker/pterodactyl/
├── compose.yaml
├── .env                    # Variables d'environnement
├── panel/                  # Volume pour le panel
├── database/               # Volume MariaDB
└── redis/                  # Volume Redis
```

#### Différence CLI vs Container Manager UI

| Aspect | CLI (`docker compose`) | Container Manager Project |
|--------|------------------------|---------------------------|
| Flexibilité | Totale | Totale |
| Persistance | Manuelle | Automatique |
| Gestion | Via SSH | Via DSM UI |
| Logs | Terminal | Interface graphique |

**Les deux méthodes produisent le même résultat** : les conteneurs sont identiques.

**Sources** :
- [Container Manager Project](https://kb.synology.com/en-sg/DSM/help/ContainerManager/docker_project?version=7)
- [Docker Compose on Synology](https://www.virtualizationhowto.com/2023/02/docker-compose-synology-nas-install-and-configuration/)

### Changements Importants dans Container Manager 24.x

#### Modification des Conteneurs

> À partir de cette version, les paramètres du conteneur (ports, volumes, environnement, links) **ne sont plus modifiables** après création. Pour modifier, il faut "Dupliquer" le conteneur.

**Impact pour Pterodactyl** : Les utilisateurs devront recréer les conteneurs pour changer les ports. Documenter cette limitation.

#### Corrections de Bugs

- Connexions de ports avec plusieurs passerelles
- Configuration IPv6
- Affichage du statut des images

### Option C : Container Manager Direct (Sans Worker SPK)

Suite aux recherches, une troisième approche émerge comme potentiellement plus simple :

#### Concept

Le SPK ne gère **que** Wings + helpers. L'utilisateur importe manuellement le `compose.yaml` dans Container Manager.

#### Avantages

| Avantage | Description |
|----------|-------------|
| SPK simplifié | Pas de configuration Worker complexe |
| Flexibilité totale | L'utilisateur peut modifier le compose |
| Compatibilité | Fonctionne sur DSM 7.0+ |
| Mises à jour | Via l'UI Container Manager standard |
| Debugging | Logs et gestion via l'interface graphique |

#### Inconvénients

| Inconvénient | Description |
|--------------|-------------|
| Installation en 2 temps | SPK puis import compose |
| Risque d'erreur | L'utilisateur doit suivre la doc |
| Moins "clé en main" | Pas de one-click install |

#### Structure Proposée

```
SPK Pteropanel:
├── Wings binary
├── Configuration helpers
├── Templates:
│   ├── compose.yaml.example
│   └── .env.example
└── Documentation wizard
```

L'utilisateur :
1. Installe le SPK (Wings + templates)
2. Copie les templates vers `/volume1/docker/pterodactyl/`
3. Crée un Project dans Container Manager
4. Configure Wings via le Panel

### Recommandation Finale

Après analyse complète du fonctionnement de Docker sur Synology :

| Option | Complexité SPK | UX Utilisateur | Maintenabilité | Recommandation |
|--------|----------------|----------------|----------------|----------------|
| Docker Worker (JSON) | Élevée | One-click | Difficile | ❌ Non |
| Docker Project Worker | Moyenne | One-click | Moyenne | ⚠️ Possible |
| Container Manager Direct | Faible | 2 étapes | Facile | ✅ Recommandée |

**Justification** : Container Manager Direct offre le meilleur compromis entre simplicité de développement, flexibilité utilisateur, et maintenabilité long terme. Les Workers Synology ajoutent une couche d'abstraction qui peut devenir problématique lors des mises à jour de DSM ou Container Manager.

### Sources Générales

- [Synology Container Manager Feature Page](https://www.synology.com/en-us/dsm/feature/docker)
- [Synology Knowledge Center - Container Manager](https://kb.synology.com/en-me/DSM/help/ContainerManager/docker_desc?version=7)
- [WunderTech - Complete Container Manager Guide](https://www.wundertech.net/container-manager-on-a-synology-nas/)
- [Marius Hosting - Synology Docker](https://mariushosting.com/category/synology-container-manager/)
- [SynoForum - Docker/Container Manager](https://www.synoforum.com/forums/docker-container-manager.45/)
