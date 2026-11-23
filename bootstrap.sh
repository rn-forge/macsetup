#!/bin/zsh
# shellcheck shell=bash
#
# Take a fresh Mac from nothing to an installed Python rnfmac: Homebrew, then
# uv, then `rnfmac self install`. Source it, do not execute it:
#
#   . bootstrap.sh [--force] [--archive <file> --version <version>]
#
# It never exits the calling shell: on failure it returns non-zero.

# Top level on purpose: assignments made in a function of a sourced file vanish
# under zsh.
export RNF_HOME="${RNF_HOME:-${HOME}/.rn-forge}"

rnfmac_bootstrap() {
  local force=0 archive="" version="" prefix brew_bin
  while [ $# -gt 0 ]; do
    case "$1" in
      --force) force=1 ;;
      --archive)
        [ $# -ge 2 ] || { _rnfmac_bootstrap_usage; return 1; }
        archive="$2"
        shift
        ;;
      --version)
        [ $# -ge 2 ] || { _rnfmac_bootstrap_usage; return 1; }
        version="$2"
        shift
        ;;
      *) _rnfmac_bootstrap_usage; return 1 ;;
    esac
    shift
  done
  if [ -n "$archive" ] && [ -z "$version" ]; then
    _rnfmac_bootstrap_usage
    return 1
  fi
  if [ -z "$archive" ] && [ -n "$version" ]; then
    _rnfmac_bootstrap_usage
    return 1
  fi
  if [ -n "$archive" ] && [ ! -f "$archive" ]; then
    printf 'bootstrap: archive not found: %s\n' "$archive" >&2
    return 1
  fi

  prefix="${HOMEBREW_PREFIX:-/opt/homebrew}"
  brew_bin="${prefix}/bin/brew"
  if [ -x "$brew_bin" ] && [ "$force" -eq 0 ]; then
    printf 'bootstrap: Homebrew is already installed\n' >&2
  else
    printf 'bootstrap: installing Homebrew\n' >&2
    if ! /bin/bash -c "$(curl -fsSL --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" ||
      [ ! -x "$brew_bin" ]; then
      printf 'bootstrap: installation failed\n' >&2
      return 1
    fi
  fi
  eval "$("$brew_bin" shellenv)"

  if ! command -v uv >/dev/null 2>&1; then
    printf 'bootstrap: installing uv\n' >&2
    if ! brew install uv; then
      printf 'bootstrap: installation failed\n' >&2
      return 1
    fi
  fi

  if [ -n "$archive" ]; then
    uvx --from "$archive" rnfmac self install --archive "$archive" --version "$version"
  else
    uvx --from git+https://github.com/rn-forge/macsetup rnfmac self install
  fi
  # shellcheck disable=SC2181
  if [ $? -ne 0 ]; then
    printf 'bootstrap: installation failed\n' >&2
    return 1
  fi

  export PATH="${RNF_HOME}/bin:${PATH}"
  printf 'bootstrap: next steps:\n' >&2
  printf 'bootstrap:   rnfmac system init\n' >&2
  printf 'bootstrap:   rnfmac sync\n' >&2
}

_rnfmac_bootstrap_usage() {
  printf 'bootstrap: usage: . bootstrap.sh [--force] [--archive <file> --version <version>]\n' >&2
}

rnfmac_bootstrap "$@"
__rnfmac_bootstrap_rc=$?
unset -f rnfmac_bootstrap _rnfmac_bootstrap_usage
if [ "$__rnfmac_bootstrap_rc" -eq 0 ]; then
  unset __rnfmac_bootstrap_rc
else
  unset __rnfmac_bootstrap_rc
  false
fi
