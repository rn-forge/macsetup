#!/bin/zsh
# shellcheck shell=bash
# @file diff.sh
# @brief `rnfmac brew diff` — read-only Homebrew drift report.
# @description
#   Report drift between installed Homebrew packages and the host Brewfile.
#   --write updates the Brewfile in the persistent macsetup-config checkout.
#   Exit 0 no drift, 2 drift, or 1 structural error.
# Version: 1.0
# Author: Rohit Narayanan

set -eo pipefail

RNF_HOME="${HOME}/.rn-forge"
source "${RNF_HOME}/shkit/current/shkit.sh"

PRODUCT_HOME="${RNF_HOME}/macsetup"
HOST_NAME="$(hostname | tr '[:upper:]' '[:lower:]' | cut -d. -f1)"
BREWFILE="${PRODUCT_HOME}/config/hosts/${HOST_NAME}/Brewfile"
SELF_PATH="$(readlink -f "$0")"
source "$(dirname "$(dirname "${SELF_PATH}")")/lib/report.sh"
export REPORT_GROUP="brew"
WRITE_FLAG=0

# =============================================================================
# Helper functions
# =============================================================================

# @description Print `rnfmac brew diff` usage.
# @noargs
# @stdout The usage text.
function usage() {
  echo "usage: rnfmac brew diff [--write] [--all] [--json]"
}

# @description Parse CLI args, setting report flags and `WRITE_FLAG`.
# @arg $@ string Flags: `--write`, `--all`, `--json`, `-h`/`--help`/`help`.
# @set WRITE_FLAG Set to 1 if `--write` was passed.
# @set RNFMAC_REPORT_ALL Set to 1 when `--all` is passed.
# @set RNFMAC_REPORT_FORMAT Set to `json` when `--json` is passed.
# @exitcode 0 Parsed successfully, or help was requested (also exits the script).
# @exitcode 1 Unrecognized argument.
function parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --write) WRITE_FLAG=1 ;;
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
# Main functions
# =============================================================================

# @description Report drift between installed Homebrew packages and `BREWFILE`.
# @noargs
function report_diff() {
  local missing=0 extra=0

  if [[ "${RNFMAC_REPORT_FORMAT:-human}" = "human" ]]; then
    log_verbose "Checking brew bundle drift against ${BREWFILE} ..."
    if ! brew bundle check --file="${BREWFILE}" --verbose; then
      missing=1
    fi
  elif ! brew bundle check --file="${BREWFILE}" --verbose >/dev/null; then
    missing=1
  fi

  local extras
  extras="$(brew bundle cleanup --file="${BREWFILE}" 2>/dev/null | sed '/^Would `brew cleanup`:$/,$d')" || true
  if [[ -n "${extras}" ]]; then
    extra=1
    report_add "drift" "packages" "brewfile-extra" "installed but not in Brewfile:
${extras}"
  fi

  if [[ "${missing}" -eq 0 ]] && [[ "${extra}" -eq 0 ]]; then
    report_add "ok" "packages" "brewfile" "no drift — installed packages match the Brewfile"
    return 0
  fi

  if [[ "${missing}" -eq 1 ]]; then
    report_add "drift" "packages" "brewfile-missing" "packages from the Brewfile are missing — run 'rnfmac brew sync'"
  fi
  return 0
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
  local lib_dir
  lib_dir="$(dirname "$(dirname "${SELF_PATH}")")/lib"
  LEAVES="${leaves}" awk -f "${lib_dir}/dedupe-brewfile.awk" "${target}" >"${target}.tmp" && mv "${target}.tmp" "${target}"

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
if [[ "${WRITE_FLAG}" -eq 1 ]]; then
  exit 0
fi
report_render
exit "$(report_exit_code)"
