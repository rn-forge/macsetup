#!/bin/zsh
# shellcheck shell=bash
# @file check.sh
# @brief `rnfmac profile check` — read-only profile drift report.
# @description
#   Read-only report: does the installed profile.zsh + rc-file patches match what
#   profile sync would render? Exit 0 healthy, 1 drift/problems found.
# Version: 1.0
# Author: Rohit Narayanan

set -eo pipefail

RNF_HOME="${HOME}/.rn-forge"
source "${RNF_HOME}/shkit/current/shkit.sh"

SELF_PATH="$(readlink -f "$0")"
source "$(dirname "${SELF_PATH}")/lib.sh"

PROBLEMS=0

# =============================================================================
# Helper functions
# =============================================================================

# @description Log a warning and mark the run as having found a problem.
# @arg $1 string The warning message.
# @set PROBLEMS Set to 1.
function report_problem() {
  log_warning "$1"
  PROBLEMS=1
}

# =============================================================================
# Main functions — one check per concern, run in order by execute()
# =============================================================================

# @description Check that a profile exists for the current host.
# @noargs
# @exitcode 1 No profile for this host (reported via `report_problem`).
function check_host_profile() {
  local host_profile="${PRODUCT_HOME}/current/profiles/${HOST_NAME}/profile.zsh"
  if [ ! -f "${host_profile}" ]; then
    report_problem "no profile for host '${HOST_NAME}' — create src/profiles/${HOST_NAME}/ first"
    return 1
  fi
}

# @description Check the installed `profile.zsh` matches a freshly-rendered copy.
# @noargs
function check_rendered_profile() {
  local tmp_profile
  tmp_profile="$(mktemp)"
  render_profile_content >"${tmp_profile}"

  if [ ! -f "${PRODUCT_HOME}/profile.zsh" ]; then
    report_problem "no rendered profile at ${PRODUCT_HOME}/profile.zsh — run 'rnfmac profile sync'"
  elif ! diff -q "${tmp_profile}" "${PRODUCT_HOME}/profile.zsh" >/dev/null 2>&1; then
    report_problem "rendered profile.zsh is stale — run 'rnfmac profile sync'"
  else
    log_success "rendered profile.zsh is up to date"
  fi
  rm -f "${tmp_profile}"
}

# @description Check `.zprofile` and `.zshrc` both carry the macsetup marker + source line.
# @noargs
function check_rc_files() {
  if grep -qF "${MACSETUP_MARKER}" "${HOME}/.zprofile" 2>/dev/null && grep -qF "${MACSETUP_SOURCE_LINE}" "${HOME}/.zprofile" 2>/dev/null; then
    log_success ".zprofile is patched"
  else
    report_problem ".zprofile is missing the macsetup marker/profile lines — run 'rnfmac profile sync'"
  fi

  if grep -qF "${MACSETUP_MARKER}" "${HOME}/.zshrc" 2>/dev/null && grep -qF "${MACSETUP_SOURCE_LINE}" "${HOME}/.zshrc" 2>/dev/null; then
    log_success ".zshrc is patched"
  else
    report_problem ".zshrc is missing the macsetup marker/profile lines — run 'rnfmac profile sync'"
  fi
}

# @description Run `rnfmac profile check`: host-profile existence, then (if that
#   passed) rendered-profile freshness and rc-file patch status.
# @noargs
# @set PROBLEMS Left at 1 if any check reported a problem.
function execute() {
  if check_host_profile; then
    check_rendered_profile
    check_rc_files
  fi
}

${__SOURCED__:+return} # shellspec Include guard

execute
if [ "${PROBLEMS}" -eq 0 ]; then
  log_success "profile check passed"
fi
exit "${PROBLEMS}"
