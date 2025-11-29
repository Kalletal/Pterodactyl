PANEL_SHARE="${SYNOPKG_PKGDEST}/share/panel"
WINGS_CONFIG_EXAMPLE="${SYNOPKG_PKGDEST}/share/wings.config.example.yml"
ENV_EXAMPLE="${SYNOPKG_PKGDEST}/share/panel.env.example"
LANG_DIR_SRC="${SYNOPKG_PKGDEST}/share/lang"
VAR_DIR="${SYNOPKG_PKGVAR}"
DATA_DIR="${VAR_DIR}/data"
LOG_DIR="${VAR_DIR}/logs"
ENV_FILE="${VAR_DIR}/panel.env"
WINGS_CONFIG="${DATA_DIR}/wings/config.yml"
LANG_DIR="${DATA_DIR}/lang"

# Cleanup function - called on uninstall or failed install
cleanup_package()
{
    # Stop and remove Docker containers (try both naming conventions)
    docker rm -f pterodactyl_panel-panel-1 pterodactyl_panel-panel-db-1 pterodactyl_panel-panel-redis-1 2>/dev/null || true
    docker rm -f pterodactyl_panel-panel pterodactyl_panel-db pterodactyl_panel-redis 2>/dev/null || true

    # Remove Docker network
    docker network rm pterodactyl_panel_pterodactyl 2>/dev/null || true

    # Remove user from docker group
    if getent group docker >/dev/null 2>&1 && [ -n "${EFF_USER}" ]; then
        delgroup "${EFF_USER}" docker 2>/dev/null || true
    fi
}

service_preinst()
{
    return 0
}

create_data_dirs()
{
    install -d -m 0750 "${VAR_DIR}"
    # Panel directories (matching official docker-compose volumes)
    mkdir -p "${DATA_DIR}/panel/var" 2>/dev/null || true
    mkdir -p "${DATA_DIR}/panel/nginx" 2>/dev/null || true
    mkdir -p "${DATA_DIR}/panel/logs" 2>/dev/null || true
    mkdir -p "${DATA_DIR}/certs" 2>/dev/null || true
    # Wings directory
    mkdir -p "${DATA_DIR}/wings" 2>/dev/null || true
    # Database and cache
    mkdir -p "${DATA_DIR}/database" 2>/dev/null || true
    mkdir -p "${DATA_DIR}/redis" 2>/dev/null || true
    # Language files directory
    mkdir -p "${LANG_DIR}/fr" 2>/dev/null || true
    # Package logs
    install -d -m 0750 "${LOG_DIR}" 2>/dev/null || mkdir -p "${LOG_DIR}"
}

copy_lang_files()
{
    # Copy French translation files if they exist
    if [ -d "${LANG_DIR_SRC}/fr" ]; then
        cp -r "${LANG_DIR_SRC}/fr/"* "${LANG_DIR}/fr/" 2>/dev/null || true
    fi
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

        # Generate APP_KEY
        APP_KEY=$(generate_app_key)
        sed -i "s#APP_KEY=.*#APP_KEY=base64:${APP_KEY}#" "${ENV_FILE}"

        # Apply wizard values (port is fixed at 38080)
        local app_host="${wizard_app_host:-localhost}"
        local app_url="http://${app_host}:38080"
        local db_pass="${wizard_db_password:-changeMeNow!}"
        local db_root_pass="${wizard_db_root_password:-ChangeRootPassword!}"

        sed -i "s#APP_URL=.*#APP_URL=${app_url}#" "${ENV_FILE}"
        sed -i "s#DB_PASSWORD=.*#DB_PASSWORD=${db_pass}#" "${ENV_FILE}"
        sed -i "s#DB_ROOT_PASSWORD=.*#DB_ROOT_PASSWORD=${db_root_pass}#" "${ENV_FILE}"

        # Admin account configuration
        local admin_email="${wizard_admin_email:-admin@example.com}"
        local admin_username="${wizard_admin_username:-admin}"
        local admin_password="${wizard_admin_password:-ChangeMe123!}"

        sed -i "s#APP_SETUP_ADMIN_EMAIL=.*#APP_SETUP_ADMIN_EMAIL=${admin_email}#" "${ENV_FILE}"
        sed -i "s#APP_SETUP_ADMIN_USERNAME=.*#APP_SETUP_ADMIN_USERNAME=${admin_username}#" "${ENV_FILE}"
        sed -i "s#APP_SETUP_ADMIN_PASSWORD=.*#APP_SETUP_ADMIN_PASSWORD=${admin_password}#" "${ENV_FILE}"

        # Language configuration
        local app_locale="${wizard_app_locale:-fr}"
        sed -i "s#APP_LOCALE=.*#APP_LOCALE=${app_locale}#" "${ENV_FILE}"
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
    copy_lang_files
    hydrate_env_file
    hydrate_wings_config
    install -d -m 0750 "${VAR_DIR}/runtime"
    touch "${VAR_DIR}/ptero.log"
    chmod 0640 "${VAR_DIR}/ptero.log"

    # Only chown specific files, not recursively (Docker manages its own data permissions)
    if [ -n "${EFF_USER}" ]; then
        chown "${EFF_USER}:${EFF_USER}" "${VAR_DIR}" "${LOG_DIR}" "${VAR_DIR}/runtime" 2>/dev/null || true
        chown "${EFF_USER}:${EFF_USER}" "${ENV_FILE}" "${VAR_DIR}/ptero.log" 2>/dev/null || true
        chown "${EFF_USER}:${EFF_USER}" "${WINGS_CONFIG}" 2>/dev/null || true
        chown -R "${EFF_USER}:${EFF_USER}" "${LANG_DIR}" 2>/dev/null || true
    fi

    if getent group docker >/dev/null 2>&1 && [ -n "${EFF_USER}" ]; then
        addgroup "${EFF_USER}" docker 2>/dev/null || true
    fi
}

