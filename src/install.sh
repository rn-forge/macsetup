#!/bin/zsh
# shellcheck shell=bash
# @file install.sh
# @brief Standalone macsetup installer, published as a release asset.
# @description
#   Standalone macsetup installer — published as a release asset. Two ways to run it:
#   Streaming (fresh machine, no local checkout) — safe to source, downloads the
#   latest release:
#     . <(curl -fsSL https://github.com/rn-forge/macsetup/releases/latest/download/install.sh)
#   In-path (an unpacked release dist, or this repo's src/, sits next to this file)
#   — installs straight from that tree, no network round-trip for macsetup itself
#   (shkit below is still fetched fresh either way):
#     . src/install.sh
#   Archive (a release tarball already on disk) — unpacks and installs it, no
#   download; takes precedence over in-path detection:
#     . ./install.sh --archive ~/Downloads/macsetup.tar.gz
# shkit is still fetched via curl even in in-path mode; if that curl is
# blocked (e.g. a corporate proxy), set RNF_SHKIT_INSTALL_BUNDLE to the path of a
# shkit release tarball fetched out-of-band — it's extracted and its
# install.sh run locally instead of curling:
#     RNF_SHKIT_INSTALL_BUNDLE=./shkit.tar.gz . ./install.sh
# Installs into ~/.rn-forge/macsetup/<version>/, clones macsetup-config into the
# persistent product home, and links rnfmac. It does not touch .zprofile/.zshrc or
# run bootstrap/sync; those stay with `rnfmac system init` / `rnfmac sync`.
# Sourced contract: no `set -e`, no `exit` — a failure must never kill the caller's shell.
# Version: 3.0
# Author: Rohit Narayanan

RNF_HOME="${HOME}/.rn-forge"
RNF_GITHUB_ORG="${RNF_GITHUB_ORG:-rn-forge}"
RNFMAC_CONFIG_REPO_URL="${RNFMAC_CONFIG_REPO_URL:-https://github.com/${RNF_GITHUB_ORG}/macsetup-config.git}"

## Sourced at file top level, not inside a function: under zsh, $0 (and readonly
## constants) sourced from inside a function become function-local/scoped to the
## function and vanish on return — SELF_PATH needs the real path of this file.
SELF_PATH="$(readlink -f "$0" 2>/dev/null || echo "$0")"

## shkit — install.sh is the only place that installs it (shkit's own
## install.sh handles the version checks and versioned install layout); every other
## script assumes it's already present and just sources it locally, no network.
## RNF_SHKIT_INSTALL_BUNDLE lets a blocked network (e.g. behind a corporate proxy)
## point at a shkit release tarball fetched out-of-band instead of curling it —
## shkit's own install.sh would otherwise try (and fail) to curl the same tarball.
if [ -n "${RNF_SHKIT_INSTALL_BUNDLE:-}" ]; then
  _rnf_shkit_bundle_dir="$(mktemp -d)"
  if tar -xzf "${RNF_SHKIT_INSTALL_BUNDLE}" -C "${_rnf_shkit_bundle_dir}"; then
    bash "${_rnf_shkit_bundle_dir}/install.sh"
  else
    echo "install.sh: failed to extract RNF_SHKIT_INSTALL_BUNDLE=${RNF_SHKIT_INSTALL_BUNDLE}" >&2
  fi
  rm -rf "${_rnf_shkit_bundle_dir}"
  unset _rnf_shkit_bundle_dir
else
  curl -fsSL "https://github.com/${RNF_GITHUB_ORG}/shkit/releases/latest/download/install.sh" | bash
fi
_rnf_shkit_loaded=1
if [ -f "${RNF_HOME}/shkit/current/shkit.sh" ]; then
  source "${RNF_HOME}/shkit/current/shkit.sh"
  _rnf_shkit_loaded=$?
fi

# @description Print the sha256 of a file — sha256sum on Linux, shasum on macOS.
# @arg $1 string Path to the file to hash.
# @stdout The hex-encoded sha256 digest.
function _rnf_sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# @description Compare a file against a sha256 sidecar.
# @arg $1 string Path to the file to verify.
# @arg $2 string Path to the sidecar holding the expected digest.
# @exitcode 0 The digests match.
# @exitcode 1 The digests differ.
function _rnf_verify_checksum() {
  if [ "$(awk '{print $1}' "$2")" != "$(_rnf_sha256_of "$1")" ]; then
    log_error "checksum mismatch for $1"
    return 1
  fi
}

