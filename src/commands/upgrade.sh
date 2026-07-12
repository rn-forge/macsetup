#!/bin/zsh
# shellcheck shell=bash
# @file upgrade.sh
# @brief `rnfmac upgrade` — downloads the latest macsetup release and installs it.
# @description
#   Script to download the latest macsetup release and install it
# Version: 2.0
# Author: Rohit Narayanan

set -eo pipefail

## shkit — installed by install.sh; sourced from the local install, no network,
## no PATH assumption (that's the shell profile's job)
RNF_HOME="${HOME}/.rn-forge"
source "${RNF_HOME}/shkit/current/shkit.sh"
export RNF_LOG_LEVEL=${RNF_LOG_LEVEL_DEBUG}

## global variables
GITHUB_REPO="${RNF_GITHUB_ORG:-rn-forge}/macsetup"
PRODUCT_HOME="${RNF_HOME}/macsetup"

# @description Print the sha256 of a file — sha256sum on Linux, shasum on macOS.
# @arg $1 string Path to the file to hash.
# @stdout The hex-encoded sha256 digest.
function sha256_of() {
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
function read_dist_version() {
  local version_file="$1" version
  version="$(cat "${version_file}" 2>/dev/null)"
  if ! printf '%s\n' "${version}" | grep -Eq '^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*([-+][A-Za-z0-9][A-Za-z0-9._-]*)?$'; then
    log_error "invalid or missing VERSION in ${version_file}"
    return 1
  fi
  printf '%s\n' "${version}"
}

# @description Copy a staged dist tree into place atomically: builds in a scratch
#   dir next to the destination first, then rm+mv swaps it into place — a failed
#   copy only ever corrupts the scratch dir, never leaves a partially-overwritten
#   install.
# @arg $1 string Source dir (a staged dist tree).
# @arg $2 string Destination dist path.
function atomic_install() {
  local src="$1" dist_path="$2" tmp_dist="$2.tmp.$$"
  rm -rf "${tmp_dist}"
  mkdir -p "${tmp_dist}"
  cp -R "${src}/." "${tmp_dist}/"
  rm -rf "${dist_path}"
  mv "${tmp_dist}" "${dist_path}"
}

# @description Serialize concurrent upgrades via a mkdir-based lock — portable
#   across macOS/Linux, unlike flock. Released by a trap: this script always runs
#   standalone (never sourced into a caller's shell), so a trap here is safe.
# @arg $1 string Lock directory path to create.
# @exitcode 0 Lock acquired (an EXIT trap releasing it is now set).
# @exitcode 1 Timed out after 30s waiting for the lock.
function acquire_install_lock() {
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
  trap 'rm -rf "${lock_dir}"' EXIT
}

# @description Run `rnfmac upgrade`: download and verify the latest release
#   tarball, install it as a new version dir (no-op if already current), flip
#   `current`, then exec the new dist's sync.sh to re-sync profile/brew/system.
# @arg $@ string Forwarded to the new dist's `commands/sync.sh` on completion.
function execute() {
  local tmp_dir tmp_tarball extract_dir version tag current_version dist_path

  tmp_dir="$(mktemp -d)"
  tmp_tarball="${tmp_dir}/macsetup.tar.gz"

  ## unversioned asset name — the "latest" alias resolves to whichever release
  ## tag currently owns it, so no api.github.com call is needed up front; the
  ## tag is read from VERSION inside the downloaded tarball instead
  log_info "Downloading latest release of ${GITHUB_REPO} ..."
  curl -fsSL -o "${tmp_tarball}" "https://github.com/${GITHUB_REPO}/releases/latest/download/macsetup.tar.gz"

  if curl -fsSL -o "${tmp_tarball}.sha256" "https://github.com/${GITHUB_REPO}/releases/latest/download/macsetup.tar.gz.sha256" 2>/dev/null; then
    if [ "$(awk '{print $1}' "${tmp_tarball}.sha256")" != "$(sha256_of "${tmp_tarball}")" ]; then
      log_error "checksum mismatch for ${GITHUB_REPO} release tarball"
      exit 1
    fi
  else
    log_warning "no checksum found for ${GITHUB_REPO} release tarball, skipping verification"
  fi

  extract_dir="${tmp_dir}/extracted"
  mkdir -p "${extract_dir}"
  tar -xzf "${tmp_tarball}" -C "${extract_dir}"
  rm -f "${tmp_tarball}" "${tmp_tarball}.sha256"

  version="$(read_dist_version "${extract_dir}/VERSION")" || exit 1
  tag="v${version}"

  current_version=""
  if [ -f "${PRODUCT_HOME}/current/VERSION" ]; then
    current_version="v$(cat "${PRODUCT_HOME}/current/VERSION")"
  fi
  if [ "${tag}" = "${current_version}" ]; then
    log_success "already on the latest release (${current_version})"
    rm -rf "${tmp_dir}"
    return
  fi

  log_notice "Upgrading ${current_version:-<none>} -> ${tag} ..."
  dist_path="${PRODUCT_HOME}/${tag}"
  mkdir -p "${PRODUCT_HOME}"
  acquire_install_lock "${PRODUCT_HOME}/.install.lock"
  atomic_install "${extract_dir}" "${dist_path}"
  ln -sfn "${tag}" "${PRODUCT_HOME}/current"
  rm -rf "${PRODUCT_HOME}/.install.lock" "${tmp_dir}"
  trap - EXIT
  log_success "downloaded and unpacked ${tag}"

  ## flips `current` to the new dist and re-syncs profile/brew/system
  exec "${dist_path}/commands/sync.sh"
}

${__SOURCED__:+return} # shellspec Include guard

print_vars "RNF_HOME" "GITHUB_REPO" "PRODUCT_HOME"
execute "$@"
