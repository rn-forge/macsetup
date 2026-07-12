#!/bin/zsh
# shellcheck shell=bash
# @file relay.sh
# @brief `rnfmac brew relay` — (re)applies the Homebrew Remote Relay patches.
# @description
#   (Re)apply the Homebrew Remote Relay patches — patches are the single source of
#   truth. All git operations run against the local Homebrew install at
#   HOMEBREW_PREFIX (/opt/homebrew — the relay only supports Apple Silicon Macs).
#   Every apply resets Homebrew to its clean base and re-applies the payload
#   patches fresh, rather than cherry-picking a stored commit.
# Version: 3.0
# Author: Rohit Narayanan

set -eo pipefail

## shkit — installed by install.sh; sourced from the local install, no network,
## no PATH assumption (that's the shell profile's job)
RNF_HOME="${HOME}/.rn-forge"
source "${RNF_HOME}/shkit/current/shkit.sh"
export RNF_LOG_LEVEL=${RNF_LOG_LEVEL_DEBUG}

SELF_PATH="$(readlink -f "$0")"
SRC_ROOT="$(dirname "$(dirname "$(dirname "${SELF_PATH}")")")" # unpacked dist root, or src/ in a git checkout

## RNFMAC_TEST_HOMEBREW_PREFIX is a shellspec-only test seam (mirrors the RNFMAC_SYNC_PROFILES_ONLY
## / RNF_TEST_* pattern used elsewhere) — production always operates on the real /opt/homebrew.
HOMEBREW_PREFIX="${RNFMAC_TEST_HOMEBREW_PREFIX:-/opt/homebrew}"

PAYLOAD_PATH="${SRC_ROOT}/homebrew"
PATCH_PATH="${PAYLOAD_PATH}/patches"

MANAGED_HOMEBREW_FILES=(
  "Library/Homebrew/download_strategy.rb"
  "Library/Homebrew/download_strategy/download_strategy_detector.rb"
  "Library/Homebrew/cmd/vendor-install.sh"
)

PATCH_FILES=(
  "${PATCH_PATH}/download_strategy.rb.patch"
  "${PATCH_PATH}/download_strategy_detector.rb.patch"
  "${PATCH_PATH}/vendor-install.sh.patch"
)

REMOTE_RELAY_STRATEGY="Library/Homebrew/download_strategy/remote_relay_curl_download_strategy.rb"
RELAY_COMMIT_SUBJECT="rn-forge: apply Homebrew remote relay"

FORCE_FLAG=0
RESET_FLAG=0
REGEN_FLAG=0

# =============================================================================
# Helper functions
# =============================================================================

# @description Print `rnfmac brew relay` usage.
# @noargs
# @stdout The usage text.
function usage() {
  cat <<EOF
Usage: rnfmac brew relay [--force|--reset|--regen]

  (no flag)  ensure Homebrew is patched with the remote relay (skips if already
             applied, applies otherwise)
  --force    reset to clean base, then unconditionally reapply and commit the patches
  --reset    hard reset Homebrew (${HOMEBREW_PREFIX}) back to its clean upstream base
  --regen    regenerate the patch files from a hand-edited clean-base Homebrew worktree
             (requires a git checkout; run against ${HOMEBREW_PREFIX}, see CLAUDE.md)
EOF
}

# @description Parse CLI args, setting the mode flags and handling `-h`/`--help`.
#   `--force` and `--reset` are mutually exclusive.
# @arg $@ string Flags: `--force`, `--reset`, `--regen`, `-h`/`--help`/`help`.
# @set FORCE_FLAG Set to 1 if `--force` was passed.
# @set RESET_FLAG Set to 1 if `--reset` was passed.
# @set REGEN_FLAG Set to 1 if `--regen` was passed.
# @exitcode 0 Parsed successfully, or help was requested (also exits the script).
# @exitcode 1 Unrecognized argument, or `--force`+`--reset` both passed.
function parse_args() {
  local arg
  for arg in "$@"; do
    case "${arg}" in
    --force) FORCE_FLAG=1 ;;
    --reset) RESET_FLAG=1 ;;
    --regen) REGEN_FLAG=1 ;;
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

  if [ "${FORCE_FLAG}" -eq 1 ] && [ "${RESET_FLAG}" -eq 1 ]; then
    echo "rnfmac: --force and --reset are mutually exclusive" >&2
    usage >&2
    exit 1
  fi
}