# @description Validate and print the version in a VERSION file — guards against a
#   truncated download or corrupt file silently producing a bogus install path.
# @arg $1 string Path to the VERSION file.
# @stdout The validated version string.
# @exitcode 0 VERSION matches `X.Y.Z` (with optional `-`/`+` suffix).
# @exitcode 1 VERSION is missing or malformed.
function _rnf_read_dist_version() {
  local version_file="$1" version
  version="$(cat "${version_file}" 2>/dev/null)"
  if ! printf '%s\n' "${version}" | grep -Eq '^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*([-+][A-Za-z0-9][A-Za-z0-9._-]*)?$'; then
    log_error "invalid or missing VERSION in ${version_file}"
    return 1
  fi
  printf '%s\n' "${version}"
}

# @description Serialize concurrent installs (e.g. two terminals bootstrapping at
#   once) via a mkdir-based lock — portable across macOS/Linux, unlike flock. Fails
#   after a bounded wait rather than deleting an unknown lock and racing an active
#   install. No trap here to auto-release it: this file is sourced into the caller's
#   shell, and a trap set here would attach to that shell, not just this function.
# @arg $1 string Lock directory path to create.
# @exitcode 0 Lock acquired.
# @exitcode 1 Timed out after 30s waiting for the lock.
function _rnf_acquire_install_lock() {
  local lock_dir="$1" waited=0
  while ! mkdir "${lock_dir}" 2>/dev/null; do
    if [ "${waited}" -eq 0 ]; then
      log_info "waiting for install lock ${lock_dir} (held by another install) ..."
    fi
    if [ "${waited}" -ge 30 ]; then
      log_error "could not acquire install lock ${lock_dir}"
      return 1
    fi
    sleep 1
    waited=$((waited + 1))
  done
}

# @description Copy a staged dist tree into place atomically: builds in a scratch
#   dir next to the destination first, then rm+mv swaps it into place — a failed
#   copy only ever corrupts the scratch dir, never leaves a partially-overwritten
#   install.
# @arg $1 string Source dir (a staged dist tree).
# @arg $2 string Destination dist path.
# @exitcode 0 Install swapped into place successfully.
# @exitcode 1 A step failed; destination is left untouched or removed, never partial.
function _rnf_atomic_install() {
  local src="$1" dist_path="$2" tmp_dist="$2.tmp.$$"
  rm -rf "${tmp_dist}" || return 1
  mkdir -p "${tmp_dist}" || return 1
  cp -R "${src}/." "${tmp_dist}/" || {
    rm -rf "${tmp_dist}"
    return 1
  }
  rm -rf "${dist_path}" || return 1
  mv "${tmp_dist}" "${dist_path}" || return 1
}

# @description Clone the persistent macsetup-config checkout on first install, or
#   fast-forward an existing checkout, carrying any uncommitted local changes across
#   on a stash. The checkout lives beside versioned application directories so future
#   upgrades never replace it.
# @arg $1 string Product home directory.
# @exitcode 0 Configuration checkout is current.
# @exitcode 1 Git is unavailable, or clone/pull validation failed.
function _rnf_install_config_checkout() {
  local config_home="${1}/config"
  if ! command -v git >/dev/null 2>&1; then
    log_error "git is required to install macsetup configuration"
    return 1
  fi

  if [ ! -e "${config_home}" ]; then
    log_info "cloning macsetup config from ${RNFMAC_CONFIG_REPO_URL} ..."
    git clone --quiet --branch main --single-branch "${RNFMAC_CONFIG_REPO_URL}" "${config_home}" || return 1
  else
    if ! git -C "${config_home}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      log_error "existing config path is not a git checkout: ${config_home}"
      return 1
    fi
    ## uncommitted config edits are the normal state of a working checkout — hold
    ## them aside for the fast-forward rather than making an install refuse to run
    local stashed=0
    if [ -n "$(git -C "${config_home}" status --porcelain)" ]; then
      log_info "holding local config changes aside while updating ..."
      git -C "${config_home}" stash push --quiet --include-untracked --message "rnfmac install" || return 1
      stashed=1
    fi
    if ! git -C "${config_home}" pull --quiet --ff-only origin main; then
      if [ "${stashed}" -eq 1 ]; then
        git -C "${config_home}" stash pop --quiet
      fi
      return 1
    fi
    if [ "${stashed}" -eq 1 ] && ! git -C "${config_home}" stash pop --quiet; then
      log_error "local config changes conflict with origin/main — resolve the conflicts in ${config_home}"
      return 1
    fi
  fi
  log_success "macsetup config is current ($(git -C "${config_home}" rev-parse --short HEAD))"
}

