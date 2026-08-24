#!/bin/zsh
# shellcheck shell=bash
# @file upgrade.sh
# @brief `rnfmac upgrade` — installs the latest release and updates configuration.
# @description
#   Downloads and installs the latest macsetup release, then updates the persistent
#   macsetup-config checkout without applying profile, brew, or system sync.
#   `--archive <path>` installs a release tarball already on disk instead of
#   downloading one — the offline/air-gapped route, and the way to move to a
#   specific build rather than whatever "latest" currently points at.
# Version: 3.0
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
ARCHIVE=""

# @description Print `rnfmac upgrade` usage.
# @noargs
# @stdout The usage text.
function usage() {
  echo "usage: rnfmac upgrade [--archive <path>]"
}

# @description Parse CLI args, setting `ARCHIVE` and handling `-h`/`--help`.
# @arg $@ string Command arguments.
# @set ARCHIVE Path to a release tarball to install instead of downloading one.
# @exitcode 1 Unrecognized or incomplete arguments.
function parse_args() {
  local arg
  while [[ $# -gt 0 ]]; do
    arg="$1"
    case "${arg}" in
    --archive)
      if [[ -z "${2:-}" ]]; then
        usage >&2
        exit 1
      fi
      ARCHIVE="$2"
      shift 2
      ;;
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

# @description Print the sha256 of a file — sha256sum on Linux, shasum on macOS.
# @arg $1 string Path to the file to hash.
# @stdout The hex-encoded sha256 digest.
function sha256_of() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${file}" | awk '{print $1}'
  else
    shasum -a 256 "${file}" | awk '{print $1}'
  fi
}

# @description Compare a file against a sha256 sidecar.
# @arg $1 string Path to the file to verify.
# @arg $2 string Path to the sidecar holding the expected digest.
# @exitcode 0 The digests match.
# @exitcode 1 The digests differ.
function verify_checksum() {
  local file="$1" sidecar="$2"
  if [[ "$(awk '{print $1}' "${sidecar}")" != "$(sha256_of "${file}")" ]]; then
    log_error "checksum mismatch for ${file}"
    return 1
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
    if [[ "${waited}" -eq 0 ]]; then
      log_info "waiting for install lock ${lock_dir} (held by another install) ..."
    fi
    if [[ "${waited}" -ge 30 ]]; then
      log_error "could not acquire install lock ${lock_dir}"
      return 1
    fi
    sleep 1
    waited=$((waited + 1))
  done
  trap 'rm -rf "${lock_dir}"' EXIT
}

# @description Download the latest release tarball into `$1` and verify it against
#   its published sidecar.
# @arg $1 string Destination path for the downloaded tarball.
# @exitcode 1 The download failed or the checksum did not match.
function fetch_release_tarball() {
  local tarball="$1"

  ## unversioned asset name — the "latest" alias resolves to whichever release
  ## tag currently owns it, so no api.github.com call is needed up front; the
  ## tag is read from VERSION inside the downloaded tarball instead
  log_info "Downloading latest release of ${GITHUB_REPO} ..."
  curl -fsSL --proto '=https' --tlsv1.2 -o "${tarball}" "https://github.com/${GITHUB_REPO}/releases/latest/download/macsetup.tar.gz"

  if curl -fsSL --proto '=https' --tlsv1.2 -o "${tarball}.sha256" "https://github.com/${GITHUB_REPO}/releases/latest/download/macsetup.tar.gz.sha256" 2>/dev/null; then
    verify_checksum "${tarball}" "${tarball}.sha256" || return 1
  else
    log_warning "no checksum found for ${GITHUB_REPO} release tarball, skipping verification"
  fi
}

# @description Stage the `--archive` tarball into `$1`, verifying it against a
#   sibling `.sha256` sidecar when one exists.
# @arg $1 string Destination path for the staged tarball.
# @exitcode 1 The archive is missing, or its checksum did not match.
function stage_local_archive() {
  local tarball="$1"

  if [[ ! -f "${ARCHIVE}" ]]; then
    log_error "archive not found: ${ARCHIVE}"
    return 1
  fi

  log_info "Installing from local archive ${ARCHIVE} ..."
  ## a sidecar beside the archive is honoured exactly as the release one is; an
  ## archive moved by hand is the case most likely to have been truncated
  if [[ -f "${ARCHIVE}.sha256" ]]; then
    verify_checksum "${ARCHIVE}" "${ARCHIVE}.sha256" || return 1
  else
    log_warning "no ${ARCHIVE}.sha256 sidecar found, skipping verification"
  fi
  cp "${ARCHIVE}" "${tarball}"
}

# @description Run `rnfmac upgrade`: stage the release tarball (downloaded, or the
#   `--archive` one), install it as a new version dir (no-op if already current),
#   flip `current`, and update macsetup-config without applying it.
# @noargs
function execute() {
  local tmp_dir tmp_tarball extract_dir version tag current_version dist_path

  tmp_dir="$(mktemp -d)"
  tmp_tarball="${tmp_dir}/macsetup.tar.gz"

  if [[ -n "${ARCHIVE}" ]]; then
    stage_local_archive "${tmp_tarball}" || exit 1
  else
    fetch_release_tarball "${tmp_tarball}" || exit 1
  fi

  extract_dir="${tmp_dir}/extracted"
  mkdir -p "${extract_dir}"
  tar -xzf "${tmp_tarball}" -C "${extract_dir}"
  rm -f "${tmp_tarball}" "${tmp_tarball}.sha256"

  version="$(read_dist_version "${extract_dir}/VERSION")" || exit 1
  tag="v${version}"

  current_version=""
  if [[ -f "${PRODUCT_HOME}/current/VERSION" ]]; then
    current_version="v$(cat "${PRODUCT_HOME}/current/VERSION")"
  fi
  if [[ "${tag}" = "${current_version}" ]]; then
    log_success "already on ${current_version}"
    rm -rf "${tmp_dir}"
  else
    ## an --archive tarball can legitimately be older than what is installed, so
    ## this is worded as a move rather than an upgrade
    log_notice "Installing ${tag} (current: ${current_version:-<none>}) ..."
    dist_path="${PRODUCT_HOME}/${tag}"
    mkdir -p "${PRODUCT_HOME}"
    acquire_install_lock "${PRODUCT_HOME}/.install.lock"
    atomic_install "${extract_dir}" "${dist_path}"
    ln -sfn "${tag}" "${PRODUCT_HOME}/current"
    rm -rf "${PRODUCT_HOME}/.install.lock" "${tmp_dir}"
    trap - EXIT
    log_success "unpacked and installed ${tag}"
  fi

  "${PRODUCT_HOME}/current/commands/config/pull.sh"
  log_notice "configuration updated but not applied — run 'rnfmac sync' to apply it"
}

${__SOURCED__:+return} # shellspec Include guard

parse_args "$@"
print_vars "RNF_HOME" "GITHUB_REPO" "PRODUCT_HOME"
execute
