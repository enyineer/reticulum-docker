#!/usr/bin/env bash
set -Eeuo pipefail

APP_USER="rns"
APP_GROUP="rns"
PUID="${PUID:-10001}"
PGID="${PGID:-10001}"
DATA_DIR="${DATA_DIR:-/home/${APP_USER}/.reticulum}"
STORAGE_DIR="${DATA_DIR%/}/storage"

log(){ echo "[entrypoint] $*"; }

log "PUID=${PUID} PGID=${PGID} DATA_DIR=${DATA_DIR}"

# Ensure dialout for /dev/ttyUSB*
if getent group dialout >/dev/null 2>&1; then
  usermod -aG dialout "${APP_USER}" || true
fi

# Try to remap rns uid/gid to PUID/PGID (best-effort)
if getent group "${APP_GROUP}" >/dev/null 2>&1; then
  CURRENT_GID="$(getent group "${APP_GROUP}" | awk -F: '{print $3}')"
  if [ "${CURRENT_GID}" != "${PGID}" ]; then
    groupmod -o -g "${PGID}" "${APP_GROUP}" || log "WARN: groupmod to ${PGID} failed; continuing"
  fi
fi
CURRENT_UID="$(id -u "${APP_USER}")"
if [ "${CURRENT_UID}" != "${PUID}" ]; then
  usermod -o -u "${PUID}" "${APP_USER}" || log "WARN: usermod to ${PUID} failed; continuing"
fi

# Create & fix perms; only chown when needed (cheaper)
mkdir -p "${DATA_DIR}"
if [ "$(stat -c '%u:%g' "${DATA_DIR}")" != "${PUID}:${PGID}" ]; then
  log "chown -R ${PUID}:${PGID} ${DATA_DIR}"
  chown -R "${PUID}:${PGID}" "${DATA_DIR}" || log "WARN: chown DATA_DIR failed; continuing"
fi
chmod u+rwx,g+rx "${DATA_DIR}" || true

# Ensure storage/ exists and is writable by PUID
mkdir -p "${STORAGE_DIR}" || true
if [ "$(stat -c '%u:%g' "${STORAGE_DIR}")" != "${PUID}:${PGID}" ]; then
  log "chown -R ${PUID}:${PGID} ${STORAGE_DIR}"
  chown -R "${PUID}:${PGID}" "${STORAGE_DIR}" || log "WARN: chown STORAGE_DIR failed; continuing"
fi
chmod -R u+rwX "${STORAGE_DIR}" || true

# Debug dump
log "whoami=$(whoami) euid=$(id -u) egid=$(id -g)"
log "ls -ldn ${DATA_DIR} ${STORAGE_DIR}"
ls -ldn "${DATA_DIR}" "${STORAGE_DIR}" || true
log "touch probe in storage"
if sudo -u "#${PUID}" -g "#${PGID}" touch "${STORAGE_DIR}/.probe" 2>/dev/null; then
  log "probe OK"
else
  log "ERROR: cannot write to ${STORAGE_DIR} as ${PUID}:${PGID}"
fi

# Default command: run rnsd with -c DATA_DIR
if [ "$#" -eq 0 ]; then
  set -- rnsd -vv -c "${DATA_DIR}"
fi

# Drop privileges and exec
exec gosu "${PUID}:${PGID}" "$@"
