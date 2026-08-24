# shellcheck shell=bash
# minimal test double for the installed shkit bundle (shkit.sh) —
# pre-seeded into the sandbox by setup_sandbox so commands/profile.zsh can source it
# locally, matching the real "install.sh installs it, everything else just sources it" contract.
if [[ -n "${ZSH_VERSION:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname -- "${ZSH_ARGZERO:-$0}")" && pwd)"
else
  SCRIPT_DIR="$(cd "$(dirname -- "$0")" && pwd)"
fi
export RNF_LOG_LEVEL_DEBUG="DEBUG"
log_info() { echo "[info] $*"; return 0; }
log_success() { echo "[success] $*"; return 0; }
log_warning() { echo "[warning] $*"; return 0; }
log_notice() { echo "[notice] $*"; return 0; }
log_verbose() { echo "[verbose] $*"; return 0; }
log_error() { echo "[error] $*" >&2; return 0; }
print_vars() { :; return 0; }
confirm() {
  local msg="$1" reply
  if [[ "${RNF_SKIP_CONFIRMATIONS:-0}" = "1" ]]; then
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
