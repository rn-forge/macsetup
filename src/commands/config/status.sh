#!/bin/zsh
# shellcheck shell=bash
# @file status.sh
# @brief `rnfmac config status` — show configuration checkout status.
# Version: 1.0
# Author: Rohit Narayanan

set -eo pipefail

RNF_HOME="${HOME}/.rn-forge"
source "${RNF_HOME}/shkit/current/shkit.sh"

SELF_PATH="$(readlink -f "$0")"
source "$(dirname "${SELF_PATH}")/lib.sh"

# @description Show the branch, revision, and working-tree status of macsetup-config.
# @noargs
function execute() {
  require_config_checkout
  echo "config: ${CONFIG_HOME}"
  echo "revision: $(git -C "${CONFIG_HOME}" rev-parse HEAD)"
  git -C "${CONFIG_HOME}" status --short --branch
}

${__SOURCED__:+return} # shellspec Include guard

execute
