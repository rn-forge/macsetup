#!/bin/zsh
# shellcheck shell=bash
# @file doctor.sh
# @brief `rnfmac doctor` — read-only health sweep across all groups.
# @description
#   Meta: system doctor + profile check + brew diff, a read-only sweep across all
#   groups. Exit 0 healthy, 1 if any group reports drift/problems.
# Version: 1.0
# Author: Rohit Narayanan

set -eo pipefail

SELF_PATH="$(readlink -f "$0")"
COMMANDS_PATH="$(dirname "${SELF_PATH}")"
PROBLEMS=0

# @description Run `rnfmac doctor`: system doctor, profile check, and brew diff, all
#   read-only. Continues through all three even if one reports drift.
# @noargs
# @set PROBLEMS Set to 1 if any group reported drift/problems.
function execute() {
  "${COMMANDS_PATH}/system/doctor.sh" || PROBLEMS=1
  "${COMMANDS_PATH}/profile/check.sh" || PROBLEMS=1
  "${COMMANDS_PATH}/brew/diff.sh" || PROBLEMS=1
}

${__SOURCED__:+return} # shellspec Include guard

execute
exit "${PROBLEMS}"
