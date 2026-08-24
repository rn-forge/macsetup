#!/bin/zsh
# shellcheck shell=bash
# @file pull.sh
# @brief `rnfmac config pull` — fast-forward the configuration checkout.
# @description
#   Updates the persistent macsetup-config checkout from origin/main. Refuses dirty
#   or divergent checkouts; it never merges, rebases, or overwrites local changes.
# Version: 1.0
# Author: Rohit Narayanan

set -eo pipefail

RNF_HOME="${HOME}/.rn-forge"
source "${RNF_HOME}/shkit/current/shkit.sh"

SELF_PATH="$(readlink -f "$0")"
source "$(dirname "${SELF_PATH}")/lib.sh"

# @description Pull `origin/main` with fast-forward-only semantics.
# @noargs
# @exitcode 0 Configuration is current.
# @exitcode 1 Checkout validation or pull failed.
function execute() {
  require_config_checkout
  require_clean_config
  log_info "Updating macsetup config ..."
  git -C "${CONFIG_HOME}" pull --quiet --ff-only origin "${CONFIG_BRANCH}"
  log_success "macsetup config is current ($(git -C "${CONFIG_HOME}" rev-parse --short HEAD))"
}

${__SOURCED__:+return} # shellspec Include guard

execute
