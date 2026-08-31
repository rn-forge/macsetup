# shellcheck shell=bash
# minimal test double for the installed shkit bundle (shkit.sh) —
# pre-seeded into the sandbox by setup_sandbox so commands/profile.zsh can source it
# locally, matching the real "install.sh installs it, everything else just sources it" contract.
if [[ -n "${ZSH_VERSION:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname -- "${ZSH_ARGZERO:-$0}")" && pwd)"
else
  SCRIPT_DIR="$(cd "$(dirname -- "$0")" && pwd)"
fi
export RNF_LOG_LEVEL_DEBUG=10
: "${RNF_LOG_LEVEL:=20}"
_double_log() {
  local level="$1"
  shift
  [[ "${level}" -lt "${RNF_LOG_LEVEL}" ]] && return 0
  echo "$@"
  return 0
}
log_info() {
  _double_log 20 "[info] $*"
  return 0
}
log_success() {
  _double_log 35 "[success] $*"
  return 0
}
log_warning() {
  _double_log 30 "[warning] $*"
  return 0
}
log_notice() {
  _double_log 25 "[notice] $*"
  return 0
}
log_verbose() {
  _double_log 15 "[verbose] $*"
  return 0
}
log_error() {
  _double_log 40 "[error] $*" >&2
  return 0
}
print_vars() {
  :
  return 0
}
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
