#!/bin/zsh
# shellcheck shell=bash
# @file cleanup.sh
# @brief `rnfmac cleanup` — deletes all installed macsetup versions except the current one.
# @description
#   Removes every version directory under ~/.rn-forge/macsetup/ other than the one
#   `current` points to. Upgrade/install never prune old versions themselves (that's
#   what makes rollback-by-symlink possible), so this is the explicit opt-in to
#   reclaim that disk space.
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

# @description Run `rnfmac cleanup`: delete every version dir under PRODUCT_HOME
#   except the one `current` resolves to. Prompts for confirmation first
#   (see shkit's `confirm` — bypass with RNF_SKIP_CONFIRMATIONS=1).
# @noargs
# @stdout One line per version removed, plus a summary.
# @exitcode 0 Always, including when there was nothing to remove.
# @exitcode 1 No current install found, or the user declined confirmation.
function execute() {
  local current_version dir name to_remove=() removed=0

  if [ ! -L "${PRODUCT_HOME}/current" ]; then
    log_error "no current install found at ${PRODUCT_HOME}/current"
    exit 1
  fi
  current_version="$(basename "$(readlink "${PRODUCT_HOME}/current")")"

  for dir in "${PRODUCT_HOME}"/v*/; do
    [ -d "${dir}" ] || continue
    name="$(basename "${dir}")"
    [ "${name}" = "${current_version}" ] && continue
    to_remove+=("${dir}")
  done

  if [ "${#to_remove[@]}" -eq 0 ]; then
    log_success "nothing to clean up — only ${current_version} is installed"
    return
  fi

  for dir in "${to_remove[@]}"; do
    log_info "  $(basename "${dir}")"
  done
  confirm "Remove ${#to_remove[@]} old version(s) from ${PRODUCT_HOME}"

  for dir in "${to_remove[@]}"; do
    log_info "removing $(basename "${dir}") ..."
    rm -rf "${dir}"
    removed=$((removed + 1))
  done

  log_success "removed ${removed} old version(s), kept ${current_version}"
}

${__SOURCED__:+return} # shellspec Include guard

print_vars "RNF_HOME" "PRODUCT_HOME"
execute
