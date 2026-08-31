#!/bin/zsh
# shellcheck shell=bash
# @file check.sh
# @brief `rnfmac profile check` — read-only profile drift report.
# @description
#   Read-only report: does the installed profile.zsh + rc-file patches match what
#   profile sync would render, using the shared structured report format.
# Version: 1.0
# Author: Rohit Narayanan

set -eo pipefail

RNF_HOME="${HOME}/.rn-forge"
source "${RNF_HOME}/shkit/current/shkit.sh"

SELF_PATH="$(readlink -f "$0")"
source "$(dirname "${SELF_PATH}")/lib.sh"
source "$(dirname "$(dirname "${SELF_PATH}")")/lib/report.sh"
export REPORT_GROUP="profile"

# =============================================================================
# Helper functions
# =============================================================================

# @description Print `rnfmac profile check` usage.
# @stdout The usage text.
function usage() {
  echo "usage: rnfmac profile check [--all] [--json]"
}

# @description Parse reporting and help flags.
# @arg $@ string Flags: `--all`, `--json`, `-h`/`--help`/`help`.
# @set RNFMAC_REPORT_ALL Set to 1 when `--all` is passed.
# @set RNFMAC_REPORT_FORMAT Set to `json` when `--json` is passed.
# @exitcode 0 Parsed successfully, or help was requested.
# @exitcode 1 An argument was unrecognized.
function parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --all) export RNFMAC_REPORT_ALL=1 ;;
    --json) export RNFMAC_REPORT_FORMAT=json ;;
    -h | --help | help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 1
      ;;
    esac
    shift
  done
}

# =============================================================================
# Main functions — one check per concern, run in order by execute()
# =============================================================================

# @description Check that a profile exists for the current host.
# @noargs
# @exitcode 1 No profile for this host.
function check_host_profile() {
  local host_profile="${CONFIG_HOME}/hosts/${HOST_NAME}/profile.zsh"
  if [[ ! -f "${host_profile}" ]]; then
    report_add "warning" "profile" "host-profile" "no profile for host '${HOST_NAME}' — create hosts/${HOST_NAME}/ in macsetup-config"
    return 1
  fi
}

# @description Check the installed `profile.zsh` matches a freshly-rendered copy.
# @noargs
function check_rendered_profile() {
  local tmp_profile
  tmp_profile="$(mktemp)"
  render_profile_content >"${tmp_profile}"

  if [[ ! -f "${PRODUCT_HOME}/profile.zsh" ]]; then
    report_add "drift" "profile" "rendered-profile" "no rendered profile at ${PRODUCT_HOME}/profile.zsh — run 'rnfmac profile sync'"
  elif ! diff -q "${tmp_profile}" "${PRODUCT_HOME}/profile.zsh" >/dev/null 2>&1; then
    report_add "drift" "profile" "rendered-profile" "rendered profile.zsh is stale — run 'rnfmac profile sync'"
  else
    report_add "ok" "profile" "rendered-profile" "rendered profile.zsh is up to date"
  fi
  rm -f "${tmp_profile}"
}

# @description Check `.zprofile` and `.zshrc` both carry the macsetup marker + source line.
# @noargs
function check_rc_files() {
  if grep -qF "${MACSETUP_MARKER}" "${HOME}/.zprofile" 2>/dev/null && grep -qF "${MACSETUP_SOURCE_LINE}" "${HOME}/.zprofile" 2>/dev/null; then
    report_add "ok" "profile" "zprofile" ".zprofile is patched"
  else
    report_add "drift" "profile" "zprofile" ".zprofile is missing the macsetup marker/profile lines — run 'rnfmac profile sync'"
  fi

  if grep -qF "${MACSETUP_MARKER}" "${HOME}/.zshrc" 2>/dev/null && grep -qF "${MACSETUP_SOURCE_LINE}" "${HOME}/.zshrc" 2>/dev/null; then
    report_add "ok" "profile" "zshrc" ".zshrc is patched"
  else
    report_add "drift" "profile" "zshrc" ".zshrc is missing the macsetup marker/profile lines — run 'rnfmac profile sync'"
  fi
}

# @description Run `rnfmac profile check`: host-profile existence, then (if that
#   passed) rendered-profile freshness and rc-file patch status.
# @noargs
function execute() {
  if check_host_profile; then
    check_rendered_profile
    check_rc_files
  fi
}

${__SOURCED__:+return} # shellspec Include guard

parse_args "$@"
execute
report_render
exit "$(report_exit_code)"
