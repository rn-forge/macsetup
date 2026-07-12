#!/bin/zsh
# shellcheck shell=bash
# @file diff.sh
# @brief `rnfmac brew diff` — read-only Homebrew drift report.
# @description
#   Report drift between installed Homebrew packages and the host Brewfile.
#   --write updates the Brewfile from installed state — requires a git checkout.
#   Exit 0 no drift, 1 drift/problems found.
# Version: 1.0
# Author: Rohit Narayanan

set -eo pipefail

RNF_HOME="${HOME}/.rn-forge"
source "${RNF_HOME}/shkit/current/shkit.sh"

SELF_PATH="$(readlink -f "$0")"
SRC_ROOT="$(dirname "$(dirname "$(dirname "${SELF_PATH}")")")" # unpacked dist root, or src/ in a git checkout

PRODUCT_HOME="${RNF_HOME}/macsetup"
HOST_NAME="$(hostname | tr '[:upper:]' '[:lower:]' | cut -d. -f1)"
BREWFILE="${PRODUCT_HOME}/current/profiles/${HOST_NAME}/Brewfile"
WRITE_FLAG=0

# =============================================================================
# Helper functions
# =============================================================================

# @description Print `rnfmac brew diff` usage.
# @noargs
# @stdout The usage text.
function usage() {
  echo "usage: rnfmac brew diff [--write]"
}

# @description Parse CLI args, setting `WRITE_FLAG` and handling `-h`/`--help`.
# @arg $1 string Optional flag: `--write`, `-h`/`--help`/`help`, or empty.
# @set WRITE_FLAG Set to 1 if `--write` was passed.
# @exitcode 0 Parsed successfully, or help was requested (also exits the script).
# @exitcode 1 Unrecognized argument.
function parse_args() {
  case "${1:-}" in
  --write) WRITE_FLAG=1 ;;
  "") ;;
  -h | --help | help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 1
    ;;
  esac
}

# @description Print the git checkout root containing `SRC_ROOT`, if any.
# @noargs
# @stdout The checkout's top-level path, or nothing if `SRC_ROOT` isn't in a git checkout.
function checkout_root() {
  if git -C "${SRC_ROOT}" rev-parse --show-toplevel >/dev/null 2>&1; then
    git -C "${SRC_ROOT}" rev-parse --show-toplevel
  fi
}

# =============================================================================
# Main functions
# =============================================================================

# @description Report drift between installed Homebrew packages and `BREWFILE`.
# @noargs
# @exitcode 0 No drift.
# @exitcode 1 Drift detected.
function report_diff() {
  log_verbose "Checking brew bundle drift against ${BREWFILE} ..."
  if brew bundle check --file="${BREWFILE}" --verbose; then
    log_success "no drift — installed packages match the Brewfile"
    return 0
  fi

  log_warning "drift detected between installed packages and the Brewfile"
  return 1
}

# @description Dump installed Homebrew package state to the host's Brewfile.
#   Requires `SRC_ROOT` to be inside a git checkout.
# @noargs
# @exitcode 1 Not run from a git checkout.
function write_brewfile() {
  local root
  root="$(checkout_root)"
  if [ -z "${root}" ]; then
    log_warning "'--write' requires a git checkout — run via 'src/rnfmac.sh brew diff --write' from the macsetup checkout"
    exit 1
  fi

  local target="${root}/src/profiles/${HOST_NAME}/Brewfile"
  log_verbose "Writing installed package state to ${target} ..."
  brew bundle dump --file="${target}" --force --describe
  log_success "Brewfile updated at ${target}"
}

# @description Run `rnfmac brew diff`: write the Brewfile if `--write` was passed,
#   otherwise report drift.
# @noargs
function execute() {
  if [ "${WRITE_FLAG}" -eq 1 ]; then
    write_brewfile
    return 0
  fi

  report_diff
}

${__SOURCED__:+return} # shellspec Include guard

parse_args "$@"
execute
