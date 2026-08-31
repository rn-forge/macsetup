#!/bin/zsh
# shellcheck shell=bash
# @file reset.sh
# @brief `rnfmac config reset` — discard local config changes.
# @description
#   Hard-resets the macsetup-config checkout to origin/main, discarding any
#   uncommitted local changes (tracked and untracked). Refuses to run without
#   `--force` so it never destroys unpublished work by accident; without the
#   flag it reports what would be discarded and exits non-zero.
# Version: 1.0
# Author: Rohit Narayanan

set -eo pipefail

RNF_HOME="${HOME}/.rn-forge"
source "${RNF_HOME}/shkit/current/shkit.sh"

SELF_PATH="$(readlink -f "$0")"
source "$(dirname "${SELF_PATH}")/lib.sh"

FORCE_FLAG=0

# @description Parse `--force`.
# @arg $@ string Command arguments.
# @set FORCE_FLAG Set to 1 if `--force` was passed.
# @exitcode 1 An unrecognized argument was passed.
function parse_args() {
  local arg="${1:-}"
  if [[ $# -eq 0 ]]; then
    return 0
  fi
  if [[ $# -eq 1 ]] && [[ "${arg}" == "--force" ]]; then
    FORCE_FLAG=1
    return 0
  fi
  echo "usage: rnfmac config reset [--force]" >&2
  return 1
}

# @description Hard-reset the config checkout to origin/main and remove
#   untracked files, discarding all local changes.
# @noargs
# @exitcode 0 The checkout is clean and matches origin/main.
# @exitcode 1 Local changes exist and `--force` was not passed.
function execute() {
  require_config_checkout
  git -C "${CONFIG_HOME}" fetch --quiet origin "${CONFIG_BRANCH}"

  if [[ -z "$(git -C "${CONFIG_HOME}" status --porcelain)" ]]; then
    git -C "${CONFIG_HOME}" reset --quiet --hard "origin/${CONFIG_BRANCH}"
    log_success "macsetup config is already clean ($(git -C "${CONFIG_HOME}" rev-parse --short HEAD))"
    return 0
  fi

  if [[ "${FORCE_FLAG}" -ne 1 ]]; then
    log_error "macsetup config has local changes that would be discarded — rerun with --force"
    git -C "${CONFIG_HOME}" --no-pager status --short
    return 1
  fi

  git -C "${CONFIG_HOME}" reset --quiet --hard "origin/${CONFIG_BRANCH}"
  git -C "${CONFIG_HOME}" clean --quiet -fd
  log_success "macsetup config reset to origin/${CONFIG_BRANCH} ($(git -C "${CONFIG_HOME}" rev-parse --short HEAD))"
}

${__SOURCED__:+return} # shellspec Include guard

parse_args "$@"
execute
