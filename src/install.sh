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
# shkit is still fetched via curl even in in-path mode; if that curl is
# blocked (e.g. a corporate proxy), set RNF_SHKIT_INSTALL_BUNDLE to the path of a
# shkit release tarball fetched out-of-band — it's extracted and its
# install.sh run locally instead of curling:
#     RNF_SHKIT_INSTALL_BUNDLE=./shkit.tar.gz . ./install.sh
# Installs into ~/.rn-forge/macsetup/<version>/ and links rnfmac — it does not touch
# .zprofile/.zshrc or run bootstrap/sync; those stay with `rnfmac system init` /
# `rnfmac sync`.
# Sourced contract: no `set -e`, no `exit` — a failure must never kill the caller's shell.
# Version: 3.0
# Author: Rohit Narayanan

RNF_HOME="${HOME}/.rn-forge"
RNF_GITHUB_ORG="${RNF_GITHUB_ORG:-rn-forge}"

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

# @description Install macsetup into `~/.rn-forge/macsetup/<version>/` and link
#   `rnfmac` + its completion script. Streaming mode (no sibling dist next to this
#   script) downloads and verifies the latest release tarball; in-path mode (an
#   unpacked dist or this repo's checkout sits alongside install.sh) installs
#   straight from that tree. No-ops if `current` already matches the target version.
#   Does not touch .zprofile/.zshrc or run bootstrap/sync — see next-step output.
# @noargs
# @exitcode 0 Installed (or already up to date).
# @exitcode 1 shkit failed to load, or an install step failed.
function rnfmac_install() {
  if [ "${_rnf_shkit_loaded}" -ne 0 ]; then
    echo "install.sh: failed to load shkit" >&2
    return 1
  fi

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

  if [ -n "${version_file}" ] && [ -f "${src_root}/rnfmac.sh" ]; then
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
      if [ "$(awk '{print $1}' "${tmp_tarball}.sha256")" != "$(_rnf_sha256_of "${tmp_tarball}")" ]; then
        log_error "checksum mismatch for ${github_repo} release tarball"
        return 1
      fi
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

  log_info ""
  log_info "macsetup ${tag} installed. next steps:"
  log_info "  export PATH=\"${rnf_home}/bin:\${PATH}\"   # add to ~/.zprofile to persist across shells"
  log_info "  rnfmac system init        # brand-new Mac: Homebrew, oh-my-zsh, uv, nvm, SDKMAN"
  log_info "  rnfmac sync               # render profile, patch .zprofile/.zshrc, sync packages + runtimes"
}

${__SOURCED__:+return} # shellspec Include guard

rnfmac_install
_rnfmac_install_status=$?
unset -f rnfmac_install _rnf_sha256_of _rnf_read_dist_version _rnf_acquire_install_lock _rnf_atomic_install
unset _rnf_shkit_loaded
if [ "${_rnfmac_install_status}" -eq 0 ]; then
  ## PATH for the current shell — the payoff of sourcing this script
  export PATH="${HOME}/.rn-forge/bin:${PATH}"
  unset _rnfmac_install_status
else
  echo "install.sh: installation failed" >&2
  unset _rnfmac_install_status
  false # sets the sourced/executed status without `exit`
fi
