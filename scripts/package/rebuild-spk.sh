#!/usr/bin/env bash
set -euo pipefail

# Script de reconstruction du SPK sans recompilation
# Utile pour les modifications mineures (HTML, CSS, JS, configs)

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DIST_DIR="${ROOT}/dist"
SRC_DIR="${ROOT}/spk/pterodactyl/src"
TMP_DIR="${DIST_DIR}/tmp"
ARCH="${ARCH:-geminilake}"
TCVERSION="${TCVERSION:-7.2}"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Correspondance des fichiers src → destination dans package.tgz
# Format: "fichier_source:chemin_destination"
declare -a FILE_MAPPINGS=(
    "loading.html:share/loading.html"
    "bootstrap.sql:share/bootstrap.sql"
    "panel.env.example:share/panel.env.example"
    "wings.config.example.yml:share/wings.config.example.yml"
    "docker-compose.yml:share/docker/docker-compose.yml"
    "loading-server.sh:bin/loading-server.sh"
    "app/pterodactyl_panel.sc:app/pterodactyl_panel.sc"
    "app/config:app/config"
    "ui/wings-config.cgi:app/wings-config.cgi"
    "app/images/pterodactyl_panel-16.png:app/images/pterodactyl_panel-16.png"
    "app/images/pterodactyl_panel-24.png:app/images/pterodactyl_panel-24.png"
    "app/images/pterodactyl_panel-32.png:app/images/pterodactyl_panel-32.png"
    "app/images/pterodactyl_panel-48.png:app/images/pterodactyl_panel-48.png"
    "app/images/pterodactyl_panel-64.png:app/images/pterodactyl_panel-64.png"
    "app/images/pterodactyl_panel-72.png:app/images/pterodactyl_panel-72.png"
    "app/images/pterodactyl_panel-256.png:app/images/pterodactyl_panel-256.png"
)

# Fichiers icônes SPK (à la racine du SPK, pas dans package.tgz)
declare -a ICON_MAPPINGS=(
    "PACKAGE_ICON.PNG:PACKAGE_ICON.PNG"
    "PACKAGE_ICON_256.PNG:PACKAGE_ICON_256.PNG"
)

# Fichiers qui vont dans scripts/ du SPK (pas dans package.tgz)
declare -a SCRIPT_MAPPINGS=(
    "dsm-control.sh:scripts/start-stop-status"
    "service-setup.sh:scripts/service-setup"
)

# Fichiers wizard (dans WIZARD_UIFILES/)
declare -a WIZARD_MAPPINGS=(
    "wizard/install_uifile:WIZARD_UIFILES/install_uifile"
    "wizard/uninstall_uifile:WIZARD_UIFILES/uninstall_uifile"
)

# Métadonnées du package (description et changelog)
DESCRIPTION="Pterodactyl Panel pour Synology avec Wings daemon intégré. Configuration Wings: 1) Connectez-vous au Panel 2) Admin → Nodes → Create New 3) Copiez la configuration YAML 4) Dans le Menu DSM, cliquez sur Configurer Wings et collez la configuration."
CHANGELOG="Nouvelles icônes officielles Pterodactyl. Interface de configuration Wings intégrée."

# Trouver le SPK le plus récent
find_latest_spk() {
    local latest=$(ls -t "${DIST_DIR}"/pterodactyl_panel_${ARCH}-${TCVERSION}_*.spk 2>/dev/null | head -1)
    if [[ -z "$latest" ]]; then
        log_error "Aucun SPK trouvé dans ${DIST_DIR}"
        exit 1
    fi
    echo "$latest"
}

# Extraire la version actuelle du nom de fichier
get_current_version() {
    local spk_name="$1"
    basename "$spk_name" | sed -E 's/pterodactyl_panel_[^_]+_([0-9.]+-[0-9]+)\.spk/\1/'
}

# Incrémenter le numéro de build
increment_version() {
    local version="$1"
    local base=$(echo "$version" | cut -d'-' -f1)
    local build=$(echo "$version" | cut -d'-' -f2)
    local new_build=$((build + 1))
    echo "${base}-${new_build}"
}

