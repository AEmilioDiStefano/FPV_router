#!/usr/bin/env bash
# shellcheck shell=bash

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  exec "${SCRIPT_DIR}/fpv_router_bootstrap.sh" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_SCRIPT="${SCRIPT_DIR}/fpv_router_bootstrap.sh"

if [[ ! -x "$BOOTSTRAP_SCRIPT" ]]; then
  echo "[fpv_router_bootstrap_env] ERROR: Missing executable bootstrap helper: ${BOOTSTRAP_SCRIPT}" >&2
  return 1
fi

BOOTSTRAP_EXPORTS="$("$BOOTSTRAP_SCRIPT" "$@" --emit-shell)" || return $?
eval "$BOOTSTRAP_EXPORTS"
unset BOOTSTRAP_EXPORTS
