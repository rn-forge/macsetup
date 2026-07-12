#!/bin/bash
# shellcheck shell=bash
# minimal test double for shkit's install.sh — served by the curl stub for
# `curl -fsSL .../shkit/releases/latest/download/install.sh | bash` (executed,
# not sourced, so this only needs to write the versioned layout to disk).
_rnf_home="${RNF_HOME:-${HOME}/.rn-forge}"
mkdir -p "${_rnf_home}/shkit/v0.1.2" "${_rnf_home}/bin"
cat >"${_rnf_home}/shkit/v0.1.2/shkit.sh" <<'RNF_SHKIT_TEST_DOUBLE'
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export RNF_LOG_LEVEL_DEBUG="DEBUG"
log_info() { echo "[info] $*"; }
log_success() { echo "[success] $*"; }
log_warning() { echo "[warning] $*"; }
log_notice() { echo "[notice] $*"; }
log_verbose() { echo "[verbose] $*"; }
log_error() { echo "[error] $*" >&2; }
print_vars() { :; }
confirm() {
  local msg="$1" reply
  if [ "${RNF_SKIP_CONFIRMATIONS:-0}" = "1" ]; then
    log_info "auto-confirmed: ${msg}"
    return 0
  fi
  printf '%s (y/n): ' "$msg"
  read -r reply
  case "$reply" in
  [Yy] | [Yy][Ee][Ss]) return 0 ;;
  *)
    log_error "Cancelled."
    exit 1
    ;;
  esac
}
RNF_SHKIT_TEST_DOUBLE
echo "0.1.2" >"${_rnf_home}/shkit/v0.1.2/VERSION"
ln -sfn v0.1.2 "${_rnf_home}/shkit/current"
