#!/bin/zsh
# shellcheck shell=bash
# @file push.sh
# @brief `rnfmac config push` — commit and publish configuration changes.
# @description
#   Publishes local macsetup-config changes directly to the linear main branch.
#   Requires an explicit commit message and refuses to merge, rebase, or force-push.
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
  if [ -z "${2+x}" ] || [ -n "${3+x}" ] || { [ "$1" != "-m" ] && [ "$1" != "--message" ]; } || [ -z "$2" ]; then
    echo "usage: rnfmac config push -m <message>" >&2
    return 1
  fi
  MESSAGE="$2"
}

# @description Commit all config checkout changes and push them to origin/main.
# @noargs
# @exitcode 1 No changes exist, or local main is not equal to origin/main.
function execute() {
  require_config_checkout

  if [ -z "$(git -C "${CONFIG_HOME}" status --porcelain)" ]; then
    log_error "macsetup config has no changes to publish"
    return 1
  fi

  git -C "${CONFIG_HOME}" fetch --quiet origin "${CONFIG_BRANCH}"
  local local_head remote_head
  local_head="$(git -C "${CONFIG_HOME}" rev-parse HEAD)"
  remote_head="$(git -C "${CONFIG_HOME}" rev-parse "origin/${CONFIG_BRANCH}")"
  if [ "${local_head}" != "${remote_head}" ]; then
    log_error "local config is not current with origin/${CONFIG_BRANCH} — reconcile it before publishing"
    return 1
  fi

  git -C "${CONFIG_HOME}" add -A
  git -C "${CONFIG_HOME}" commit -m "${MESSAGE}"
  git -C "${CONFIG_HOME}" push --quiet origin "${CONFIG_BRANCH}"
  log_success "macsetup config published ($(git -C "${CONFIG_HOME}" rev-parse --short HEAD))"
}

${__SOURCED__:+return} # shellspec Include guard

parse_args "$@"
execute
