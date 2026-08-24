#!/bin/zsh
# shellcheck shell=bash
# @file sync.sh
# @brief `rnfmac system sync` — installs pinned runtimes.
# @description
#   Installs the runtimes declared in macsetup-config: python via uv, node via
#   nvm, java via SDKMAN. Each runtime's version list is shared/<runtime>-versions
#   merged with the optional hosts/<host>/<runtime>-versions override in the config
#   checkout (one version per line, `#` comments) — the first entry across the
#   merged list is installed as that runtime's default. A version that can't be
#   resolved or installed is logged as an error and skipped rather than aborting
#   the whole sync; the script exits non-zero if any version, across any runtime,
#   failed.
# Version: 2.0
# Author: Rohit Narayanan

set -eo pipefail

## shkit — installed by install.sh; sourced from the local install, no network,
## no PATH assumption (that's the shell profile's job)
RNF_HOME="${HOME}/.rn-forge"
source "${RNF_HOME}/shkit/current/shkit.sh"
export RNF_LOG_LEVEL=${RNF_LOG_LEVEL_DEBUG}

## global variables
PRODUCT_HOME="${RNF_HOME}/macsetup"
CONFIG_HOME="${PRODUCT_HOME}/config"
HOST_NAME="$(hostname | tr '[:upper:]' '[:lower:]' | cut -d. -f1)"

# =============================================================================
# Helper functions
# =============================================================================

# @description Read and merge a runtime's version list: shared/<runtime>-versions
#   (required — at least one of shared or host must exist) plus the optional
#   hosts/<host>/<runtime>-versions override, comments/blank lines stripped,
#   deduped, order preserved (shared first, so shared entries win the "first =
#   default" position unless a host file lists its own first).
# @arg $1 string Runtime name (`java`, `python`, or `node`).
# @stdout One version spec per line.
# @exitcode 0 At least one version spec was found.
# @exitcode 1 Neither the shared nor the host file exists (or both are empty).
function read_runtime_versions() {
  local runtime="$1" shared_file host_file combined=""
  shared_file="${CONFIG_HOME}/shared/${runtime}-versions"
  host_file="${CONFIG_HOME}/hosts/${HOST_NAME}/${runtime}-versions"

  if [ -f "${shared_file}" ]; then
    combined="${combined}$(cat "${shared_file}")
"
  fi
  if [ -f "${host_file}" ]; then
    combined="${combined}$(cat "${host_file}")
"
  fi

  combined="$(printf '%s\n' "${combined}" | sed 's/#.*//' | awk '{gsub(/^[ \t]+|[ \t]+$/, "")} NF && !seen[$0]++')"

  if [ -z "${combined}" ]; then
    log_error "no ${runtime} versions configured — add shared/${runtime}-versions or hosts/${HOST_NAME}/${runtime}-versions to macsetup-config"
    return 1
  fi
  printf '%s\n' "${combined}"
}

# =============================================================================
# Main functions — one per runtime, run in order by sync_runtimes()
# =============================================================================

# @description Install every configured python version via uv; the first
#   successfully installed version becomes the default.
# @noargs
# @exitcode 0 All configured versions installed.
# @exitcode 1 No version list was configured, or at least one version failed.
function sync_python() {
  log_verbose "Syncing python runtimes ..."
  export PATH="${HOME}/.local/bin:${PATH}"

  local versions spec failed=0
  local -a installed
  versions="$(read_runtime_versions "python")" || return 1

  while IFS= read -r spec; do
    log_verbose "Installing python ${spec} ..."
    if uv python install "${spec}"; then
      installed+=("${spec}")
    else
      log_error "python ${spec} not available — skipping"
      failed=1
    fi
  done <<<"${versions}"

  if [ "${#installed[@]}" -eq 0 ]; then
    log_error "no python versions were installed"
    return 1
  fi

  uv python install "${installed[1]}" --default
  log_success "python runtimes synced (default: ${installed[1]}, $(python --version 2>&1))"
  return "${failed}"
}

