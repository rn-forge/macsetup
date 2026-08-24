#!/bin/zsh
# shellcheck shell=bash
# @file status.sh
# @brief `rnfmac config status` — show configuration checkout status and local diff.
# @description
#   Read-only report on the macsetup-config checkout: where it is, what revision it
#   sits on, how it compares to origin/main, and the full diff of anything not yet
#   published — so there is never a reason to run git by hand inside the checkout.
# Version: 2.0
# Author: Rohit Narayanan

set -eo pipefail

RNF_HOME="${HOME}/.rn-forge"
source "${RNF_HOME}/shkit/current/shkit.sh"

SELF_PATH="$(readlink -f "$0")"
source "$(dirname "${SELF_PATH}")/lib.sh"

# @description Run a read-only git command in the config checkout with the pager off.
# @arg $@ string The git arguments.
# @stdout The command's output.
function config_git() {
  git -C "${CONFIG_HOME}" --no-pager "$@"
}

# @description Print the checkout location, branch, and current revision.
# @noargs
# @stdout The identity block.
function show_identity() {
  echo "config:   ${CONFIG_HOME}"
  echo "branch:   $(config_git branch --show-current)"
  echo "revision: $(config_git log -1 --format='%h %s (%ar)')"
}

# @description Fetch origin and report how the checkout compares to it, listing the
#   commits waiting to be pulled. A fetch failure is reported, not fatal — status
#   must still work offline.
# @noargs
# @stdout The remote comparison block.
function show_remote_state() {
  if ! config_git fetch --quiet origin "${CONFIG_BRANCH}" 2>/dev/null; then
    echo "remote:   unreachable — comparison below is against the last fetch"
    return 0
  fi

  local behind
  behind="$(config_git rev-list --count "HEAD..origin/${CONFIG_BRANCH}")"
  if [ "${behind}" -eq 0 ]; then
    echo "remote:   up to date with origin/${CONFIG_BRANCH}"
    return 0
  fi

  echo "remote:   ${behind} commit(s) behind origin/${CONFIG_BRANCH} — run 'rnfmac config pull'"
  echo ""
  echo "incoming:"
  config_git log --oneline --no-decorate "HEAD..origin/${CONFIG_BRANCH}"
}

# @description Print the full diff of unpublished work: tracked changes against HEAD,
#   then each untracked file diffed against /dev/null so new files show their contents
#   too (`git diff` alone would silently omit them).
# @noargs
# @stdout The local-changes block, or nothing beyond a success note when clean.
function show_local_changes() {
  if [ -z "$(config_git status --porcelain)" ]; then
    echo ""
    log_success "no local changes"
    return 0
  fi

  echo ""
  echo "local changes:"
  config_git status --short
  echo ""
  config_git diff --stat HEAD
  echo ""
  config_git diff HEAD

  local file
  while IFS= read -r file; do
    [ -n "${file}" ] || continue
    config_git diff --no-index -- /dev/null "${file}" || true
  done < <(config_git ls-files --others --exclude-standard)

  echo ""
  log_notice "publish with 'rnfmac config push -m <message>'"
}

# @description Show the branch, revision, remote comparison, and local diff of
#   macsetup-config.
# @noargs
function execute() {
  require_config_checkout
  show_identity
  show_remote_state
  show_local_changes
}

${__SOURCED__:+return} # shellspec Include guard

execute
