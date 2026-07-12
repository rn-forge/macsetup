#!/bin/zsh
# shellcheck shell=bash
# @file sync.sh
# @brief `rnfmac system sync` — installs pinned runtimes.
# @description
#   Script to sync pinned runtimes (python/uv, node/nvm, java/sdkman)
# Version: 1.0
# Author: Rohit Narayanan

set -eo pipefail

## shkit — installed by install.sh; sourced from the local install, no network,
## no PATH assumption (that's the shell profile's job)
RNF_HOME="${HOME}/.rn-forge"
source "${RNF_HOME}/shkit/current/shkit.sh"
export RNF_LOG_LEVEL=${RNF_LOG_LEVEL_DEBUG}

# @description Install pinned runtimes: Python 3.15 via uv, Node LTS via nvm,
#   Java 21 Temurin via SDKMAN.
# @noargs
function sync_runtimes() {
  log_verbose "Syncing Python runtime ..."
  uv python install 3.15 --default
  export PATH="${HOME}/.local/bin:$PATH"
  log_success "$(python --version) synced successfully"

  log_verbose "Syncing node runtime ..."
  export NVM_DIR="$HOME/.nvm"
  source "${NVM_DIR}/nvm.sh"
  nvm install --lts
  log_success "node $(node --version) synced successfully"

  log_verbose "Syncing java runtimes ..."
  set +eu
  export SDKMAN_DIR="${HOME}/.sdkman"
  source "${SDKMAN_DIR}/bin/sdkman-init.sh"
  echo "Searching for java versions ..."
  local available_java_versions temurin_version
  # shellcheck disable=SC2043
  for java_version in "21"; do
    # shellcheck disable=SC2209
    available_java_versions=$(PAGER=cat sdk list java)
    log_verbose "searching java version ${java_version}"
    temurin_version="$(echo "${available_java_versions}" | grep "| tem" | grep ${java_version} | awk '{print $NF}')"
    log_verbose "Installing java version ${temurin_version}"
    sdk install java "${temurin_version}"
  done
  set -eu
}

${__SOURCED__:+return} # shellspec Include guard

sync_runtimes
log_success "System sync complete !"
