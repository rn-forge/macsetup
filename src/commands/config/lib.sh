#!/bin/zsh
# shellcheck shell=bash
# @file lib.sh
# @brief Shared helpers for the `config` command group. Not dispatchable.
# Version: 1.0
# Author: Rohit Narayanan

RNF_HOME="${HOME}/.rn-forge"
PRODUCT_HOME="${RNF_HOME}/macsetup"
CONFIG_HOME="${PRODUCT_HOME}/config"
CONFIG_BRANCH="main"
CONFIG_REPO_URL="${RNFMAC_CONFIG_REPO_URL:-https://github.com/${RNF_GITHUB_ORG:-rn-forge}/macsetup-config.git}"

# @description Clone macsetup-config when upgrading an installation that predates
#   the external config checkout, otherwise validate the existing checkout.
# @noargs
# @exitcode 0 The checkout exists and is on the expected branch.
# @exitcode 1 Clone or checkout validation failed.
function ensure_config_checkout() {
  if [ ! -e "${CONFIG_HOME}" ]; then
    log_info "cloning macsetup config from ${CONFIG_REPO_URL} ..."
    git clone --quiet --branch "${CONFIG_BRANCH}" --single-branch "${CONFIG_REPO_URL}" "${CONFIG_HOME}"
  fi
  require_config_checkout
}

# @description Verify that the macsetup-config checkout exists and is on `main`.
# @noargs
# @exitcode 0 The checkout is valid and on the expected branch.
# @exitcode 1 The checkout is missing, invalid, or on another branch.
function require_config_checkout() {
  if ! git -C "${CONFIG_HOME}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log_error "macsetup config checkout is invalid at ${CONFIG_HOME}"
    return 1
  fi

  local branch
  branch="$(git -C "${CONFIG_HOME}" branch --show-current)"
  if [ "${branch}" != "${CONFIG_BRANCH}" ]; then
    log_error "macsetup config must be on '${CONFIG_BRANCH}' (currently '${branch:-detached}')"
    return 1
  fi
}

# @description Fail when the config checkout contains tracked or untracked changes.
# @noargs
# @exitcode 0 The checkout is clean.
# @exitcode 1 Local changes are present.
function require_clean_config() {
  if [ -n "$(git -C "${CONFIG_HOME}" status --porcelain)" ]; then
    log_error "macsetup config has local changes — publish or discard them before pulling"
    return 1
  fi
}
