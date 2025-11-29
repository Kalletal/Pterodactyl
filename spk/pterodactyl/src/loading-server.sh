#!/bin/sh
# Simple HTTP server for loading page during startup

PACKAGE="pterodactyl_panel"
VAR_DIR="/var/packages/${PACKAGE}/var"
PID_FILE="${VAR_DIR}/loading-server.pid"
HTTPD_ROOT="/tmp/pterodactyl_loading"
LOG_FILE="${VAR_DIR}/${PACKAGE}.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [loading-server] $1" >> "${LOG_FILE}" 2>/dev/null
    echo "$1"
}

start_server() {
    port="${1:-38080}"
    html_file="${2:-/var/packages/${PACKAGE}/target/share/loading.html}"

    log "Starting loading server on port ${port}"
    log "HTML file: ${html_file}"

    # Check HTML file exists
    if [ ! -f "${html_file}" ]; then
        log "Error: ${html_file} not found"
        return 1
    fi

    # Stop any existing server first
    stop_server 2>/dev/null

    # Create serving directory and copy HTML
    rm -rf "${HTTPD_ROOT}"
    mkdir -p "${HTTPD_ROOT}"
    cp "${html_file}" "${HTTPD_ROOT}/index.html"

    if [ ! -f "${HTTPD_ROOT}/index.html" ]; then
        log "Error: Failed to copy HTML file to ${HTTPD_ROOT}"
        return 1
    fi
    log "HTML copied to ${HTTPD_ROOT}/index.html"

    # Method 1: Try python3 (most reliable)
    if command -v python3 >/dev/null 2>&1; then
        log "Using python3 http.server on 0.0.0.0:${port}"
        cd "${HTTPD_ROOT}"
        python3 -m http.server "${port}" --bind 0.0.0.0 >> "${LOG_FILE}" 2>&1 &
        SERVER_PID=$!
        echo "${SERVER_PID}" > "${PID_FILE}"
        sleep 1
        if kill -0 "${SERVER_PID}" 2>/dev/null; then
            log "Loading server started (python3, PID: ${SERVER_PID})"
            return 0
        else
            log "python3 server failed to start"
        fi
    fi

    # Method 2: Try php built-in server
    if command -v php >/dev/null 2>&1; then
        log "Using php built-in server"
        cd "${HTTPD_ROOT}"
        php -S "0.0.0.0:${port}" >> "${LOG_FILE}" 2>&1 &
        SERVER_PID=$!
        echo "${SERVER_PID}" > "${PID_FILE}"
        sleep 1
        if kill -0 "${SERVER_PID}" 2>/dev/null; then
            log "Loading server started (php, PID: ${SERVER_PID})"
            return 0
        else
            log "php server failed to start"
        fi
    fi

    # Method 3: Try socat
    if command -v socat >/dev/null 2>&1; then
        log "Using socat"
        (
            while [ -f "${PID_FILE}" ]; do
                socat TCP-LISTEN:"${port}",reuseaddr,fork SYSTEM:"echo 'HTTP/1.1 200 OK'; echo 'Content-Type: text/html'; echo ''; cat ${HTTPD_ROOT}/index.html" 2>/dev/null
            done
        ) &
        SERVER_PID=$!
        echo "${SERVER_PID}" > "${PID_FILE}"
        log "Loading server started (socat, PID: ${SERVER_PID})"
        return 0
    fi

    log "Error: No suitable HTTP server found (tried python3, php, socat)"
    return 1
}

stop_server() {
    if [ -f "${PID_FILE}" ]; then
        PID=$(cat "${PID_FILE}" 2>/dev/null)
        if [ -n "${PID}" ]; then
            log "Stopping loading server (PID: ${PID})"
            kill "${PID}" 2>/dev/null
            sleep 1
            kill -9 "${PID}" 2>/dev/null
        fi
        rm -f "${PID_FILE}"
    fi
    rm -rf "${HTTPD_ROOT}"
    log "Loading server stopped"
}

case "$1" in
    start)
        shift
        start_server "$@"
        ;;
    stop)
        stop_server
        ;;
    *)
        echo "Usage: $0 {start|stop} [port] [html_file]"
        exit 1
        ;;
esac
