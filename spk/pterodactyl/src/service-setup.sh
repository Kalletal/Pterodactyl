PANEL_SHARE="${SYNOPKG_PKGDEST}/share/panel"
WINGS_CONFIG_EXAMPLE="${SYNOPKG_PKGDEST}/share/wings.config.example.yml"
ENV_EXAMPLE="${SYNOPKG_PKGDEST}/share/panel.env.example"
VAR_DIR="${SYNOPKG_PKGVAR}"
DATA_DIR="${VAR_DIR}/data"
LOG_DIR="${VAR_DIR}/logs"
ENV_FILE="${VAR_DIR}/panel.env"
WINGS_CONFIG="${DATA_DIR}/wings/config.yml"

# Cleanup function - called on uninstall or failed install
cleanup_package()
{
    # Stop and remove Docker containers
    docker rm -f pteropanel-panel pteropanel-db pteropanel-redis 2>/dev/null || true

    # Remove user from docker group
    if getent group docker >/dev/null 2>&1 && [ -n "${EFF_USER}" ]; then
        delgroup "${EFF_USER}" docker 2>/dev/null || true
    fi

    # Clean up all package directories
    local pkg="${SYNOPKG_PKGNAME:-pteropanel}"
    rm -rf "/volume1/@appconf/${pkg}" 2>/dev/null || true
    rm -rf "/volume1/@appdata/${pkg}" 2>/dev/null || true
    rm -rf "/volume1/@apphome/${pkg}" 2>/dev/null || true
    rm -rf "/volume1/@appshare/${pkg}" 2>/dev/null || true
    rm -rf "/volume1/@apptemp/${pkg}" 2>/dev/null || true
    rm -rf "/volume1/@tmp/synopkg/lfs/image/INST/${pkg}" 2>/dev/null || true
    rm -f "/run/synopkg/lock/${pkg}.lock" 2>/dev/null || true

    # Clean up system files
    rm -rf "/usr/syno/etc/packages/${pkg}" 2>/dev/null || true
    rm -rf "/usr/syno/synoman/webman/3rdparty/${pkg}" 2>/dev/null || true
    rm -f "/usr/local/etc/services.d/${pkg}.sc" 2>/dev/null || true

    # Clean up logs
    rm -f "/var/log/packages/${pkg}.log" 2>/dev/null || true
    rm -f /var/log/systemd/*${pkg}* 2>/dev/null || true
}

service_preinst()
{
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
    if [ ! -f "${ENV_FILE}" ] && [ -f "${ENV_EXAMPLE}" ]; then
        install -m 0600 "${ENV_EXAMPLE}" "${ENV_FILE}"
        APP_KEY=$(generate_app_key)
        sed -i "s#APP_KEY=.*#APP_KEY=base64:${APP_KEY}#" "${ENV_FILE}"
    fi
}

hydrate_wings_config()
{
    if [ ! -f "${WINGS_CONFIG}" ] && [ -f "${WINGS_CONFIG_EXAMPLE}" ]; then
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
    touch "${VAR_DIR}/ptero.log"
    chmod 0640 "${VAR_DIR}/ptero.log"

    if [ -n "${EFF_USER}" ]; then
        chown -R "${EFF_USER}:${EFF_USER}" "${VAR_DIR}" 2>/dev/null || true
    fi

    if getent group docker >/dev/null 2>&1 && [ -n "${EFF_USER}" ]; then
        addgroup "${EFF_USER}" docker 2>/dev/null || true
    fi
}

service_preupgrade()
{
    if [ -d "${SYNOPKG_TEMP_UPGRADE_FOLDER}" ]; then
        cp -a "${ENV_FILE}" "${SYNOPKG_TEMP_UPGRADE_FOLDER}/panel.env" 2>/dev/null || true
        cp -a "${WINGS_CONFIG}" "${SYNOPKG_TEMP_UPGRADE_FOLDER}/wings.config.yml" 2>/dev/null || true
        if [ -d "${DATA_DIR}" ]; then
            rsync -a "${DATA_DIR}/" "${SYNOPKG_TEMP_UPGRADE_FOLDER}/data/" 2>/dev/null || true
        fi
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
        rsync -a "${SYNOPKG_TEMP_UPGRADE_FOLDER}/data/" "${DATA_DIR}/" 2>/dev/null || true
    fi
    if [ -n "${EFF_USER}" ]; then
        chown -R "${EFF_USER}:${EFF_USER}" "${VAR_DIR}" 2>/dev/null || true
    fi
}

service_preuninst()
{
    # Stop containers before uninstall
    docker stop pteropanel-panel pteropanel-db pteropanel-redis 2>/dev/null || true
}

service_postuninst()
{
    # Always cleanup on uninstall
    cleanup_package
}
