#!/bin/zsh
# shellcheck shell=bash
# @file sync.sh
# @brief `rnfmac profile sync` — renders and installs the shell profile.
# @description
#   Script to install the macsetup distribution into RNF_HOME and render/patch the shell profile
# Run As: local admin
# Version: 1.0
# Author: Rohit Narayanan

set -eo pipefail
unsetopt nomatch

## shkit — installed by install.sh; sourced from the local install, no network,
## no PATH assumption (that's the shell profile's job)
RNF_HOME="${HOME}/.rn-forge"
source "${RNF_HOME}/shkit/current/shkit.sh"
export RNF_LOG_LEVEL=${RNF_LOG_LEVEL_DEBUG}

## global variables
SELF_PATH="$(readlink -f "$0")" # top level: inside a function zsh sets $0 to the function name
source "$(dirname "${SELF_PATH}")/lib.sh"

# =============================================================================
# Helper functions
# =============================================================================

# @description Back up a file to `RNF_HOME/backup/macsetup/`, timestamped, unless
#   it's identical to the most recent backup already taken.
# @arg $1 string Path to the file to back up. No-op if it doesn't exist.
function backup() {
  if [ ! -f "${1}" ]; then
    return
  fi
  local backup_path backup_prefix last_backup

  backup_path="${RNF_HOME}/backup/macsetup"
  backup_prefix="${backup_path}/$(basename "${1}")_"
  print_vars "backup_path" "backup_prefix"

  mkdir -p "${backup_path}"

  last_backup=$(ls -t "${backup_prefix}"* 2>/dev/null || true | head -1)
  if [ -n "${last_backup}" ] && diff -q "${1}" "${last_backup}" &>/dev/null; then
    return
  fi
  cp -fr "${1}" "${backup_prefix}$(date +%Y%m%d%H%M%S)"
}

# @description Back up and patch `~/.zprofile` to source the rendered profile,
#   idempotently (single marker guard, appended at end).
# @noargs
function update_zprofile() {
  ## check-and-insert-at-end: single marker guard, same as update_zshrc. If the
  ## marker is already present (e.g. from an older macsetup version's block) but
  ## the source line is missing, complete the block rather than re-adding the
  ## marker and duplicating it.
  backup "${HOME}/.zprofile"
  if ! grep -qF "${MACSETUP_MARKER}" "${HOME}/.zprofile" 2>/dev/null; then
    {
      echo "${MACSETUP_MARKER}"
      echo "${MACSETUP_SOURCE_LINE}"
    } >>"${HOME}/.zprofile"
  elif ! grep -qF "${MACSETUP_SOURCE_LINE}" "${HOME}/.zprofile" 2>/dev/null; then
    echo "${MACSETUP_SOURCE_LINE}" >>"${HOME}/.zprofile"
  fi
}

# @description Back up and patch `~/.zshrc` to source the rendered profile,
#   idempotently, inserting the source line before oh-my-zsh.sh loads (plugins=()
#   must be set before oh-my-zsh.sh reads it, which only .zprofile guarantees for
#   login shells — a non-login shell, e.g. tmux or a plain `zsh`, sources only
#   .zshrc, so it needs its own copy too).
# @noargs
function update_zshrc() {
  backup "${HOME}/.zshrc"
  if ! grep -qF "${MACSETUP_MARKER}" "${HOME}/.zshrc" 2>/dev/null; then
    awk -v marker="${MACSETUP_MARKER}" -v line="${MACSETUP_SOURCE_LINE}" '
      /^source \$ZSH\/oh-my-zsh\.sh/{
        print marker
        print line "\n"
      }
      { print }
    ' "${HOME}/.zshrc" >"${HOME}/.zshrc.tmp" && mv "${HOME}/.zshrc.tmp" "${HOME}/.zshrc"
  fi
}

# =============================================================================
# Main functions — one per pipeline step, run in order by execute()
# =============================================================================

# @description Render shared+host profile.zsh into `PRODUCT_HOME/profile.zsh` and
#   copy the host's Brewfile into place.
# @noargs
# @exitcode 1 No profile exists for the current host.
function render_profile() {
  log_verbose "Rendering profile for host '${HOST_NAME}' ..."
  local host_profile="${PRODUCT_HOME}/current/profiles/${HOST_NAME}/profile.zsh"

  if [ ! -f "${host_profile}" ]; then
    log_warning "no profile for host '${HOST_NAME}' — create src/profiles/${HOST_NAME}/ first"
    exit 1
  fi

  render_profile_content >"${PRODUCT_HOME}/profile.zsh"
  cp -f "${PRODUCT_HOME}/current/profiles/${HOST_NAME}/Brewfile" "${PRODUCT_HOME}/Brewfile"
}

# @description Patch .zprofile/.zshrc, install the oh-my-zsh theme, and install
#   the shared keybindings — everything except rendering profile.zsh itself.
# @noargs
function sync_profile() {
  ## Setting up .zprofile
  log_verbose "Setting up .zprofile ..."
  update_zprofile

  ## Setting up .zshrc
  log_verbose "Setting up .zshrc ..."
  update_zshrc

  ## Setting up oh-my-zsh theme
  log_verbose "Setting up oh-my-zsh theme ..."
  ln -f -s "${PRODUCT_HOME}/current/profiles/shared/rohitnarayanan.zsh-theme" "${HOME}"/.oh-my-zsh/custom/themes/rohitnarayanan.zsh-theme
  local theme_value
  theme_value="$(grep '^export ZSH_THEME=' "${PRODUCT_HOME}/profile.zsh" | head -1 | cut -d= -f2-)"
  backup "${HOME}/.zshrc"
  sed -i '' "s|^ZSH_THEME=.*|ZSH_THEME=${theme_value}|" "${HOME}/.zshrc"

  ## Setting up keybindings
  log_verbose "Setting up keybindings ..."
  backup "${HOME}/Library/KeyBindings/DefaultKeyBinding.dict"
  mkdir -p "${HOME}/Library/KeyBindings" && cp -f "${PRODUCT_HOME}/current/profiles/shared/DefaultKeyBinding.dict" "${HOME}/Library/KeyBindings/"
}

# @description Run `rnfmac profile sync`: render the profile, then apply it.
# @noargs
function execute() {
  render_profile
  sync_profile
}

${__SOURCED__:+return} # shellspec Include guard

print_vars "RNF_HOME" "HOST_NAME"
execute
log_success "Profile synced successfully !"