# @description Guard: exit unless `HOMEBREW_PREFIX` exists (Apple Silicon only).
# @noargs
# @exitcode 1 `HOMEBREW_PREFIX` does not exist.
function ensure_compatible_system() {
  if [ ! -d "${HOMEBREW_PREFIX}" ]; then
    log_warning "this system is not compatible with the Homebrew relay — ${HOMEBREW_PREFIX} not found (Apple Silicon Homebrew installs only)"
    exit 1
  fi
}

# @description Guard: exit unless `HOMEBREW_PREFIX` is itself the root of a git
#   repository — refuses to run destructive resets against a repo larger than
#   `HOMEBREW_PREFIX` (e.g. nested inside another checkout).
# @noargs
# @exitcode 1 Not a git repo, or its root isn't `HOMEBREW_PREFIX`.
function ensure_homebrew_repo() {
  local toplevel
  toplevel="$(brew_git rev-parse --show-toplevel 2>/dev/null)" || {
    log_warning "${HOMEBREW_PREFIX} is not a git repository"
    exit 1
  }

  ## defensive: -C scopes git to HOMEBREW_PREFIX, but show-toplevel walks up to the
  ## enclosing repo root — refuse to run destructive resets against a repo larger
  ## than HOMEBREW_PREFIX itself (e.g. HOMEBREW_PREFIX nested inside another checkout)
  if [ "$(readlink -f "${toplevel}")" != "$(readlink -f "${HOMEBREW_PREFIX}")" ]; then
    log_warning "${HOMEBREW_PREFIX} is not the root of its git repository (root is ${toplevel}) — refusing to operate on it"
    exit 1
  fi
}

# =============================================================================
# Git operations — everything here runs scoped to HOMEBREW_PREFIX (or, for
# checkout detection, SRC_ROOT)
# =============================================================================

# @description Run a git command scoped to `HOMEBREW_PREFIX`.
# @arg $@ string Git subcommand and arguments.
function brew_git() {
  git -C "${HOMEBREW_PREFIX}" "$@"
}

# @description Run a git command scoped to `HOMEBREW_PREFIX`, with a fixed
#   `rn-forge` committer identity (needed for `commit` — the real user's git
#   identity may not be configured for this repo).
# @arg $@ string Git subcommand and arguments.
function brew_git_with_identity() {
  git -C "${HOMEBREW_PREFIX}" \
    -c user.name="rn-forge" \
    -c user.email="rn-forge@local" \
    "$@"
}

# @description Test whether HEAD in `HOMEBREW_PREFIX` is the relay's own commit.
# @noargs
# @exitcode 0 HEAD's subject matches `RELAY_COMMIT_SUBJECT`.
# @exitcode 1 It does not.
function head_is_relay_commit() {
  [ "$(brew_git log -1 --pretty=%s 2>/dev/null)" = "${RELAY_COMMIT_SUBJECT}" ]
}

# @description Reset `HOMEBREW_PREFIX` back to its clean upstream base: drops the
#   relay commit if present (else a plain hard reset), then removes the relay's
#   download-strategy file (untracked, so `reset --hard` alone wouldn't remove it).
# @noargs
function reset_homebrew_to_clean_base() {
  if head_is_relay_commit; then
    brew_git reset --hard HEAD^
  else
    brew_git reset --hard
  fi

  rm -f "${HOMEBREW_PREFIX}/${REMOTE_RELAY_STRATEGY}"
}

# @description Print the git checkout root containing `SRC_ROOT`, if any.
# @noargs
# @stdout The checkout's top-level path, or nothing if `SRC_ROOT` isn't in a git checkout.
function checkout_root() {
  if git -C "${SRC_ROOT}" rev-parse --show-toplevel >/dev/null 2>&1; then
    git -C "${SRC_ROOT}" rev-parse --show-toplevel
  fi
}

# =============================================================================
# Main functions — one per execution mode, dispatched from execute()
# =============================================================================

