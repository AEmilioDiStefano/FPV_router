#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HELPER_DIR="${SCRIPT_DIR}/pi"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/install_pi_helpers.sh [--user PI_USER] [--host PI_HOST_OR_IP]

This script runs on your laptop. It copies the tracked FPV router helper
scripts from this repo onto the Raspberry Pi and installs them into
/usr/local/sbin with sudo.
EOF
}

PI_USER_ARG=""
PI_HOST_ARG=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --user)
      PI_USER_ARG="${2:-}"
      shift 2
      ;;
    --host)
      PI_HOST_ARG="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ ! -d "${HELPER_DIR}" ]; then
  echo "ERROR: Helper directory not found at ${HELPER_DIR}." >&2
  exit 1
fi

PI_USER="${PI_USER_ARG:-${PI_USER:-}}"
PI_HOST="${PI_HOST_ARG:-${PI_SSH_TARGET:-${PI_IP:-${PI_HOST:-}}}}"

if [ -z "${PI_USER}" ]; then
  read -rp "Enter the Linux username for the Pi: " PI_USER
fi

if [ -z "${PI_HOST}" ]; then
  read -rp "Enter the Pi SSH hostname or IP: " PI_HOST
fi

if [ -z "${PI_USER}" ] || [ -z "${PI_HOST}" ]; then
  echo "ERROR: Both the Pi username and the Pi SSH host are required." >&2
  exit 1
fi

TARGET="${PI_USER}@${PI_HOST}"
REMOTE_TMP="/tmp/fpv-router-helper-install.$$"

echo "Installing FPV router helper scripts to ${TARGET}..."

ssh "${TARGET}" "mkdir -p '${REMOTE_TMP}'"
scp "${HELPER_DIR}/"* "${TARGET}:${REMOTE_TMP}/"
ssh -t "${TARGET}" "\
  sudo install -d -m 755 /usr/local/sbin && \
  for file in ${REMOTE_TMP}/*; do \
    sudo install -m 755 \"\$file\" /usr/local/sbin/; \
  done && \
  rm -rf '${REMOTE_TMP}'"

echo
echo "Installed helper scripts on ${TARGET}:"
echo "  - /usr/local/sbin/fpv-router-reset-for-retry"
echo "  - /usr/local/sbin/fpv-router-verify-reset"
echo "  - /usr/local/sbin/fpv-router-detect-ifaces"
echo "  - /usr/local/sbin/set-initial-uplink-wifi"
echo "  - /usr/local/sbin/render-fpv-router-config"
echo "  - /usr/local/sbin/manage-uplink-wifis"
