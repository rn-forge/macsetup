#!/bin/zsh
# shellcheck shell=bash
# @file lib.sh
# @brief Shared helpers for the `profile` command group. Not a sub-command itself.
# @description
#   Shared helpers for the profile group — sourced by commands/profile/sync.sh and
#   commands/profile/check.sh. Not a sub-command itself: rnfmac's dispatcher skips any
#   "lib.sh" when listing a group's sub-commands.
# Version: 1.0
# Author: Rohit Narayanan

PRODUCT_HOME="${RNF_HOME}/macsetup"
HOST_NAME="$(hostname | tr '[:upper:]' '[:lower:]' | cut -d. -f1)"
# shellcheck disable=SC2034 # consumed by callers that source this file, not used here
MACSETUP_MARKER="#################### macsetup"
# shellcheck disable=SC2034 # consumed by callers that source this file, not used here
MACSETUP_SOURCE_LINE="source ${PRODUCT_HOME}/profile.zsh"

# @description Render the shared + host `profile.zsh` (host wins by coming last)
#   into the combined content that `profile/sync.sh` installs.
# @noargs
# @stdout The rendered profile.zsh content, with marker headers.
function render_profile_content() {
  local shared_profile host_profile
  shared_profile="${PRODUCT_HOME}/current/profiles/shared/profile.zsh"
  host_profile="${PRODUCT_HOME}/current/profiles/${HOST_NAME}/profile.zsh"

  echo "#################### macsetup profile — rendered by profile/sync.sh, DO NOT EDIT"
  cat "${shared_profile}"
  echo ""
  echo "#################### aliases"
  cat "${PRODUCT_HOME}/current/profiles/shared/aliases.zsh"
  echo ""
  echo "#################### host overrides: ${HOST_NAME}"
  cat "${host_profile}"
}
