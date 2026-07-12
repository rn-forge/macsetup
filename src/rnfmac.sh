#!/bin/zsh
# shellcheck shell=bash
# @file rnfmac.sh
# @brief The `rnfmac` command dispatcher.
# @description
#   `rnfmac <sub-command> [args ...]` runs commands/<sub_command>.sh.
#   `rnfmac <group> <sub-command> [args ...]` runs commands/<group>/<sub_command>.sh
#   when commands/<group>/ is a directory. Dropping a script into commands/ (or a
#   new commands/<group>/) adds the sub-command with no registration anywhere else —
#   this file only ever lists what's already on disk.
# Version: 2.0
# Author: Rohit Narayanan

set -eo pipefail

SELF_PATH="$(readlink -f "$0")"
COMMANDS_PATH="$(dirname "${SELF_PATH}")/commands"

# @description "lib" is a reserved name, not a sub-command: a top-level commands/lib/
#   directory, or a commands/<group>/lib.sh, holds helpers shared within that scope
#   and gets sourced by the real sub-commands rather than dispatched to directly.
# @arg $1 string A sub-command or group name to test.
# @exitcode 0 If `$1` is the reserved name "lib".
# @exitcode 1 Otherwise.
function is_lib_name() {
  [ "$1" = "lib" ]
}

# @description List top-level sub-commands (commands/*.sh) and sub-command groups
#   (commands/*/), skipping the reserved "lib" name in either position.
# @stdout One `  <name>` line per sub-command, one `  <name> ...` line per group.
function list_top_level() {
  local script name
  for script in "${COMMANDS_PATH}"/*.sh; do
    [ -e "${script}" ] || continue
    name="$(basename "${script}" .sh)"
    is_lib_name "${name}" && continue
    echo "  ${name//_/-}"
  done
  local dir
  for dir in "${COMMANDS_PATH}"/*/; do
    [ -d "${dir}" ] || continue
    name="$(basename "${dir}")"
    is_lib_name "${name}" && continue
    echo "  ${name//_/-} ..."
  done
}

# @description List the sub-commands within one group directory, skipping "lib.sh".
# @arg $1 string Path to a commands/<group>/ directory.
# @stdout One `  <name>` line per sub-command in the group.
function list_group() {
  local group_path="$1" script name
  for script in "${group_path}"/*.sh; do
    [ -e "${script}" ] || continue
    name="$(basename "${script}" .sh)"
    is_lib_name "${name}" && continue
    echo "  ${name//_/-}"
  done
}

# @description Print top-level usage: `rnfmac <sub-command> [args ...]` plus the
#   list of available sub-commands and groups.
# @stdout The usage text.
function usage() {
  echo "usage: rnfmac <sub-command> [args ...]"
  echo "sub-commands:"
  list_top_level
}

# @description Print usage for one sub-command group: `rnfmac <group> <sub-command>
#   [args ...]` plus the list of sub-commands within that group.
# @arg $1 string Group name (already underscore-normalized).
# @stdout The usage text.
function group_usage() {
  local group="$1"
  echo "usage: rnfmac ${group} <sub-command> [args ...]"
  echo "sub-commands:"
  list_group "${COMMANDS_PATH}/${group}"
}

if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$1" = "help" ]; then
  usage
  exit 0
fi

SUB_COMMAND="$1"
GROUP_DIR="${COMMANDS_PATH}/${SUB_COMMAND//-/_}"

if [ -d "${GROUP_DIR}" ]; then
  shift
  if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$1" = "help" ]; then
    group_usage "${SUB_COMMAND//-/_}"
    exit 0
  fi

  GROUP_SUB_COMMAND="$1"
  shift
  SUB_COMMAND_SCRIPT="${GROUP_DIR}/${GROUP_SUB_COMMAND//-/_}.sh"
  if [ ! -x "${SUB_COMMAND_SCRIPT}" ]; then
    echo "rnfmac: unknown sub-command '${SUB_COMMAND} ${GROUP_SUB_COMMAND}'" >&2
    group_usage "${SUB_COMMAND//-/_}" >&2
    exit 1
  fi

  exec "${SUB_COMMAND_SCRIPT}" "$@"
fi

shift
SUB_COMMAND_SCRIPT="${COMMANDS_PATH}/${SUB_COMMAND//-/_}.sh"
if [ ! -x "${SUB_COMMAND_SCRIPT}" ]; then
  echo "rnfmac: unknown sub-command '${SUB_COMMAND}'" >&2
  usage >&2
  exit 1
fi

exec "${SUB_COMMAND_SCRIPT}" "$@"
