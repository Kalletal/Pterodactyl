#!/bin/sh

# Pterodactyl Panel - DSM Start/Stop/Status Script

PACKAGE="pterodactyl_panel"
DNAME="Pterodactyl Panel"
INSTALL_DIR="/var/packages/${PACKAGE}/target"
VAR_DIR="/var/packages/${PACKAGE}/var"
LOG_FILE="${VAR_DIR}/${PACKAGE}.log"

# Docker compose paths
COMPOSE_FILE="${INSTALL_DIR}/share/docker/docker-compose.yml"
ENV_FILE="${VAR_DIR}/panel.env"

# Wings daemon paths
WINGS_BIN="${INSTALL_DIR}/bin/wings"
WINGS_CONFIG="${VAR_DIR}/data/wings/config.yml"
WINGS_PID_FILE="${VAR_DIR}/wings.pid"
WINGS_LOG="${VAR_DIR}/wings.log"

# Loading page
LOADING_SERVER="${INSTALL_DIR}/bin/loading-server.sh"
LOADING_HTML="${INSTALL_DIR}/share/loading.html"
PANEL_PORT="38080"
LOADING_PORT="38081"

PATH="${INSTALL_DIR}/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

log() {
    printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$1" >> "${LOG_FILE}" 2>/dev/null
}

start_loading_page()
{
    if [ -x "${LOADING_SERVER}" ] && [ -f "${LOADING_HTML}" ]; then
        log "Starting loading page server on port ${LOADING_PORT}..."
        "${LOADING_SERVER}" start "${LOADING_PORT}" "${LOADING_HTML}" >> "${LOG_FILE}" 2>&1
    fi
}

stop_loading_page()
{
    if [ -x "${LOADING_SERVER}" ]; then
        "${LOADING_SERVER}" stop >> "${LOG_FILE}" 2>&1
    fi
}

ensure_port_free()
{
    # Make sure port 38080 is free before starting containers
    # Note: Loading page runs on LOADING_PORT (38081), not PANEL_PORT (38080)
    log "Ensuring port ${PANEL_PORT} is free..."

    # Method 1: fuser (most reliable on Synology)
    if command -v fuser >/dev/null 2>&1; then
        fuser -k ${PANEL_PORT}/tcp 2>/dev/null
        sleep 1
    fi

    # Method 2: lsof
    PID_ON_PORT=$(lsof -t -i:${PANEL_PORT} 2>/dev/null)
    if [ -n "${PID_ON_PORT}" ]; then
        log "Killing process ${PID_ON_PORT} on port ${PANEL_PORT}"
        kill -9 ${PID_ON_PORT} 2>/dev/null
        sleep 1
    fi

    # Method 3: netstat + kill
    PID_ON_PORT=$(netstat -tlnp 2>/dev/null | grep ":${PANEL_PORT} " | awk '{print $7}' | cut -d'/' -f1)
    if [ -n "${PID_ON_PORT}" ] && [ "${PID_ON_PORT}" != "-" ]; then
        log "Killing process ${PID_ON_PORT} on port ${PANEL_PORT} (netstat)"
        kill -9 ${PID_ON_PORT} 2>/dev/null
        sleep 1
    fi

    # Verify port is free
    if netstat -tlnp 2>/dev/null | grep -q ":${PANEL_PORT} "; then
        log "WARNING: Port ${PANEL_PORT} still in use after cleanup attempts"
        return 1
    fi

    log "Port ${PANEL_PORT} is free"
    return 0
}

is_first_install()
{
    # Check if database directory is empty (first install)
    [ ! -d "${VAR_DIR}/data/database" ] || [ -z "$(ls -A ${VAR_DIR}/data/database 2>/dev/null)" ]
}

wait_for_panel()
{
    # Wait up to 90 seconds for panel to respond
    log "Waiting for Panel to be ready..."
    for i in $(seq 1 30); do
        if curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PANEL_PORT}" 2>/dev/null | grep -qE "^(200|302|301)"; then
            log "Panel is ready!"
            # Stop the loading page now that Panel is available
            stop_loading_page
            return 0
        fi
        sleep 3
    done
    log "Panel startup timeout (may still be initializing)"
    # Stop loading page anyway after timeout
    stop_loading_page
    return 1
}

