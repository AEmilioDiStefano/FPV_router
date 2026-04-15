#!/usr/bin/env bash
# shellcheck shell=bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  fpv_router_bootstrap.sh [--repo-root <path>] [--search-root <path>] [--interactive|--non-interactive] [--emit-shell]

Behavior:
  - Detects the FPV_router repo root from anywhere.
  - Optionally confirms the detected repo interactively.
  - With --emit-shell, prints export commands to stdout for eval/source usage.

Examples:
  eval "$(/path/to/fpv_router_bootstrap.sh --interactive --emit-shell)"
  /path/to/fpv_router_bootstrap.sh --repo-root /home/user/FPV_router --non-interactive
USAGE
}

emit_shell="0"
interactive_mode="auto"
repo_override=""
search_root="${FPV_ROUTER_SEARCH_ROOT:-$HOME}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      shift
      repo_override="${1:-}"
      ;;
    --search-root)
      shift
      search_root="${1:-}"
      ;;
    --interactive)
      interactive_mode="yes"
      ;;
    --non-interactive)
      interactive_mode="no"
      ;;
    --emit-shell)
      emit_shell="1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[fpv_router_bootstrap] Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

expand_path() {
  local raw="${1:-}"
  if [[ -z "$raw" ]]; then
    printf '%s' ""
    return 0
  fi
  if [[ "$raw" == "~/"* ]]; then
    raw="${HOME}/${raw#~/}"
  elif [[ "$raw" == '$HOME/'* ]]; then
    raw="${HOME}/${raw#\$HOME/}"
  fi
  printf '%s' "${raw%/}"
}

is_repo_root() {
  local candidate
  candidate="$(expand_path "${1:-}")"
  [[ -n "$candidate" ]] || return 1
  [[ -d "${candidate}/.git" ]] || return 1
  [[ -f "${candidate}/README.md" ]] || return 1
  [[ -f "${candidate}/DOCS/git_workflow.md" ]] || return 1
  [[ -f "${candidate}/scripts/fpv_router_bootstrap_env.sh" ]] || return 1
}

resolve_repo_root() {
  local candidate
  candidate="$(expand_path "${1:-}")"
  [[ -n "$candidate" ]] || return 1

  if is_repo_root "$candidate"; then
    printf '%s' "$candidate"
    return 0
  fi

  if is_repo_root "${candidate}/FPV_router"; then
    printf '%s' "${candidate}/FPV_router"
    return 0
  fi

  return 1
}

resolve_current_shell_root() {
  local candidate=""
  local resolved=""
  for candidate in "${FPV_ROUTER_ROOT:-}" "${FPR:-}"; do
    if resolved="$(resolve_repo_root "$candidate" || true)"; [[ -n "$resolved" ]]; then
      printf '%s' "$resolved"
      return 0
    fi
  done
  return 1
}

resolve_from_pwd() {
  local cur="${PWD}"
  while [[ -n "$cur" && "$cur" != "/" ]]; do
    if is_repo_root "$cur"; then
      printf '%s' "$cur"
      return 0
    fi
    cur="$(dirname "$cur")"
  done
  return 1
}

resolve_from_script_dir() {
  local repo_root
  repo_root="$(cd "${SCRIPT_DIR}/.." && pwd)"
  if is_repo_root "$repo_root"; then
    printf '%s' "$repo_root"
    return 0
  fi
  return 1
}

resolve_from_search() {
  local candidate=""
  local root=""
  mapfile -t candidates < <(find "$search_root" -maxdepth 8 -type f -path "*/scripts/fpv_router_bootstrap_env.sh" 2>/dev/null | sort)
  if (( ${#candidates[@]} == 0 )); then
    return 1
  fi
  if (( ${#candidates[@]} > 1 )); then
    echo "[WARN] Multiple FPV_router bootstrap helpers found; using: ${candidates[0]}" >&2
    echo "       Set FPV_ROUTER_ROOT=/path/to/FPV_router to force selection." >&2
  fi
  candidate="${candidates[0]}"
  root="$(cd "$(dirname "$candidate")/.." && pwd)"
  if is_repo_root "$root"; then
    printf '%s' "$root"
    return 0
  fi
  return 1
}

repo_root=""
if [[ -n "$repo_override" ]]; then
  repo_root="$(resolve_repo_root "$repo_override" || true)"
elif current_root="$(resolve_current_shell_root || true)"; [[ -n "$current_root" ]]; then
  repo_root="$current_root"
elif pwd_root="$(resolve_from_pwd || true)"; [[ -n "$pwd_root" ]]; then
  repo_root="$pwd_root"
elif script_root="$(resolve_from_script_dir || true)"; [[ -n "$script_root" ]]; then
  repo_root="$script_root"
elif search_found="$(resolve_from_search || true)"; [[ -n "$search_found" ]]; then
  repo_root="$search_found"
fi

if [[ -z "$repo_root" ]]; then
  echo "[FAIL] Could not locate FPV_router under ${search_root}." >&2
  exit 1
fi

current_shell_root=""
if current_root="$(resolve_current_shell_root || true)"; [[ -n "$current_root" ]]; then
  current_shell_root="$current_root"
fi

skip_interactive_confirm="0"
if [[ -n "$current_shell_root" && "$current_shell_root" == "$repo_root" && -z "$repo_override" ]]; then
  skip_interactive_confirm="1"
fi

if [[ "$skip_interactive_confirm" != "1" ]] && { [[ "$interactive_mode" == "yes" ]] || { [[ "$interactive_mode" == "auto" ]] && [[ -t 0 ]]; }; }; then
  detected_name="$(basename "$repo_root")"
  while true; do
    printf '\nA repo called [%s] has been detected as the FPV_router root. Is this correct?\n' "$detected_name" >&2
    printf '(Y/n): ' >&2
    read -r confirm
    case "${confirm:-Y}" in
      y|Y)
        break
        ;;
      n|N)
        while true; do
          printf 'Enter FPV_router repo path: ' >&2
          read -r repo_input
          if [[ -z "${repo_input// }" ]]; then
            echo "[fpv_router_bootstrap] Repo path cannot be empty." >&2
            continue
          fi
          if resolved_repo="$(resolve_repo_root "$repo_input" || true)"; [[ -n "$resolved_repo" ]]; then
            repo_root="$resolved_repo"
            detected_name="$(basename "$repo_root")"
            break
          fi
          echo "[fpv_router_bootstrap] Path does not look like an FPV_router repo: ${repo_input}" >&2
        done
        break
        ;;
      *)
        echo "Please enter Y, N, or press ENTER." >&2
        ;;
    esac
  done
fi

repo_name="$(basename "$repo_root")"

if [[ "$emit_shell" == "1" ]]; then
  printf 'export FPV_ROUTER_ROOT=%q\n' "$repo_root"
  printf 'export FPR=%q\n' "$repo_root"
  printf 'export FPV_ROUTER_REPO_NAME=%q\n' "$repo_name"
  printf 'echo %q\n' "FPV_router root has been set to: ${repo_root}"
else
  echo "[fpv_router_bootstrap] FPV_ROUTER_ROOT=${repo_root}"
  echo "[fpv_router_bootstrap] FPR=${repo_root}"
fi
