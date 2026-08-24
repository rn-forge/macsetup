#!/bin/zsh
# shellcheck shell=bash
# @file push.sh
# @brief `rnfmac config push` — commit and publish configuration changes.
# @description
#   Publishes local macsetup-config changes directly to the linear main branch.
#   Fast-forwards onto origin/main first (carrying the local changes across) so a
#   remote that moved on is not a reason to fail. Requires an explicit commit
#   message and refuses to merge, rebase, or force-push.
# Version: 1.0
# Author: Rohit Narayanan

set -eo pipefail

RNF_HOME="${HOME}/.rn-forge"
source "${RNF_HOME}/shkit/current/shkit.sh"

SELF_PATH="$(readlink -f "$0")"
source "$(dirname "${SELF_PATH}")/lib.sh"

MESSAGE=""

# @description Parse `-m <message>` or `--message <message>`.
# @arg $@ string Command arguments.
# @exitcode 1 Arguments are missing or invalid.
function parse_args() {
  local flag="$1" message="$2"
  if [[ $# -ne 2 ]] || { [[ "${flag}" != "-m" ]] && [[ "${flag}" != "--message" ]]; } || [[ -z "${message}" ]]; then
    echo "usage: rnfmac config push -m <message>" >&2
    return 1
  fi
  MESSAGE="${message}"
}

# @description Fast-forward onto origin/main, then commit all config checkout
#   changes and push them.
# @noargs
# @exitcode 1 No changes exist, or the checkout could not be brought up to date.
function execute() {
  require_config_checkout

  if [[ -z "$(git -C "${CONFIG_HOME}" status --porcelain)" ]]; then
    log_error "macsetup config has no changes to publish"
    return 1
  fi

  update_config_checkout

  git -C "${CONFIG_HOME}" add -A
  git -C "${CONFIG_HOME}" commit -m "${MESSAGE}"
  git -C "${CONFIG_HOME}" push --quiet origin "${CONFIG_BRANCH}"
  log_success "macsetup config published ($(git -C "${CONFIG_HOME}" rev-parse --short HEAD))"
}

${__SOURCED__:+return} # shellspec Include guard

parse_args "$@"
execute