# Nettoyage
cleanup() {
    if [[ -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT

# Main
main() {
    log_info "Recherche du SPK existant..."
    local current_spk=$(find_latest_spk)
    local current_version=$(get_current_version "$current_spk")
    local new_version=$(increment_version "$current_version")

    log_info "Version actuelle : ${current_version}"
    log_info "Nouvelle version : ${new_version}"

    # Créer le répertoire temporaire
    cleanup
    mkdir -p "$TMP_DIR"

    # Extraire le SPK
    log_info "Extraction du SPK..."
    cd "$TMP_DIR"
    tar -xf "$current_spk"

    # Extraire package.tgz
    mkdir -p package
    cd package
    tar -xzf ../package.tgz

    # Copier les fichiers sources modifiés dans package.tgz
    log_info "Mise à jour des fichiers dans package.tgz..."
    local files_updated=0

    for mapping in "${FILE_MAPPINGS[@]}"; do
        local src_file="${SRC_DIR}/${mapping%%:*}"
        local dest_file="${TMP_DIR}/package/${mapping#*:}"

        if [[ -f "$src_file" ]]; then
            if [[ -f "$dest_file" ]]; then
                if ! cmp -s "$src_file" "$dest_file"; then
                    cp "$src_file" "$dest_file"
                    # Fix permissions for CGI/scripts
                    if [[ "$dest_file" == *.cgi ]] || [[ "$dest_file" == *.sh ]]; then
                        chmod 755 "$dest_file"
                    fi
                    log_info "  Mis à jour : ${mapping%%:*}"
                    files_updated=$((files_updated + 1))
                fi
            else
                mkdir -p "$(dirname "$dest_file")"
                cp "$src_file" "$dest_file"
                # Fix permissions for CGI/scripts
                if [[ "$dest_file" == *.cgi ]] || [[ "$dest_file" == *.sh ]]; then
                    chmod 755 "$dest_file"
                fi
                log_info "  Ajouté : ${mapping%%:*}"
                files_updated=$((files_updated + 1))
            fi
        fi
    done

    # Recréer package.tgz
    log_info "Reconstruction de package.tgz..."
    cd "${TMP_DIR}/package"
    tar -czf ../package.tgz .
    cd "$TMP_DIR"
    rm -rf package

    # Copier les fichiers scripts du SPK
    log_info "Mise à jour des scripts SPK..."
    for mapping in "${SCRIPT_MAPPINGS[@]}"; do
        local src_file="${SRC_DIR}/${mapping%%:*}"
        local dest_file="${TMP_DIR}/${mapping#*:}"

        if [[ -f "$src_file" ]]; then
            if [[ -f "$dest_file" ]]; then
                if ! cmp -s "$src_file" "$dest_file"; then
                    cp "$src_file" "$dest_file"
                    log_info "  Mis à jour : ${mapping%%:*}"
                    files_updated=$((files_updated + 1))
                fi
            fi
        fi
    done

    # Copier les fichiers wizard du SPK
    log_info "Mise à jour des wizards SPK..."
    for mapping in "${WIZARD_MAPPINGS[@]}"; do
        local src_file="${SRC_DIR}/${mapping%%:*}"
        local dest_file="${TMP_DIR}/${mapping#*:}"

        if [[ -f "$src_file" ]]; then
            if [[ -f "$dest_file" ]]; then
                if ! cmp -s "$src_file" "$dest_file"; then
                    cp "$src_file" "$dest_file"
                    log_info "  Mis à jour : ${mapping%%:*}"
                    files_updated=$((files_updated + 1))
                fi
            fi
        fi
    done

    # Copier les icônes SPK (à la racine du SPK)
    log_info "Mise à jour des icônes SPK..."
    for mapping in "${ICON_MAPPINGS[@]}"; do
        local src_file="${SRC_DIR}/${mapping%%:*}"
        local dest_file="${TMP_DIR}/${mapping#*:}"

        if [[ -f "$src_file" ]]; then
            if [[ -f "$dest_file" ]]; then
                if ! cmp -s "$src_file" "$dest_file"; then
                    cp "$src_file" "$dest_file"
                    log_info "  Mis à jour : ${mapping%%:*}"
                    files_updated=$((files_updated + 1))
                fi
            else
                cp "$src_file" "$dest_file"
                log_info "  Ajouté : ${mapping%%:*}"
                files_updated=$((files_updated + 1))
            fi
        fi
    done

    # Calculer le nouveau checksum
    local new_checksum=$(md5sum package.tgz | cut -d' ' -f1)
    log_info "Nouveau checksum : ${new_checksum}"

    # Mettre à jour INFO
    log_info "Mise à jour du fichier INFO..."
    sed -i "s/^version=\".*\"/version=\"${new_version}\"/" INFO
    sed -i "s/^checksum=\".*\"/checksum=\"${new_checksum}\"/" INFO
    sed -i "s/^description=\".*\"/description=\"${DESCRIPTION}\"/" INFO
    sed -i "s/^changelog=\".*\"/changelog=\"${CHANGELOG}\"/" INFO

    if [[ $files_updated -eq 0 ]]; then
        log_warn "Aucun fichier modifié détecté (seule la version sera incrémentée)"
    fi

    # Créer le nouveau SPK
    local new_spk="${DIST_DIR}/pterodactyl_panel_${ARCH}-${TCVERSION}_${new_version}.spk"
    log_info "Création du nouveau SPK..."
    tar -cf "$new_spk" INFO PACKAGE_ICON.PNG PACKAGE_ICON_256.PNG WIZARD_UIFILES conf package.tgz scripts

    # Créer le fichier SHA256
    cd "$DIST_DIR"
    sha256sum "$(basename "$new_spk")" > "$(basename "$new_spk").sha256"

    # Supprimer l'ancien SPK
    if [[ "$current_spk" != "$new_spk" ]]; then
        rm -f "$current_spk" "${current_spk}.sha256"
        log_info "Ancien SPK supprimé"
    fi

    log_info "Terminé !"
    log_info "Nouveau paquet : ${new_spk}"
    ls -lh "$new_spk"
}

main "$@"