# @description Parse installer arguments, setting `_RNF_ARCHIVE` from
#   `--archive <path>`. Returns rather than exits: this file is sourced, so a bad
#   argument must never kill the caller's shell.
# @arg $@ string Installer arguments.
# @set _RNF_ARCHIVE Path to a release tarball to install from.
# @exitcode 0 Parsed successfully.
# @exitcode 1 Unrecognized or incomplete arguments.
function _rnf_parse_install_args() {
  _RNF_ARCHIVE=""
  while [ $# -gt 0 ]; do
    case "$1" in
    --archive)
      if [ -z "${2:-}" ]; then
        log_error "usage: . install.sh [--archive <path>]"
        return 1
      fi
      _RNF_ARCHIVE="$2"
      shift 2
      ;;
    *)
      log_error "usage: . install.sh [--archive <path>]"
      return 1
      ;;
    esac
  done
}

# @description Install macsetup into `~/.rn-forge/macsetup/<version>/`, install or
#   update macsetup-config, and link `rnfmac` + its completion script. Three modes:
#   `--archive <path>` unpacks a release tarball already on disk; in-path mode (an
#   unpacked dist or this repo's checkout sits alongside install.sh) installs
#   straight from that tree; streaming mode (neither of those) downloads and
#   verifies the latest release tarball. No-ops if `current` already matches the
#   target version. Does not touch .zprofile/.zshrc or run bootstrap/sync — see
#   next-step output.
# @arg $@ string Installer arguments — optionally `--archive <path>`.
# @exitcode 0 Installed (or already up to date).
# @exitcode 1 shkit failed to load, bad arguments, or an install step failed.
function rnfmac_install() {
  if [ "${_rnf_shkit_loaded}" -ne 0 ]; then
    echo "install.sh: failed to load shkit" >&2
    return 1
  fi

  _rnf_parse_install_args "$@" || return 1

  local github_repo="${RNF_GITHUB_ORG}/macsetup"
  local rnf_home="${RNF_HOME}"
  local product_home="${rnf_home}/macsetup"
  local src_root version_file extract_dir tmp_dir version tag dist_path

  ## In-path install: an unpacked release dist has VERSION directly alongside this
  ## script; a git checkout has it one level up (src/install.sh, VERSION at repo root).
  src_root="$(dirname "${SELF_PATH}")"
  if [ -f "${src_root}/VERSION" ]; then
    version_file="${src_root}/VERSION"
  elif [ -f "$(dirname "${src_root}")/VERSION" ]; then
    version_file="$(dirname "${src_root}")/VERSION"
  fi

  if [ -n "${_RNF_ARCHIVE}" ]; then
    ## Archive install: an explicit tarball wins over whatever sits next to this
    ## script — the caller named the payload, so detection must not second-guess it.
    if [ ! -f "${_RNF_ARCHIVE}" ]; then
      log_error "archive not found: ${_RNF_ARCHIVE}"
      return 1
    fi

    log_info "installing macsetup from ${_RNF_ARCHIVE} ..."
    tmp_dir="$(mktemp -d)" || return 1
    ## a sidecar beside the archive is honoured exactly as the release one is; an
    ## archive moved by hand is the case most likely to have been truncated
    if [ -f "${_RNF_ARCHIVE}.sha256" ]; then
      _rnf_verify_checksum "${_RNF_ARCHIVE}" "${_RNF_ARCHIVE}.sha256" || {
        rm -rf "${tmp_dir}"
        return 1
      }
    else
      log_warning "no ${_RNF_ARCHIVE}.sha256 sidecar found, skipping verification"
    fi

    extract_dir="${tmp_dir}/extracted"
    mkdir -p "${extract_dir}" || return 1
    tar -xzf "${_RNF_ARCHIVE}" -C "${extract_dir}" || {
      log_error "could not extract ${_RNF_ARCHIVE}"
      rm -rf "${tmp_dir}"
      return 1
    }
    version_file="${extract_dir}/VERSION"
  elif [ -n "${version_file}" ] && [ -f "${src_root}/rnfmac.sh" ]; then
    extract_dir="${src_root}"
  else
    ## Streaming install: curled with no sibling dist — download the unversioned
    ## latest release tarball (verified against its .sha256 sidecar, when present)
    ## and extract it.
    tmp_dir="$(mktemp -d)" || return 1
    local tmp_tarball="${tmp_dir}/macsetup.tar.gz"

    log_info "downloading latest release of ${github_repo} ..."
    curl -fsSL -o "${tmp_tarball}" "https://github.com/${github_repo}/releases/latest/download/macsetup.tar.gz" || return 1

    if curl -fsSL -o "${tmp_tarball}.sha256" "https://github.com/${github_repo}/releases/latest/download/macsetup.tar.gz.sha256" 2>/dev/null; then
      _rnf_verify_checksum "${tmp_tarball}" "${tmp_tarball}.sha256" || return 1
    else
      log_warning "no checksum found for ${github_repo} release tarball, skipping verification"
    fi

    extract_dir="${tmp_dir}/extracted"
    mkdir -p "${extract_dir}" || return 1
    tar -xzf "${tmp_tarball}" -C "${extract_dir}" || return 1
    rm -f "${tmp_tarball}" "${tmp_tarball}.sha256"
    version_file="${extract_dir}/VERSION"
  fi

  version="$(_rnf_read_dist_version "${version_file}")" || return 1
  tag="v${version}"
  dist_path="${product_home}/${tag}"

  if [ -f "${product_home}/current/VERSION" ] && [ "$(cat "${product_home}/current/VERSION")" = "${version}" ]; then
    log_success "already on the latest release (${tag})"
  else
    log_notice "installing macsetup ${tag} ..."
    mkdir -p "${rnf_home}/bin" "${rnf_home}/completions" "${product_home}" || return 1

    local lock_dir="${product_home}/.install.lock"
    _rnf_acquire_install_lock "${lock_dir}" || return 1

    ## canonicalize before comparing — extract_dir is fully resolved, dist_path may not be
    local install_rc=0
    if [ "$(readlink -f "${extract_dir}" 2>/dev/null)" != "$(readlink -f "${dist_path}" 2>/dev/null)" ]; then
      _rnf_atomic_install "${extract_dir}" "${dist_path}"
      install_rc=$?
      ## only needed here: a checkout's VERSION lives outside extract_dir (one
      ## level up), so the atomic copy above didn't already bring it along —
      ## skipped on the re-run-in-place path above, where src == dist_path/VERSION
      ## already and `cp -f` onto itself would error
      [ "${install_rc}" -eq 0 ] && { cp -f "${version_file}" "${dist_path}/VERSION" || install_rc=1; }
    fi
    rm -rf "${lock_dir}"
    [ "${install_rc}" -eq 0 ] || return 1

    ln -sfn "${tag}" "${product_home}/current" || return 1
    ln -sfn "../macsetup/current/rnfmac.sh" "${rnf_home}/bin/rnfmac" || return 1
    ln -sfn "../macsetup/current/completions/_rnfmac" "${rnf_home}/completions/_rnfmac" || return 1
    log_success "distribution installed (current -> ${tag})"
  fi
  [ -n "${tmp_dir}" ] && rm -rf "${tmp_dir}"

  _rnf_install_config_checkout "${product_home}" || return 1

  log_info ""
  log_info "macsetup ${tag} installed. next steps:"
  log_info "  export PATH=\"${rnf_home}/bin:\${PATH}\"   # add to ~/.zprofile to persist across shells"
  log_info "  rnfmac system init        # brand-new Mac: Homebrew, oh-my-zsh, uv, nvm, SDKMAN"
  log_info "  rnfmac sync               # render profile, patch .zprofile/.zshrc, sync packages + runtimes"
}

${__SOURCED__:+return} # shellspec Include guard

rnfmac_install "$@"
_rnfmac_install_status=$?
unset -f rnfmac_install _rnf_parse_install_args _rnf_sha256_of _rnf_verify_checksum _rnf_read_dist_version _rnf_acquire_install_lock _rnf_atomic_install _rnf_install_config_checkout
unset _rnf_shkit_loaded _RNF_ARCHIVE
if [ "${_rnfmac_install_status}" -eq 0 ]; then
  ## PATH for the current shell — the payoff of sourcing this script
  export PATH="${HOME}/.rn-forge/bin:${PATH}"
  unset _rnfmac_install_status
else
  echo "install.sh: installation failed" >&2
  unset _rnfmac_install_status
  false # sets the sourced/executed status without `exit`
fi