# @description Reset Homebrew to its clean base, copy in the relay's download
#   strategy, apply the payload patches (3-way merge), and commit — the single
#   codepath every apply mode (default, `--force`) funnels through. On conflict,
#   resets back to clean base and exits rather than leaving a half-patched tree.
# @noargs
# @exitcode 1 A patch failed to apply cleanly (conflicts reported above).
function apply_relay() {
  reset_homebrew_to_clean_base

  local patch_file conflicted=0
  cp -f \
    "${PAYLOAD_PATH}/download_strategy/remote_relay_curl_download_strategy.rb" \
    "${HOMEBREW_PREFIX}/${REMOTE_RELAY_STRATEGY}"

  for patch_file in "${PATCH_FILES[@]}"; do
    if ! brew_git apply --3way "${patch_file}"; then
      conflicted=1
    fi
  done

  if [ "${conflicted}" -eq 1 ]; then
    log_warning "conflicts applying relay patches — see conflicted files above"
    reset_homebrew_to_clean_base
    log_warning "reset Homebrew back to its clean base; regenerate patches with 'rnfmac brew relay --regen'"
    exit 1
  fi

  brew_git add "${MANAGED_HOMEBREW_FILES[@]}" "${REMOTE_RELAY_STRATEGY}"
  brew_git_with_identity commit -q -m "${RELAY_COMMIT_SUBJECT}"
  log_success "homebrew remote_relay applied"
}

# @description Default mode: apply the relay only if it isn't already applied.
# @noargs
function ensure_relay_applied() {
  if head_is_relay_commit; then
    log_success "homebrew remote_relay already applied"
    return
  fi
  log_notice "Applying Homebrew relay patches ..."
  apply_relay
}

# @description `--force` mode: reset to clean base, `brew update`, then
#   unconditionally reapply and commit the relay patches.
# @noargs
function force_relay() {
  log_notice "Resetting and reapplying Homebrew relay patches ..."
  reset_homebrew_to_clean_base
  brew update
  apply_relay
}

# @description `--reset` mode: hard reset Homebrew back to its clean upstream base.
# @noargs
function reset_relay() {
  reset_homebrew_to_clean_base
  log_success "homebrew remote_relay removed — ${HOMEBREW_PREFIX} is on a clean upstream base"
}

# @description `--regen` mode: regenerate the patch files in `PATCH_PATH` from the
#   diff between HEAD and a hand-edited clean-base Homebrew worktree at
#   `HOMEBREW_PREFIX`. Requires a git checkout and a non-relay HEAD.
# @noargs
# @exitcode 1 Not run from a git checkout, or HEAD is already the relay commit.
function regen_patches() {
  local managed target
  if [ -z "$(checkout_root)" ]; then
    log_warning "'--regen' requires a git checkout — run via 'src/rnfmac.sh brew relay --regen' from the macsetup checkout"
    exit 1
  fi

  if head_is_relay_commit; then
    log_warning "${HOMEBREW_PREFIX} HEAD is the relay commit — regen must run against a clean-base worktree with your hand edits uncommitted. Run 'rnfmac brew relay --reset', hand-edit, then --regen."
    exit 1
  fi

  for managed in "${MANAGED_HOMEBREW_FILES[@]}"; do
    target="${PATCH_PATH}/$(basename "${managed}").patch"
    brew_git diff --no-color HEAD -- "${managed}" >"${target}"
    if [ ! -s "${target}" ]; then
      log_warning "no diff found for ${managed} — is it hand-edited in ${HOMEBREW_PREFIX}?"
    fi
    log_success "regenerated $(basename "${managed}").patch"
  done
}

# @description Run `rnfmac brew relay`: validate the system/repo, then dispatch to
#   the mode selected by `REGEN_FLAG`/`RESET_FLAG`/`FORCE_FLAG` (default: ensure
#   the relay is applied).
# @noargs
function execute() {
  ensure_compatible_system
  ensure_homebrew_repo

  if [ "${REGEN_FLAG}" -eq 1 ]; then
    regen_patches
  elif [ "${RESET_FLAG}" -eq 1 ]; then
    reset_relay
  elif [ "${FORCE_FLAG}" -eq 1 ]; then
    force_relay
  else
    ensure_relay_applied
  fi
}

${__SOURCED__:+return} # shellspec Include guard

print_vars "RNF_HOME" "SELF_PATH" "SRC_ROOT" "HOMEBREW_PREFIX" "PAYLOAD_PATH" "PATCH_PATH"
parse_args "$@"
execute
