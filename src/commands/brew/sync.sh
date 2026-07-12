#!/bin/zsh
# shellcheck shell=bash
# @file sync.sh
# @brief `rnfmac brew sync` — installs/cleans up Homebrew packages against the host Brewfile.
# @description
#   Script to sync installed Homebrew packages against the host Brewfile
# Version: 1.0
# Author: Rohit Narayanan

set -eo pipefail

## shkit — installed by install.sh; sourced from the local install, no network,
## no PATH assumption (that's the shell profile's job)
RNF_HOME="${HOME}/.rn-forge"
source "${RNF_HOME}/shkit/current/shkit.sh"
export RNF_LOG_LEVEL=${RNF_LOG_LEVEL_DEBUG}

## global variables
PRODUCT_HOME="${RNF_HOME}/macsetup"
HOST_NAME="$(hostname | tr '[:upper:]' '[:lower:]' | cut -d. -f1)"
BREWFILE="${PRODUCT_HOME}/current/profiles/${HOST_NAME}/Brewfile"

# @description Run `brew bundle install` + `cleanup` against `BREWFILE`.
# @noargs
function sync_packages() {
  log_verbose "Syncing brew packages ..."
  brew bundle install --file="${BREWFILE}" --verbose --force
  brew bundle cleanup --file="${BREWFILE}" --verbose --force
  log_success "Brew packages synced successfully"
  brew list
}

${__SOURCED__:+return} # shellspec Include guard

print_vars "RNF_HOME" "BREWFILE"
sync_packages
log_success "Brew sync complete !"
