#!/bin/zsh
# shellcheck shell=bash
# @file sync.sh
# @brief `rnfmac sync` — the everyday sync command.
# @description
#   Composer: config pull -> profile sync -> brew sync -> system sync, in that order.
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
  local config_was_missing=0
  [[ ! -e "${PRODUCT_HOME}/config" ]] && config_was_missing=1
  "${COMMANDS_PATH}/config/pull.sh"

  ## Compatibility with upgrade.sh versions that predate external config: those
  ## exec the newly downloaded sync.sh automatically. Bootstrap the checkout, but
  ## preserve the new contract that an upgrade never applies configuration.
  if [[ "${config_was_missing}" -eq 1 ]]; then
    source "${RNF_HOME}/shkit/current/shkit.sh"
    log_notice "configuration checkout created but not applied — run 'rnfmac sync' to apply it"
    return
  fi

  "${COMMANDS_PATH}/profile/sync.sh"
  source "${PRODUCT_HOME}/profile.zsh"

  if [[ -n "${RNFMAC_SYNC_PROFILES_ONLY:-}" ]]; then
    log_notice "RNFMAC_SYNC_PROFILES_ONLY set — skipping brew and system sync"
    return
  fi

  "${COMMANDS_PATH}/brew/sync.sh"
  "${COMMANDS_PATH}/system/sync.sh"
}

${__SOURCED__:+return} # shellspec Include guard

execute
