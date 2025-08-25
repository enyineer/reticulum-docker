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

# Best-effort: ensure dialout (for /dev/ttyUSB*)
if getent group dialout >/dev/null 2>&1; then
  usermod -aG dialout "${APP_USER}" || true
fi

# Remap gid/uid if requested (best-effort)
if getent group "${APP_GROUP}" >/dev/null 2>&1; then
  CURRENT_GID="$(getent group "${APP_GROUP}" | awk -F: '{print $3}')"
  [ "${CURRENT_GID}" = "${PGID}" ] || groupmod -o -g "${PGID}" "${APP_GROUP}" || log "WARN: groupmod ${PGID} failed"
fi
CURRENT_UID="$(id -u "${APP_USER}")"
[ "${CURRENT_UID}" = "${PUID}" ] || usermod -o -u "${PUID}" "${APP_USER}" || log "WARN: usermod ${PUID} failed"

# Ensure dirs & perms
mkdir -p "${STORAGE_DIR}"
# Only chown when needed
if [ "$(stat -c '%u:%g' "${DATA_DIR}")" != "${PUID}:${PGID}" ]; then
  log "chown -R ${PUID}:${PGID} ${DATA_DIR}"
  chown -R "${PUID}:${PGID}" "${DATA_DIR}" || log "WARN: chown DATA_DIR failed"
fi
chmod u+rwx,g+rx "${DATA_DIR}" || true
chmod -R u+rwX "${STORAGE_DIR}" || true

# Debug + real write probe using gosu
log "whoami=$(whoami) euid=$(id -u) egid=$(id -g)"
log "ls -ldn ${DATA_DIR} ${STORAGE_DIR}"
ls -ldn "${DATA_DIR}" "${STORAGE_DIR}" || true
log "touch probe in storage as ${PUID}:${PGID}"
if gosu "${PUID}:${PGID}" bash -lc "touch '${STORAGE_DIR}/.probe'"; then
  log "probe OK"
else
  log "ERROR: cannot write to ${STORAGE_DIR} as ${PUID}:${PGID}"
fi

# Default command: rnsd -c DATA_DIR
if [ "$#" -eq 0 ]; then
  set -- rnsd --config "${DATA_DIR}"
fi

exec gosu "${PUID}:${PGID}" "$@"
