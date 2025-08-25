#!/usr/bin/env bash
set -Eeuo pipefail

APP_USER="rns"
APP_GROUP="rns"
PUID="${PUID:-10001}"
PGID="${PGID:-10001}"
DATA_DIR="${DATA_DIR:-/home/${APP_USER}/.reticulum}"

# Ensure dialout membership for serial adapters
if getent group dialout >/dev/null 2>&1; then
  usermod -aG dialout "${APP_USER}" || true
fi

# Try to remap gid if requested
CURRENT_GID="$(getent group "${APP_GROUP}" | awk -F: '{print $3}')"
if [ "${CURRENT_GID}" != "${PGID}" ]; then
  if groupmod -o -g "${PGID}" "${APP_GROUP}" 2>/dev/null; then
    :
  else
    echo "WARN: Could not set GID to ${PGID} (likely in use). Keeping ${CURRENT_GID}."
    PGID="${CURRENT_GID}"
  fi
fi

# Try to remap uid if requested
CURRENT_UID="$(id -u "${APP_USER}")"
if [ "${CURRENT_UID}" != "${PUID}" ]; then
  if usermod -o -u "${PUID}" "${APP_USER}" 2>/dev/null; then
    :
  else
    echo "WARN: Could not set UID to ${PUID} (likely in use). Keeping ${CURRENT_UID}."
    PUID="${CURRENT_UID}"
  fi
fi

# Prepare data dir & fix ownership
mkdir -p "${DATA_DIR}"
# Only chown when needed (cheap stat, expensive chown avoided if already correct)
if [ "$(stat -c '%u:%g' "${DATA_DIR}")" != "${PUID}:${PGID}" ]; then
  chown -R "${PUID}:${PGID}" "${DATA_DIR}"
fi

# Default command (if none provided): rnsd -c <DATA_DIR>
if [ "$#" -eq 0 ]; then
  set -- rnsd -vv -c "${DATA_DIR}"
fi

# Drop privileges and exec
exec gosu "${PUID}:${PGID}" "$@"
