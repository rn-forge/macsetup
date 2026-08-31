#!/bin/zsh
# shellcheck shell=bash
# @file doctor.sh
# @brief `rnfmac doctor` — read-only health sweep across all groups.
# @description
#   Meta: collect system doctor + profile check + brew diff and render one report.
# Version: 1.0
# Author: Rohit Narayanan

set -eo pipefail

RNF_HOME="${HOME}/.rn-forge"
source "${RNF_HOME}/shkit/current/shkit.sh"

SELF_PATH="$(readlink -f "$0")"
COMMANDS_PATH="$(dirname "${SELF_PATH}")"
source "${COMMANDS_PATH}/lib/report.sh"
export REPORT_GROUP="doctor"
REPORT_OUTPUT_FORMAT="human"

# @description Print `rnfmac doctor` usage.
# @stdout The usage text.
function usage() {
  echo "usage: rnfmac doctor [--all] [--json]"
}

# @description Parse reporting and help flags.
# @arg $@ string Flags: `--all`, `--json`, `-h`/`--help`/`help`.
# @set RNFMAC_REPORT_ALL Set to 1 when `--all` is passed.
# @set REPORT_OUTPUT_FORMAT Set to `json` when `--json` is passed.
# @exitcode 0 Parsed successfully, or help was requested.
# @exitcode 1 An argument was unrecognized.
function parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --all) export RNFMAC_REPORT_ALL=1 ;;
    --json) REPORT_OUTPUT_FORMAT=json ;;
    -h | --help | help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 1
      ;;
    esac
    shift
  done
}

# @description Collect all child check records and render one combined report.
# @set REPORT_RECORDS Replaced with records collected from all three child checks.
# @set RNFMAC_REPORT_FORMAT Temporarily set to raw, then to the requested output format.
# @set RNFMAC_REPORT_FILE Set to the temporary collector path, then unset.
function execute() {
  local records_file record
  records_file="$(mktemp)"
  RECORDS_FILE="${records_file}"
  trap 'rm -f "${RECORDS_FILE}"' EXIT

  RNFMAC_REPORT_FILE="${records_file}"
  RNFMAC_REPORT_FORMAT=raw
  export RNFMAC_REPORT_FILE RNFMAC_REPORT_FORMAT
  "${COMMANDS_PATH}/system/doctor.sh" || true
  "${COMMANDS_PATH}/profile/check.sh" || true
  "${COMMANDS_PATH}/brew/diff.sh" || true

  REPORT_RECORDS=()
  while IFS= read -r record; do
    REPORT_RECORDS+=("${record}")
  done <"${records_file}"

  RNFMAC_REPORT_FORMAT="${REPORT_OUTPUT_FORMAT}"
  export RNFMAC_REPORT_FORMAT
  unset RNFMAC_REPORT_FILE
  report_render
}

${__SOURCED__:+return} # shellspec Include guard

parse_args "$@"
execute
exit "$(report_exit_code)"