service_preupgrade()
{
    # Only backup config files - Docker data is persistent and doesn't need copying
    if [ -d "${SYNOPKG_TEMP_UPGRADE_FOLDER}" ]; then
        cp -a "${ENV_FILE}" "${SYNOPKG_TEMP_UPGRADE_FOLDER}/panel.env" 2>/dev/null || true
        cp -a "${WINGS_CONFIG}" "${SYNOPKG_TEMP_UPGRADE_FOLDER}/wings.config.yml" 2>/dev/null || true
    fi
}

service_postupgrade()
{
    # Restore config files only - Docker data stays in place
    if [ -f "${SYNOPKG_TEMP_UPGRADE_FOLDER}/panel.env" ]; then
        install -m 0600 "${SYNOPKG_TEMP_UPGRADE_FOLDER}/panel.env" "${ENV_FILE}"
    fi
    if [ -f "${SYNOPKG_TEMP_UPGRADE_FOLDER}/wings.config.yml" ]; then
        install -m 0640 "${SYNOPKG_TEMP_UPGRADE_FOLDER}/wings.config.yml" "${WINGS_CONFIG}"
    fi
    # Only chown config files, not the entire data directory
    if [ -n "${EFF_USER}" ]; then
        chown "${EFF_USER}:${EFF_USER}" "${ENV_FILE}" 2>/dev/null || true
        chown "${EFF_USER}:${EFF_USER}" "${WINGS_CONFIG}" 2>/dev/null || true
    fi
}

service_preuninst()
{
    # Stop containers quickly (1 second timeout instead of default 10)
    docker stop -t 1 pterodactyl_panel-panel-1 pterodactyl_panel-panel-db-1 pterodactyl_panel-panel-redis-1 2>/dev/null || true
    docker stop -t 1 pterodactyl_panel-panel pterodactyl_panel-db pterodactyl_panel-redis 2>/dev/null || true
}

service_postuninst()
{
    # Always cleanup containers and system files
    cleanup_package

    # Delete data if user chose to
    if [ "${wizard_delete_data}" = "true" ]; then
        # Database files are owned by mysql user (uid 999) inside container
        # Use busybox image (lightweight) to delete with proper permissions
        docker run --rm -v "/var/packages/pterodactyl_panel/var/data/database:/data" busybox rm -rf /data/* 2>/dev/null || true
        docker run --rm -v "/var/packages/pterodactyl_panel/var/data/redis:/data" busybox rm -rf /data/* 2>/dev/null || true
        # Now remove the rest with normal permissions
        rm -rf "/var/packages/pterodactyl_panel/var" 2>/dev/null || true
        rm -rf "/volume1/@appdata/pterodactyl_panel" 2>/dev/null || true
    fi
}
