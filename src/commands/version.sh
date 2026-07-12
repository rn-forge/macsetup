#!/bin/zsh
# shellcheck shell=bash
# @file version.sh
# @brief `rnfmac version` — prints the installed macsetup version.
# @description
#   Prints the installed macsetup version
# Version: 1.0
# Author: Rohit Narayanan

set -eo pipefail

SELF_PATH="$(readlink -f "$0")"
DIST_ROOT="$(dirname "$(dirname "${SELF_PATH}")")" # unpacked dist root, or src/ in a git checkout

if [ -f "${DIST_ROOT}/VERSION" ]; then
  cat "${DIST_ROOT}/VERSION"
else
  cat "$(dirname "${DIST_ROOT}")/VERSION"
fi
