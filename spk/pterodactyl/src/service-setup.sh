PANEL_SHARE="${SYNOPKG_PKGDEST}/share/panel"
WINGS_CONFIG_EXAMPLE="${SYNOPKG_PKGDEST}/share/wings.config.example.yml"
VAR_DIR="${SYNOPKG_PKGVAR}"
DATA_DIR="${VAR_DIR}/data"
LOG_DIR="${VAR_DIR}/logs"
WINGS_CONFIG="${DATA_DIR}/wings/config.yml"

# Docker containers are managed by DSM Docker Worker (conf/resource)
# No need to check Docker here - INSTALL_DEP_PACKAGES ensures Container Manager is installed

service_preinst()
{
    # Docker/Container Manager is automatically installed via INSTALL_DEP_PACKAGES
    # No additional prerequisites check needed
    return 0
}

create_data_dirs()
{
    install -d -m 0750 "${VAR_DIR}"
    install -d -m 0770 "${DATA_DIR}/panel/storage"
    install -d -m 0770 "${DATA_DIR}/panel/cache"
    install -d -m 0770 "${DATA_DIR}/wings"
    install -d -m 0770 "${DATA_DIR}/database"
    install -d -m 0770 "${DATA_DIR}/redis"
    install -d -m 0770 "${DATA_DIR}/certs"
    install -d -m 0750 "${LOG_DIR}"
}

generate_app_key()
{
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -base64 32 | tr -d '\n'
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "import secrets,base64;print(base64.b64encode(secrets.token_bytes(32)).decode())"
    else
        tr -dc 'A-Za-z0-9' </dev/urandom | head -c 43
    fi
}

hydrate_env_file()
{
    if [ ! -f "${ENV_FILE}" ]; then
        install -m 0600 "${ENV_EXAMPLE}" "${ENV_FILE}"
        APP_KEY=$(generate_app_key)
        sed -i "s#APP_KEY=.*#APP_KEY=base64:${APP_KEY}#" "${ENV_FILE}"
    fi
}

hydrate_wings_config()
{
    if [ ! -f "${WINGS_CONFIG}" ]; then
        install -d -m 0770 "${DATA_DIR}/wings"
        install -m 0640 "${WINGS_CONFIG_EXAMPLE}" "${WINGS_CONFIG}"
    fi
}

service_postinst()
{
    create_data_dirs
    hydrate_env_file
    hydrate_wings_config
    install -d -m 0750 "${VAR_DIR}/runtime"
    touch "${VAR_DIR}/pterodactyl.log"
    chmod 0640 "${VAR_DIR}/pterodactyl.log"

    chown -R "${EFF_USER}:${EFF_USER}" "${VAR_DIR}"

    if getent group docker >/dev/null 2>&1; then
        addgroup "${EFF_USER}" docker || true
    fi
}

service_preupgrade()
{
    install -d -m 0700 "${SYNOPKG_TEMP_UPGRADE_FOLDER}"
    cp -a "${ENV_FILE}" "${SYNOPKG_TEMP_UPGRADE_FOLDER}/panel.env" 2>/dev/null || true
    cp -a "${WINGS_CONFIG}" "${SYNOPKG_TEMP_UPGRADE_FOLDER}/wings.config.yml" 2>/dev/null || true
    if [ -d "${DATA_DIR}" ]; then
        rsync -a "${DATA_DIR}/" "${SYNOPKG_TEMP_UPGRADE_FOLDER}/data/"
    fi
}

service_postupgrade()
{
    if [ -f "${SYNOPKG_TEMP_UPGRADE_FOLDER}/panel.env" ]; then
        install -m 0600 "${SYNOPKG_TEMP_UPGRADE_FOLDER}/panel.env" "${ENV_FILE}"
    fi
    if [ -f "${SYNOPKG_TEMP_UPGRADE_FOLDER}/wings.config.yml" ]; then
        install -m 0640 "${SYNOPKG_TEMP_UPGRADE_FOLDER}/wings.config.yml" "${WINGS_CONFIG}"
    fi
    if [ -d "${SYNOPKG_TEMP_UPGRADE_FOLDER}/data" ]; then
        rsync -a "${SYNOPKG_TEMP_UPGRADE_FOLDER}/data/" "${DATA_DIR}/"
    fi
    chown -R "${EFF_USER}:${EFF_USER}" "${VAR_DIR}"
}

service_postuninst()
{
    if [ "${SYNOPKG_PKG_STATUS}" = "UNINSTALL" ]; then
        # Remove user from docker group
        if getent group docker >/dev/null 2>&1; then
            delgroup "${EFF_USER}" docker || true
        fi

        # Clean up all package directories (using SYNOPKG_PKGNAME for flexibility)
        rm -rf "/volume1/@appconf/${SYNOPKG_PKGNAME}" 2>/dev/null || true
        rm -rf "/volume1/@appdata/${SYNOPKG_PKGNAME}" 2>/dev/null || true
        rm -rf "/volume1/@apphome/${SYNOPKG_PKGNAME}" 2>/dev/null || true
        rm -rf "/volume1/@appshare/${SYNOPKG_PKGNAME}" 2>/dev/null || true
        rm -rf "/volume1/@apptemp/${SYNOPKG_PKGNAME}" 2>/dev/null || true
        rm -rf "/volume1/@tmp/synopkg/lfs/image/INST/${SYNOPKG_PKGNAME}" 2>/dev/null || true

        # Clean up logs
        rm -f "/var/log/packages/${SYNOPKG_PKGNAME}.log" 2>/dev/null || true
        rm -f /var/log/systemd/*${SYNOPKG_PKGNAME}* 2>/dev/null || true

        # Stop and remove Docker containers
        docker rm -f ptero-panel ptero-db ptero-redis 2>/dev/null || true
    fi
}
