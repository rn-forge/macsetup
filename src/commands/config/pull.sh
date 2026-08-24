#!/bin/zsh
# shellcheck shell=bash
# @file pull.sh
# @brief `rnfmac config pull` — fast-forward the configuration checkout.
# @description
#   Clones the persistent macsetup-config checkout when absent, otherwise
#   fast-forwards it to origin/main. Uncommitted local changes are carried across
#   the update rather than refused; it never merges, rebases, or overwrites them.
#   Refuses only a divergent checkout (local commits absent from origin).
# Version: 1.0
# Author: Rohit Narayanan

set -eo pipefail

RNF_HOME="${HOME}/.rn-forge"
source "${RNF_HOME}/shkit/current/shkit.sh"

SELF_PATH="$(readlink -f "$0")"
source "$(dirname "${SELF_PATH}")/lib.sh"

# @description Ensure the checkout exists, then fast-forward it onto `origin/main`,
#   preserving any uncommitted local changes.
# @noargs
# @exitcode 0 Configuration is current.
# @exitcode 1 Checkout validation or update failed.
function execute() {
  ensure_config_checkout
  log_info "Updating macsetup config ..."
  update_config_checkout
  log_success "macsetup config is current ($(git -C "${CONFIG_HOME}" rev-parse --short HEAD))"

  if [ -n "$(git -C "${CONFIG_HOME}" status --porcelain)" ]; then
    log_notice "local config changes are still unpublished — see 'rnfmac config status'"
  fi
}

${__SOURCED__:+return} # shellspec Include guard

execute
