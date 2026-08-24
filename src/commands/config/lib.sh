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

# @description Fast-forward the config checkout onto `origin/<branch>`, carrying any
#   uncommitted local changes across the update on a stash. Local edits and a moved
#   remote are the normal case here, not an error — the checkout is a working copy that
#   `sync`/`upgrade` update behind the user's back, so refusing either side would
#   deadlock `pull` (wants a clean tree) against `push` (wants an up-to-date HEAD).
#   Only genuine divergence — local commits absent from the remote — is refused.
# @noargs
# @exitcode 0 The checkout is at `origin/<branch>` with local changes intact.
# @exitcode 1 The checkout diverged, could not fast-forward, or the stash conflicted.
function update_config_checkout() {
  git -C "${CONFIG_HOME}" fetch --quiet origin "${CONFIG_BRANCH}"

  local local_head remote_head
  local_head="$(git -C "${CONFIG_HOME}" rev-parse HEAD)"
  remote_head="$(git -C "${CONFIG_HOME}" rev-parse "origin/${CONFIG_BRANCH}")"
  if [ "${local_head}" = "${remote_head}" ]; then
    return 0
  fi

  if ! git -C "${CONFIG_HOME}" merge-base --is-ancestor HEAD "origin/${CONFIG_BRANCH}"; then
    log_error "macsetup config has local commits that are not on origin/${CONFIG_BRANCH} — reconcile ${CONFIG_HOME} by hand"
    return 1
  fi

  local stashed=0
  if [ -n "$(git -C "${CONFIG_HOME}" status --porcelain)" ]; then
    log_info "holding local config changes aside while updating ..."
    git -C "${CONFIG_HOME}" stash push --quiet --include-untracked --message "rnfmac config update" || return 1
    stashed=1
  fi

  if ! git -C "${CONFIG_HOME}" merge --quiet --ff-only "origin/${CONFIG_BRANCH}"; then
    log_error "could not fast-forward macsetup config to origin/${CONFIG_BRANCH}"
    if [ "${stashed}" -eq 1 ]; then
      git -C "${CONFIG_HOME}" stash pop --quiet
    fi
    return 1
  fi

  log_info "updated macsetup config to $(git -C "${CONFIG_HOME}" rev-parse --short HEAD)"

  if [ "${stashed}" -eq 1 ] && ! git -C "${CONFIG_HOME}" stash pop --quiet; then
    log_error "local config changes conflict with origin/${CONFIG_BRANCH} — resolve the conflicts in ${CONFIG_HOME}, then run 'rnfmac config push -m <message>'"
    return 1
  fi
}
