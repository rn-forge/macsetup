#!/bin/zsh
# shellcheck shell=bash
# @file doctor.sh
# @brief `rnfmac system doctor` — read-only toolchain health check.
# @description
#   Read-only health report for machine toolchain state. Exit 0 healthy, 1 problems found.
# Version: 1.0
# Author: Rohit Narayanan

set -eo pipefail

RNF_HOME="${HOME}/.rn-forge"
source "${RNF_HOME}/shkit/current/shkit.sh"

PROBLEMS=0

# =============================================================================
# Helper functions
# =============================================================================

# @description Log a warning and mark the run as having found a problem.
# @arg $1 string The warning message.
# @set PROBLEMS Set to 1.
function report_problem() {
  log_warning "$1"
  PROBLEMS=1
}

# =============================================================================
# Main functions — one check per subsystem, run in order by execute()
# =============================================================================

# @description Check Homebrew and its required oh-my-zsh plugins are installed.
# @noargs
function check_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    log_success "$(brew --version | head -1)"
  else
    report_problem "homebrew not found — run 'rnfmac system init'"
    return
  fi

  local plugin
  for plugin in zsh-completions zsh-autosuggestions zsh-syntax-highlighting; do
    if [ -d "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/${plugin}" ]; then
      log_success "oh-my-zsh plugin '${plugin}' present"
    else
      report_problem "oh-my-zsh plugin '${plugin}' missing — run 'rnfmac system init'"
    fi
  done
}

# @description Check oh-my-zsh is installed.
# @noargs
function check_ohmyzsh() {
  if [ -d "${HOME}/.oh-my-zsh" ]; then
    log_success "oh-my-zsh present"
  else
    report_problem "oh-my-zsh not found — run 'rnfmac system init'"
  fi
}

# @description Check uv, nvm, and sdkman are installed.
# @noargs
function check_runtime_managers() {
  if command -v uv >/dev/null 2>&1; then
    log_success "$(uv --version)"
  else
    report_problem "uv not found — run 'rnfmac system init'"
  fi

  if [ -d "${HOME}/.nvm" ]; then
    log_success "nvm present"
  else
    report_problem "nvm not found — run 'rnfmac system init'"
  fi

  if [ -f "${HOME}/.sdkman/bin/sdkman-init.sh" ]; then
    log_success "sdkman present"
  else
    report_problem "sdkman not found — run 'rnfmac system init'"
  fi
}

# @description Check the `~/.rn-forge` runtime layout: macsetup's `current` symlink,
#   `bin/rnfmac`, `completions/_rnfmac`, and the installed shkit.
# @noargs
function check_rn_forge_layout() {
  local product_home="${RNF_HOME}/macsetup"

  if [ -L "${product_home}/current" ] && [ -e "${product_home}/current" ]; then
    log_success "macsetup current -> $(readlink "${product_home}/current")"
  else
    report_problem "macsetup 'current' symlink missing or broken — run 'rnfmac profile sync'"
  fi

  if [ -L "${RNF_HOME}/bin/rnfmac" ] && [ -e "${RNF_HOME}/bin/rnfmac" ]; then
    log_success "bin/rnfmac linked"
  else
    report_problem "bin/rnfmac missing or broken — run 'rnfmac profile sync'"
  fi

  if [ -L "${RNF_HOME}/completions/_rnfmac" ] && [ -e "${RNF_HOME}/completions/_rnfmac" ]; then
    log_success "completions/_rnfmac linked"
  else
    report_problem "completions/_rnfmac missing or broken — run 'rnfmac profile sync'"
  fi

  if [ -f "${RNF_HOME}/shkit/current/shkit.sh" ]; then
    log_success "shkit installed and sourceable"
  else
    report_problem "shkit not found at ${RNF_HOME}/shkit/current — reinstall macsetup"
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
  homebrew_prefix="$(brew --prefix 2>/dev/null)"
  if [ -z "${homebrew_prefix}" ] || ! git -C "${homebrew_prefix}" rev-parse --show-toplevel >/dev/null 2>&1; then
    return
  fi

  if git -C "${homebrew_prefix}" log -1 --pretty=%s 2>/dev/null | grep -q '^rn-forge: apply Homebrew remote relay$'; then
    log_notice "Homebrew is patched with the remote relay (rnfmac brew relay --reset to undo)"
  else
    log_success "Homebrew is on a clean base (no remote relay patch)"
  fi
}

# @description Run `rnfmac system doctor`: all toolchain checks, in order.
# @noargs
# @set PROBLEMS Left at 1 if any check reported a problem.
function execute() {
  check_homebrew
  check_ohmyzsh
  check_runtime_managers
  check_rn_forge_layout
  check_relay_state
}

${__SOURCED__:+return} # shellspec Include guard

execute
if [ "${PROBLEMS}" -eq 0 ]; then
  log_success "system doctor passed"
fi
exit "${PROBLEMS}"
