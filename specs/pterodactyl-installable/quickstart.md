# Quickstart – Pterodactyl SPK on Synology DS920+
**Spec**: `specs/pterodactyl-installable/spec.md`  
**Audience**: Maintainers validating the SPK install path

## 1. Prérequis matériels / logiciels

1. Synology DS920+ (DSM 7.2, arch geminilake).
2. Paquets DSM installés et démarrés :
   - **Docker** (compose plugin ou `docker-compose` CLI disponible).
   - **php83** SPK (v8.3.x) avec extensions `openssl`, `gd`, `mysql`, `PDO`, `mbstring`, `tokenizer`, `bcmath`, `xml`, `curl`, `zip`. Vérifier via `php83 -m`.
3. Ligne de commande accessible (SSH) avec `curl`, `tar`, `unzip`, `git`, `composer` v2 pour maintenance éventuelle. Vérifiez la version avec `composer --version` (doit afficher `Composer version 2.x`).

## 2. Construction du paquet (mainteneurs)

```bash
cd /path/to/Pterodactyl
make setup package \
  ARCH=geminilake \
  TCVERSION=7.2 \
  SYNO_SDK_IMAGE=synologytoolkit/dsm7.2:7.2-64570
```

Résultat :
- `.build/spksrc` cloné et synchronisé avec nos overlays.
- `dist/pterodactyl_*_x86_64-7.2.spk` et `.sha256`.
- Logs sous `build/logs/`.

## 3. Installation côté DSM

1. Connectez-vous à DSM > Centre de paquets > Installation manuelle > sélectionnez l’`.spk`.
2. Wizard :
   - Étape “Prérequis système” rappelle Docker, php83 + extensions, et les CLI (curl/tar/unzip/git/composer v2).
   - Étape “Base de données et cache” précise les versions minimales (MariaDB ≥10.2, Redis 7.2) et l’usage d’Apache.
   - Étape “Secrets” demande de personnaliser `panel.env`.
3. Une fois installé, vérifier la présence du service Pterodactyl dans “Services installés”.

## 4. Configuration initiale

```bash
ssh admin@nas
sudo -i
cd /var/packages/pterodactyl/var
cp panel.env panel.env.backup.$(date +%Y%m%d)
vi panel.env
  # Mettre à jour APP_KEY (utiliser `php83 -r "echo base64_encode(random_bytes(32));"`),
  # DB_PASSWORD, DB_ROOT_PASSWORD, mail, APP_URL, etc.

vi data/wings/config.yml
  # Insérer panel token_id/token depuis l’interface Pterodactyl une fois générés.
```

## 5. Démarrage du service

Via DSM ou CLI :

```bash
sudo synopkg start pterodactyl
tail -f /var/packages/pterodactyl/var/pterodactyl.log
docker ps --filter "label=com.docker.compose.project=pterodactyl"
```

Conteneurs attendus : `pterodactyl-panel`, `pterodactyl-panel-db`, `pterodactyl-panel-redis`, `pterodactyl-wings`.

## 6. Vérifications post-install

1. Naviguer vers `http://<NAS>:8080` (HTTP interne) puis configurer DSM reverse proxy/TLS pour exposition externe.
2. Lancer `spk/scripts/verify-perms.sh` sur un staging tree si utilisé (CI) ou vérifier manuellement :
   - `ls -l /var/packages/pterodactyl/var/panel.env` → `-rw------- sc-pterodactyl`.
   - Dossiers `data/panel`, `data/wings`, `data/database`, `data/redis` → `drwxrwx--- sc-pterodactyl sc-pterodactyl`.
3. Vérifier MariaDB/Redis :
   - `docker logs pterodactyl-panel-db | grep "ready for connections"`.
   - `docker logs pterodactyl-panel-redis | grep "Ready to accept connections"`.

## 7. Mise à jour

1. Sauvegarder `panel.env`, `wings.config.yml`, `data/` (optionnel) : `rsync -a /var/packages/pterodactyl/var/ /volume1/backups/pterodactyl/`.
2. Installer le nouvel `.spk` via DSM.
3. Vérifier que les conteneurs repartent et que les secrets sont intacts.

## 8. Désinstallation / nettoyage

1. `synopkg stop pterodactyl` puis `synopkg uninstall pterodactyl`.
2. Les données sous `/var/packages/pterodactyl/var` restent ; supprimer manuellement après sauvegarde si souhaité.
3. Retirer l’utilisateur du groupe docker si nécessaire (script le fait lors de l’uninstall).