# @description Install every configured node version via nvm; the first
#   successfully installed version becomes the default alias. A bare `lts` spec
#   resolves via `nvm install --lts`; anything else (an exact version, or an
#   `lts/<codename>`) is passed to `nvm install` directly.
# @noargs
# @exitcode 0 All configured versions installed.
# @exitcode 1 No version list was configured, or at least one version failed.
function sync_node() {
  log_verbose "Syncing node runtimes ..."
  export NVM_DIR="${HOME}/.nvm"
  source "${NVM_DIR}/nvm.sh"

  local versions spec failed=0
  local -a installed
  versions="$(read_runtime_versions "node")" || return 1

  while IFS= read -r spec; do
    log_verbose "Installing node ${spec} ..."
    if [ "${spec}" = "lts" ]; then
      if ! nvm install --lts; then
        log_error "node lts not available — skipping"
        failed=1
        continue
      fi
    elif ! nvm install "${spec}"; then
      log_error "node ${spec} not available — skipping"
      failed=1
      continue
    fi
    installed+=("$(nvm current)")
  done <<<"${versions}"

  if [ "${#installed[@]}" -eq 0 ]; then
    log_error "no node versions were installed"
    return 1
  fi

  nvm alias default "${installed[1]}"
  log_success "node runtimes synced (default: ${installed[1]}, $(node --version))"
  return "${failed}"
}

# @description Resolve a java version spec to a concrete Temurin identifier
#   against `sdk list java`'s output. A spec already ending `-tem` is trusted
#   as-is (an exact identifier); otherwise it's matched as a major-version prefix
#   against the Identifier column — always the last `|`-delimited field, and the
#   one column reliably tagged `-tem` for Temurin regardless of how the Vendor
#   column is spelled (it print full names like "Temurin", not an abbreviation —
#   matching on Vendor directly is what silently broke this sync previously: the
#   filter matched nothing, the resolved version was empty, and `sdk install java
#   ""` fell back to installing whatever SDKMAN's own default happened to be).
# @arg $1 string Version spec — a major version (`21`) or an exact identifier.
# @arg $2 string The `sdk list java` output to search.
# @stdout The resolved identifier, or nothing if no match was found.
function resolve_temurin_identifier() {
  local spec="$1" available="$2"
  if [[ "${spec}" == *-tem ]]; then
    echo "${spec}"
    return 0
  fi
  echo "${available}" | awk -F'|' -v ver="${spec}" '
    { id = $NF; gsub(/^[ \t]+|[ \t]+$/, "", id) }
    id ~ ("^" ver "([.+]|-tem$)") && id ~ /-tem$/ { print id; exit }
  '
}

# @description Install every configured java version via SDKMAN; the first
#   successfully installed version becomes the SDKMAN default.
# @noargs
# @exitcode 0 All configured versions resolved and installed.
# @exitcode 1 No version list was configured, a version had no matching Temurin
#   build, or a resolved version failed to install.
function sync_java() {
  log_verbose "Syncing java runtimes ..."
  set +eu
  export SDKMAN_DIR="${HOME}/.sdkman"
  source "${SDKMAN_DIR}/bin/sdkman-init.sh"
  set -eo pipefail

  local versions spec identifier available_java_versions failed=0
  local -a installed
  versions="$(read_runtime_versions "java")" || return 1

  log_info "Searching for java versions ..."
  # shellcheck disable=SC2209
  available_java_versions=$(PAGER=cat sdk list java)

  while IFS= read -r spec; do
    identifier="$(resolve_temurin_identifier "${spec}" "${available_java_versions}")"
    if [ -z "${identifier}" ]; then
      log_error "no Temurin build found for java '${spec}' — skipping"
      failed=1
      continue
    fi
    log_verbose "Installing java ${identifier} ..."
    if sdk install java "${identifier}"; then
      installed+=("${identifier}")
    else
      log_error "failed to install java ${identifier} — skipping"
      failed=1
    fi
  done <<<"${versions}"

  if [ "${#installed[@]}" -eq 0 ]; then
    log_error "no java versions were installed"
    return 1
  fi

  sdk default java "${installed[1]}"
  log_success "java runtimes synced (default: ${installed[1]})"
  return "${failed}"
}

# @description Run `rnfmac system sync`: install every configured python, node,
#   and java version. Each runtime is attempted even if an earlier one failed, so
#   one bad version spec never blocks the others.
# @noargs
# @exitcode 0 Every runtime synced cleanly.
# @exitcode 1 At least one runtime had a failed or unconfigured version.
function sync_runtimes() {
  local failed=0
  sync_python || failed=1
  sync_node || failed=1
  sync_java || failed=1
  return "${failed}"
}

${__SOURCED__:+return} # shellspec Include guard

sync_runtimes
log_success "System sync complete !"
