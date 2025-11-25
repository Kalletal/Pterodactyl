#!/bin/sh

# Pterodactyl Panel - DSM Start/Stop/Status Script
# Docker containers are managed by DSM Docker Worker (conf/resource)
# This script only manages the Wings daemon (native binary)

PACKAGE="ptero"
DNAME="Ptero"
INSTALL_DIR="/var/packages/${PACKAGE}/target"
VAR_DIR="/var/packages/${PACKAGE}/var"
LOG_FILE="${VAR_DIR}/${PACKAGE}.log"

# Wings daemon paths
WINGS_BIN="${INSTALL_DIR}/bin/wings"
WINGS_CONFIG="${VAR_DIR}/data/wings/config.yml"
WINGS_PID_FILE="${VAR_DIR}/wings.pid"
WINGS_LOG="${VAR_DIR}/wings.log"

PATH="${INSTALL_DIR}/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

log() {
    printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$1" >> "${LOG_FILE}" 2>/dev/null
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
        log "Starting ${DNAME} (Docker containers managed by DSM)"
        # Docker containers are started by DSM Docker Worker
        # Only start Wings if configured
        start_wings
        exit 0
        ;;
    stop)
        echo "Stopping ${DNAME}"
        log "Stopping ${DNAME}"
        # Stop Wings daemon
        stop_wings
        # Docker containers are stopped by DSM Docker Worker
        exit 0
        ;;
    status)
        # For DSM, we report running if the package is active
        # Docker containers status is managed by DSM
        echo "${DNAME} is running"
        exit 0
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