start_containers()
{
    if [ ! -f "${COMPOSE_FILE}" ]; then
        log "ERROR: docker-compose.yml not found at ${COMPOSE_FILE}"
        return 1
    fi
    if [ ! -f "${ENV_FILE}" ]; then
        log "ERROR: panel.env not found at ${ENV_FILE}"
        return 1
    fi

    # Check if containers are already running
    if containers_running; then
        log "Docker containers already running"
        return 0
    fi

    # Always show loading page while containers start
    log "Starting loading page while containers initialize..."
    start_loading_page

    # Pull images (can take a while on first install)
    log "Pulling Docker images..."
    docker-compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" -p "${PACKAGE}" pull >> "${LOG_FILE}" 2>&1

    # Ensure port is free before starting containers
    ensure_port_free

    log "Starting Docker containers..."
    docker-compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" -p "${PACKAGE}" up -d >> "${LOG_FILE}" 2>&1

    # Wait for panel to be ready (especially important on first install for migrations)
    wait_for_panel

    log "Docker containers started"
}

stop_containers()
{
    log "Stopping Docker containers..."

    # Method 1: Try docker-compose down
    if [ -f "${COMPOSE_FILE}" ] && [ -f "${ENV_FILE}" ]; then
        docker-compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" -p "${PACKAGE}" down >> "${LOG_FILE}" 2>&1
    fi

    # Method 2: Force stop any remaining containers with our name
    CONTAINERS=$(docker ps -q --filter "name=${PACKAGE}" 2>/dev/null)
    if [ -n "${CONTAINERS}" ]; then
        log "Force stopping remaining containers..."
        docker stop ${CONTAINERS} >> "${LOG_FILE}" 2>&1
        docker rm -f ${CONTAINERS} >> "${LOG_FILE}" 2>&1
    fi

    # Verify containers are stopped
    if containers_running; then
        log "WARNING: Some containers may still be running"
    else
        log "Docker containers stopped"
    fi
}

containers_running()
{
    docker ps --filter "name=${PACKAGE}" --format '{{.Names}}' 2>/dev/null | grep -q "${PACKAGE}"
}

start_wings()
{
    if [ ! -x "${WINGS_BIN}" ]; then
        log "Wings binary not found at ${WINGS_BIN}"
        return 0
    fi
    if [ ! -f "${WINGS_CONFIG}" ]; then
        log "Wings config not found at ${WINGS_CONFIG}, skipping Wings startup"
        echo "${DNAME}: Wings not configured. Configure via Panel after first login." >&2
        return 0
    fi
    if [ -f "${WINGS_PID_FILE}" ] && kill -0 "$(cat "${WINGS_PID_FILE}")" 2>/dev/null; then
        log "Wings already running"
        return 0
    fi
    # Start Wings daemon in background
    "${WINGS_BIN}" --config "${WINGS_CONFIG}" >> "${WINGS_LOG}" 2>&1 &
    echo $! > "${WINGS_PID_FILE}"
    log "Wings daemon started (PID: $!)"
}

stop_wings()
{
    if [ -f "${WINGS_PID_FILE}" ]; then
        PID=$(cat "${WINGS_PID_FILE}")
        if kill -0 "${PID}" 2>/dev/null; then
            kill "${PID}" 2>/dev/null
            sleep 2
            # Force kill if still running
            if kill -0 "${PID}" 2>/dev/null; then
                kill -9 "${PID}" 2>/dev/null
            fi
            log "Wings daemon stopped"
        fi
        rm -f "${WINGS_PID_FILE}"
    fi
}

wings_running()
{
    [ -f "${WINGS_PID_FILE}" ] && kill -0 "$(cat "${WINGS_PID_FILE}")" 2>/dev/null
}

case "$1" in
    start)
        echo "Starting ${DNAME}"
        log "Starting ${DNAME}"
        start_containers
        start_wings
        exit 0
        ;;
    stop)
        echo "Stopping ${DNAME}"
        log "Stopping ${DNAME}"
        stop_wings
        stop_containers
        stop_loading_page
        # Kill any remaining Python HTTP servers on loading port
        pkill -9 -f "python.*${LOADING_PORT}" 2>/dev/null || true
        pkill -9 -f "http.server.*${LOADING_PORT}" 2>/dev/null || true
        exit 0
        ;;
    status)
        if containers_running; then
            echo "${DNAME} is running"
            exit 0
        else
            echo "${DNAME} is not running"
            exit 1
        fi
        ;;
    restart)
        $0 stop
        sleep 2
        $0 start
        ;;
    log)
        tail -n 200 -f "${LOG_FILE}"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|log}"
        exit 1
        ;;
esac
