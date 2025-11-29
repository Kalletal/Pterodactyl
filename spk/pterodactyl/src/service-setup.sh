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
    install -d -m 0770 "${DATA_DIR}/panel/var" 2>/dev/null || mkdir -p "${DATA_DIR}/panel/var"
    # Laravel storage structure (ignore permission errors for existing Docker-owned dirs)
    mkdir -p "${DATA_DIR}/panel/storage/app/packs" 2>/dev/null || true
    mkdir -p "${DATA_DIR}/panel/storage/clockwork" 2>/dev/null || true
    mkdir -p "${DATA_DIR}/panel/storage/debugbar" 2>/dev/null || true
    mkdir -p "${DATA_DIR}/panel/storage/framework/cache/data" 2>/dev/null || true
    mkdir -p "${DATA_DIR}/panel/storage/framework/sessions" 2>/dev/null || true
    mkdir -p "${DATA_DIR}/panel/storage/framework/views" 2>/dev/null || true
    mkdir -p "${DATA_DIR}/panel/storage/logs" 2>/dev/null || true
    chmod -R 0777 "${DATA_DIR}/panel/storage" 2>/dev/null || true
    mkdir -p "${DATA_DIR}/panel/logs" 2>/dev/null || true
    mkdir -p "${DATA_DIR}/wings" 2>/dev/null || true
    mkdir -p "${DATA_DIR}/database" 2>/dev/null || true
    mkdir -p "${DATA_DIR}/redis" 2>/dev/null || true
    mkdir -p "${DATA_DIR}/certs" 2>/dev/null || true
    install -d -m 0750 "${LOG_DIR}" 2>/dev/null || mkdir -p "${LOG_DIR}"
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
    docker stop pterodactyl_panel-panel pterodactyl_panel-db pterodactyl_panel-redis 2>/dev/null || true
}

service_postuninst()
{
    # Always cleanup containers and system files
    cleanup_package

    # Delete data if user chose to
    if [ "${wizard_delete_data}" = "true" ]; then
        # Use Docker to remove files owned by container users (uid 999, etc.)
        # This handles database, redis, and panel files owned by Docker
        docker run --rm -v "/var/packages/pterodactyl_panel/var/data:/data" alpine sh -c "rm -rf /data/*" 2>/dev/null || true
        docker run --rm -v "/var/packages/pterodactyl_panel/var:/data" alpine sh -c "rm -rf /data/*" 2>/dev/null || true
        rm -rf "/var/packages/pterodactyl_panel/var" 2>/dev/null || true
        rm -rf "/volume1/@appdata/pterodactyl_panel" 2>/dev/null || true
    fi
}
