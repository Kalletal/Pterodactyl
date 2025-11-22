#!/bin/sh

PACKAGE="pterodactyl"
DNAME="Pterodactyl"
INSTALL_DIR="/var/packages/${PACKAGE}/target"
VAR_DIR="/var/packages/${PACKAGE}/var"
COMPOSE_DIR="${INSTALL_DIR}/share/docker"
COMPOSE_FILE="${COMPOSE_DIR}/docker-compose.yml"
ENV_FILE="${VAR_DIR}/panel.env"
LOG_FILE="${VAR_DIR}/${PACKAGE}.log"
PID_FILE="${VAR_DIR}/${PACKAGE}.pid"
PROJECT_NAME="pterodactyl"

PATH="${INSTALL_DIR}/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

log() {
    printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$1" >> "${LOG_FILE}" 2>/dev/null
}

ensure_env()
{
    if [ ! -f "${ENV_FILE}" ]; then
        echo "${DNAME}: missing ${ENV_FILE}, aborting" >&2
        exit 1
    fi
    # shellcheck disable=SC2046
    set -a
    . "${ENV_FILE}"
    set +a
    if [ -n "${COMPOSE_PROJECT}" ]; then
        PROJECT_NAME="${COMPOSE_PROJECT}"
    fi
}

compose_cmd()
{
    if docker compose version >/dev/null 2>&1; then
        docker compose --project-name "${PROJECT_NAME}" --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" "$@"
    elif command -v docker-compose >/dev/null 2>&1; then
        docker-compose --project-name "${PROJECT_NAME}" -f "${COMPOSE_FILE}" "$@"
    else
        echo "${DNAME}: docker compose plugin missing" >&2
        exit 1
    fi
}

ensure_docker()
{
    if ! docker info >/dev/null 2>&1; then
        echo "${DNAME}: Docker daemon is not available. Please start the Docker package." >&2
        exit 1
    fi
}

start_daemon()
{
    ensure_env
    ensure_docker
    compose_cmd pull panel wings panel-db panel-redis >/dev/null 2>&1 || true
    compose_cmd up -d --remove-orphans
    echo $$ > "${PID_FILE}"
    log "stack started"
}

stop_daemon()
{
    ensure_env
    compose_cmd down
    rm -f "${PID_FILE}"
    log "stack stopped"
}

active_containers()
{
    docker ps --filter "label=com.docker.compose.project=${PROJECT_NAME}" --filter "status=running" -q
}

daemon_status()
{
    ensure_env
    if [ -n "$(active_containers)" ]; then
        return 0
    fi
    rm -f "${PID_FILE}"
    return 1
}

wait_for_status()
{
    goal=$1
    timeout=$2
    while [ ${timeout} -gt 0 ]; do
        daemon_status
        [ $? -eq ${goal} ] && return 0
        timeout=$((timeout-1))
        sleep 1
    done
    return 1
}

case "$1" in
    start)
        if daemon_status; then
            echo "${DNAME} already running"
            exit 0
        fi
        echo "Starting ${DNAME}"
        start_daemon
        ;;
    stop)
        if daemon_status; then
            echo "Stopping ${DNAME}"
            stop_daemon
        else
            echo "${DNAME} is not running"
        fi
        ;;
    status)
        if daemon_status; then
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
