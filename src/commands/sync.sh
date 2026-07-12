#!/bin/zsh
# shellcheck shell=bash
# @file sync.sh
# @brief `rnfmac sync` — the everyday sync command.
# @description
#   Composer: profile sync -> brew sync -> system sync, in that order (profile first
#   so a new dist's Brewfile/pins are what get applied).
# Version: 1.0
# Author: Rohit Narayanan

set -eo pipefail

SELF_PATH="$(readlink -f "$0")"
COMMANDS_PATH="$(dirname "${SELF_PATH}")"
RNF_HOME="${HOME}/.rn-forge"
PRODUCT_HOME="${RNF_HOME}/macsetup"

# @description Run `rnfmac sync`: profile sync, then (unless
#   `RNFMAC_SYNC_PROFILES_ONLY` is set) brew sync and system sync.
# @noargs
# @exitcode 0 All steps succeeded.
# @exitcode 1 A step failed (propagated via `set -e`).
function execute() {
  "${COMMANDS_PATH}/profile/sync.sh"
  source "${PRODUCT_HOME}/profile.zsh"

  if [ -n "${RNFMAC_SYNC_PROFILES_ONLY:-}" ]; then
    log_notice "RNFMAC_SYNC_PROFILES_ONLY set — skipping brew and system sync"
    return
  fi

  "${COMMANDS_PATH}/brew/sync.sh"
  "${COMMANDS_PATH}/system/sync.sh"
}

${__SOURCED__:+return} # shellspec Include guard

execute
