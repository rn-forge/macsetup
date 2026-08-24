#!/bin/zsh
# shellcheck shell=bash
# @file diff.sh
# @brief `rnfmac brew diff` — read-only Homebrew drift report.
# @description
#   Report drift between installed Homebrew packages and the host Brewfile.
#   --write updates the Brewfile in the persistent macsetup-config checkout.
#   Exit 0 no drift, 1 drift/problems found.
# Version: 1.0
# Author: Rohit Narayanan

set -eo pipefail

RNF_HOME="${HOME}/.rn-forge"
source "${RNF_HOME}/shkit/current/shkit.sh"

PRODUCT_HOME="${RNF_HOME}/macsetup"
HOST_NAME="$(hostname | tr '[:upper:]' '[:lower:]' | cut -d. -f1)"
BREWFILE="${PRODUCT_HOME}/config/hosts/${HOST_NAME}/Brewfile"
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

# =============================================================================
# Main functions
# =============================================================================

# @description Report drift between installed Homebrew packages and `BREWFILE`.
# @noargs
# @exitcode 0 No drift.
# @exitcode 1 Drift detected.
function report_diff() {
  log_verbose "Checking brew bundle drift against ${BREWFILE} ..."
  local missing=0 extra=0

  if ! brew bundle check --file="${BREWFILE}" --verbose; then
    missing=1
  fi

  local extras
  extras="$(brew bundle cleanup --file="${BREWFILE}" 2>/dev/null | sed '/^Would `brew cleanup`:$/,$d')" || true
  if [[ -n "${extras}" ]]; then
    extra=1
    log_warning "installed but not in Brewfile:"
    echo "${extras}"
  fi

  if [[ "${missing}" -eq 0 ]] && [[ "${extra}" -eq 0 ]]; then
    log_success "no drift — installed packages match the Brewfile"
    return 0
  fi

  log_warning "drift detected between installed packages and the Brewfile"
  return 1
}

# @description Dump installed Homebrew package state to the host's Brewfile.
#   Writes into the persistent macsetup-config checkout.
# @noargs
# @exitcode 1 The macsetup-config checkout is missing.
function write_brewfile() {
  local config_home="${PRODUCT_HOME}/config"
  if ! git -C "${config_home}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log_warning "macsetup config checkout is missing at ${config_home}"
    exit 1
  fi

  local target="${config_home}/hosts/${HOST_NAME}/Brewfile"
  mkdir -p "$(dirname "${target}")"
  log_verbose "Writing installed package state to ${target} ..."
  brew bundle dump --file="${target}" --force --no-vscode --no-uv --no-npm

  log_verbose "Dropping dependency-only formulae (keeping only explicitly requested ones) ..."
  local leaves
  leaves="$(brew leaves --installed-on-request)"
  LEAVES="${leaves}" awk '
    BEGIN {
      n = split(ENVIRON["LEAVES"], arr, "\n"); for (i = 1; i <= n; i++) requested[arr[i]] = 1
      header["tap"] = "## taps"; header["brew"] = "## formulae"; header["cask"] = "## casks"
    }
    /^#/ { pending = $0; next }
    /^brew "/ {
      name = $0
      sub(/^brew "/, "", name)
      sub(/".*/, "", name)
      if (!(name in requested)) { pending = ""; next }
    }
    {
      if ($1 != last_type) {
        if (last_type != "") print ""
        if ($1 in header) print header[$1]
        last_type = $1
      }
      if (pending != "") print pending
      pending = ""
      print
    }
  ' "${target}" >"${target}.tmp" && mv "${target}.tmp" "${target}"

  log_success "Brewfile updated at ${target}"
}

# @description Run `rnfmac brew diff`: write the Brewfile if `--write` was passed,
#   otherwise report drift.
# @noargs
function execute() {
  if [[ "${WRITE_FLAG}" -eq 1 ]]; then
    write_brewfile
    return 0
  fi

  report_diff
}

${__SOURCED__:+return} # shellspec Include guard

parse_args "$@"
execute
