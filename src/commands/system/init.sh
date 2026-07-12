#!/bin/zsh
# shellcheck shell=bash
# @file init.sh
# @brief `rnfmac system init` — one-time bootstrap of a new macOS system.
# @description
#   Script to bootstrap a new macOS system from scratch
# Run As: local admin
# Version: 1.0
# Author: Rohit Narayanan

set -eo pipefail

## shkit — installed by install.sh; sourced from the local install, no network,
## no PATH assumption (that's the shell profile's job)
RNF_HOME="${HOME}/.rn-forge"
source "${RNF_HOME}/shkit/current/shkit.sh"

FORCE_FLAG=0

# =============================================================================
# Helper functions
# =============================================================================

# @description Print `rnfmac system init` usage.
# @noargs
# @stdout The usage text.
function usage() {
  cat <<EOF
Usage: rnfmac system init [--force]

  (no flag)  bootstrap a new macOS system — installs Homebrew, oh-my-zsh, uv, nvm,
             SDKMAN, skipping any already present
  --force    reinstall/reconfigure every component, even ones already present
EOF
}

# @description Parse CLI args, setting `FORCE_FLAG` and handling `-h`/`--help`.
# @arg $@ string Flags: `--force`, `-h`/`--help`/`help`.
# @set FORCE_FLAG Set to 1 if `--force` was passed.
# @exitcode 0 Parsed successfully, or help was requested (also exits the script).
# @exitcode 1 Unrecognized argument.
function parse_args() {
  local arg
  for arg in "$@"; do
    case "${arg}" in
    --force) FORCE_FLAG=1 ;;
    -h | --help | help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 1
      ;;
    esac
  done
}

# @description Load `brew shellenv` into the current shell for the right Homebrew
#   prefix (Apple Silicon vs Intel).
# @noargs
function activate_homebrew() {
  if [ "$(uname -m)" = "arm64" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    eval "$(/usr/local/bin/brew shellenv zsh)"
  fi
}

# =============================================================================
# Main functions — one per installer step, run in order by execute()
# =============================================================================

# @description Run `rnfmac system init`: install Homebrew, oh-my-zsh (+ plugins),
#   uv, nvm, and SDKMAN, in order, skipping (or with `FORCE_FLAG`, reinstalling)
#   any already present.
# @noargs
function execute() {
  setup_homebrew
  setup_ohmyzsh
  setup_uv

  ## needed for nvm and sdkman
  brew install bash

  setup_nvm
  setup_sdkman
}

# @description Install Homebrew (or reinstall if `FORCE_FLAG` is set), then
#   activate it in the current shell.
# @noargs
function setup_homebrew() {
  log_info "Setting up homebrew ..."

  activate_homebrew

  if [ -f /opt/homebrew/bin/brew ]; then
    if [ "${FORCE_FLAG}" -eq 0 ]; then
      log_warning "\`$(brew --version)\` available, skipping ..."
      return
    fi

    log_warning "Forcing homebrew reinstallation ..."
  else
    log_notice "Installing homebrew ..."
  fi

  ## install homebrew - https://brew.sh
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  activate_homebrew

  log_success "\`$(brew --version)\` setup complete ..."
}

# @description Install oh-my-zsh and its zsh-completions/zsh-autosuggestions/
#   zsh-syntax-highlighting plugins (or reinstall if `FORCE_FLAG` is set).
# @noargs
function setup_ohmyzsh() {
  log_info "Setting up ohmyzsh ..."

  if [ -d "${HOME}/.oh-my-zsh" ]; then
    if [ "${FORCE_FLAG}" -eq 0 ]; then
      log_warning "oh-my-zsh available, skipping ..."
      source "${HOME}"/.zshrc || true # handle return 3 from oh-my-zsh.sh
      return
    fi

    log_warning "Removing existing oh-my-zsh for reinstallation ..."
    rm -fr "${HOME}/.oh-my-zsh"
  else
    log_notice "Installing ohmyzsh ..."
  fi

  ## install ohmyzsh - https://ohmyz.sh/#install
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  source "${HOME}/.zshrc" || true # handle return 3 from oh-my-zsh.sh
  git clone https://github.com/zsh-users/zsh-completions.git "${ZSH_CUSTOM}/plugins/zsh-completions"
  git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM}/plugins/zsh-autosuggestions"
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"

  log_success "oh-my-zsh setup complete ..."
  log_notice "run 'rnfmac profile sync' to setup zsh environment"
}

# @description Install uv via Homebrew (or reinstall if `FORCE_FLAG` is set).
# @noargs
function setup_uv() {
  log_info "Setting up uv ..."

  if [ -f "${HOMEBREW_PREFIX}/bin/uv" ]; then
    if [ "${FORCE_FLAG}" -eq 0 ]; then
      log_warning "\`$(uv --version)\` available, skipping ..."
      return
    fi

    log_warning "Forcing uv reinstallation ..."
  else
    log_notice "Installing uv ..."
  fi

  ## install uv - https://docs.astral.sh/uv/getting-started/installation/
  brew install uv

  log_success "\`$(uv --version)\` setup complete ..."
}

# @description Install nvm (or reinstall if `FORCE_FLAG` is set).
# @noargs
function setup_nvm() {
  log_info "Setting up nvm ..."

  export NVM_DIR="${HOME}/.nvm"
  if [ -d "${NVM_DIR}" ]; then
    if [ "${FORCE_FLAG}" -eq 0 ]; then
      source "${NVM_DIR}/nvm.sh"
      log_warning "\`nvm $(nvm --version)\` available, skipping ..."
      return
    fi

    log_warning "Removing existing nvm for reinstallation ..."
    rm -fr "${NVM_DIR}"
  else
    log_notice "Installing nvm ..."
  fi

  ## https://github.com/nvm-sh/nvm
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | PROFILE=/dev/null "${HOMEBREW_PREFIX}"/bin/bash
  source "${NVM_DIR}/nvm.sh"

  log_success "\`nvm $(nvm --version)\` setup complete ..."
}

# @description Install SDKMAN (or reinstall if `FORCE_FLAG` is set).
# @noargs
function setup_sdkman() {
  log_info "Setting up sdkman ..."

  export SDKMAN_DIR="${HOME}/.sdkman"

  if [ -f "${SDKMAN_DIR}/bin/sdkman-init.sh" ]; then
    if [ "${FORCE_FLAG}" -eq 0 ]; then
      source "${SDKMAN_DIR}/bin/sdkman-init.sh"
      log_warning "\`sdkman ($(sdk version | sed -n '3p;4p;d' | awk '{print $1,$2}' | tr '\n' ';'))\` already installed, skipping ..."
      return
    fi

    log_warning "Removing existing SDKMAN installation ..."
    rm -fr "${HOME}/.sdkman"
  else
    log_notice "Installing SDKMAN ..."
  fi

  ## https://sdkman.io
  curl -s "https://get.sdkman.io?rcupdate=false" | "${HOMEBREW_PREFIX}"/bin/bash
  source "${SDKMAN_DIR}/bin/sdkman-init.sh"

  log_success "\`sdkman ($(sdk version | sed -n '3p;4p;d' | awk '{print $1,$2}' | tr '\n' ';'))\` setup complete ..."
}

${__SOURCED__:+return} # shellspec Include guard

parse_args "$@"
print_vars "SCRIPT_DIR" "RNF_HOME" "FORCE_FLAG"
execute
log_success "System setup complete !"
log_notice "behind a corporate network/Zscaler? run 'rnfmac brew relay'"
