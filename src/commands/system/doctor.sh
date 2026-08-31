#!/bin/zsh
# shellcheck shell=bash
# @file doctor.sh
# @brief `rnfmac system doctor` — read-only toolchain health check.
# @description
#   Read-only structured health report for machine toolchain state.
# Version: 1.0
# Author: Rohit Narayanan

set -eo pipefail

RNF_HOME="${HOME}/.rn-forge"
source "${RNF_HOME}/shkit/current/shkit.sh"

SELF_PATH="$(readlink -f "$0")"
source "$(dirname "$(dirname "${SELF_PATH}")")/lib/report.sh"
export REPORT_GROUP="system"

# =============================================================================
# Helper functions
# =============================================================================

# @description Print `rnfmac system doctor` usage.
# @stdout The usage text.
function usage() {
  echo "usage: rnfmac system doctor [--all] [--json]"
}

# @description Parse reporting and help flags.
# @arg $@ string Flags: `--all`, `--json`, `-h`/`--help`/`help`.
# @set RNFMAC_REPORT_ALL Set to 1 when `--all` is passed.
# @set RNFMAC_REPORT_FORMAT Set to `json` when `--json` is passed.
# @exitcode 0 Parsed successfully, or help was requested.
# @exitcode 1 An argument was unrecognized.
function parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --all) export RNFMAC_REPORT_ALL=1 ;;
    --json) export RNFMAC_REPORT_FORMAT=json ;;
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

# =============================================================================
# Main functions — one check per subsystem, run in order by execute()
# =============================================================================

# @description Check Homebrew and its required oh-my-zsh plugins are installed.
# @noargs
function check_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    report_add "ok" "toolchain" "homebrew" "$(brew --version | head -1)"
  else
    report_add "error" "toolchain" "homebrew" "homebrew not found — run 'rnfmac system init'"
    return
  fi

  local plugin
  for plugin in zsh-completions zsh-autosuggestions zsh-syntax-highlighting; do
    if [[ -d "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/${plugin}" ]]; then
      report_add "ok" "toolchain" "omz-plugin" "oh-my-zsh plugin '${plugin}' present"
    else
      report_add "drift" "toolchain" "omz-plugin" "oh-my-zsh plugin '${plugin}' missing — run 'rnfmac system init'"
    fi
  done
}

# @description Check oh-my-zsh is installed.
# @noargs
function check_ohmyzsh() {
  if [[ -d "${HOME}/.oh-my-zsh" ]]; then
    report_add "ok" "toolchain" "oh-my-zsh" "oh-my-zsh present"
  else
    report_add "drift" "toolchain" "oh-my-zsh" "oh-my-zsh not found — run 'rnfmac system init'"
  fi
}

# @description Check uv, nvm, and sdkman are installed.
# @noargs
function check_runtime_managers() {
  if command -v uv >/dev/null 2>&1; then
    report_add "ok" "toolchain" "uv" "$(uv --version)"
  else
    report_add "drift" "toolchain" "uv" "uv not found — run 'rnfmac system init'"
  fi

  if [[ -d "${HOME}/.nvm" ]]; then
    report_add "ok" "toolchain" "nvm" "nvm present"
  else
    report_add "drift" "toolchain" "nvm" "nvm not found — run 'rnfmac system init'"
  fi

  if [[ -f "${HOME}/.sdkman/bin/sdkman-init.sh" ]]; then
    report_add "ok" "toolchain" "sdkman" "sdkman present"
  else
    report_add "drift" "toolchain" "sdkman" "sdkman not found — run 'rnfmac system init'"
  fi
}

# @description Check the `~/.rn-forge` runtime layout: macsetup's `current` symlink,
#   `bin/rnfmac`, `completions/_rnfmac`, and the installed shkit.
# @noargs
function check_rn_forge_layout() {
  local product_home="${RNF_HOME}/macsetup"

  if [[ -L "${product_home}/current" ]] && [[ -e "${product_home}/current" ]]; then
    report_add "ok" "runtime" "current-symlink" "macsetup current -> $(readlink "${product_home}/current")"
  else
    report_add "error" "runtime" "current-symlink" "macsetup 'current' symlink missing or broken — run 'rnfmac profile sync'"
  fi

  if [[ -L "${RNF_HOME}/bin/rnfmac" ]] && [[ -e "${RNF_HOME}/bin/rnfmac" ]]; then
    report_add "ok" "runtime" "bin-symlink" "bin/rnfmac linked"
  else
    report_add "error" "runtime" "bin-symlink" "bin/rnfmac missing or broken — run 'rnfmac profile sync'"
  fi

  if [[ -L "${RNF_HOME}/completions/_rnfmac" ]] && [[ -e "${RNF_HOME}/completions/_rnfmac" ]]; then
    report_add "ok" "runtime" "completions-symlink" "completions/_rnfmac linked"
  else
    report_add "drift" "runtime" "completions-symlink" "completions/_rnfmac missing or broken — run 'rnfmac profile sync'"
  fi

  if [[ -f "${RNF_HOME}/shkit/current/shkit.sh" ]]; then
    report_add "ok" "runtime" "shkit" "shkit installed and sourceable"
  else
    report_add "error" "runtime" "shkit" "shkit not found at ${RNF_HOME}/shkit/current — reinstall macsetup"
  fi
}

# @description Report (informationally, never a problem) whether Homebrew is
#   currently patched with the remote relay. No-ops if Homebrew or its git repo
#   isn't present.
# @noargs
function check_relay_state() {
  if ! command -v brew >/dev/null 2>&1; then
    return
  fi
  local homebrew_prefix
  homebrew_prefix="$(brew --prefix 2>/dev/null)" || return 0
  if [[ -z "${homebrew_prefix}" ]] || ! git -C "${homebrew_prefix}" rev-parse --show-toplevel >/dev/null 2>&1; then
    return
  fi

  if git -C "${homebrew_prefix}" log -1 --pretty=%s 2>/dev/null | grep -q '^rn-forge: apply Homebrew remote relay$'; then
    report_add "ok" "runtime" "relay" "Homebrew is patched with the remote relay (rnfmac brew relay --reset to undo)"
  else
    report_add "ok" "runtime" "relay" "Homebrew is on a clean base (no remote relay patch)"
  fi
}

# @description Run `rnfmac system doctor`: all toolchain checks, in order.
# @noargs
function execute() {
  check_homebrew
  check_ohmyzsh
  check_runtime_managers
  check_rn_forge_layout
  check_relay_state
}

${__SOURCED__:+return} # shellspec Include guard

parse_args "$@"
execute
report_render
exit "$(report_exit_code)"
