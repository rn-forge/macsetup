# shellcheck shell=bash
# shellspec helper — every example gets a sandboxed $HOME and a fixture checkout,
# so the real ~/.rn-forge, shell rc files, and Homebrew are never touched.

FIXTURES="${SHELLSPEC_PROJECT_ROOT}/tests/fixtures"

setup_sandbox() {
  SANDBOX="${SHELLSPEC_TMPBASE}/sandbox.$$.${SHELLSPEC_EXAMPLE_NO:-0}"
  export HOME="${SANDBOX}/home"
  mkdir -p "${HOME}/.rn-forge" "${HOME}/.oh-my-zsh/custom/themes"
  printf 'source $ZSH/oh-my-zsh.sh\n' >"${HOME}/.zshrc"

  # pre-seed shkit as already installed — commands/profile.zsh source it
  # locally (no network); only install.sh streams it fresh (see install_spec.sh)
  mkdir -p "${HOME}/.rn-forge/shkit/v0.1.2"
  cp "${FIXTURES}/shkit.sh" "${HOME}/.rn-forge/shkit/v0.1.2/shkit.sh"
  echo "0.1.2" >"${HOME}/.rn-forge/shkit/v0.1.2/VERSION"
  ln -sfn v0.1.2 "${HOME}/.rn-forge/shkit/current"

  # fixture checkout: the real src/ + VERSION, plus a profile for the stubbed hostname
  CHECKOUT="${SANDBOX}/checkout"
  mkdir -p "${CHECKOUT}"
  cp -R "${SHELLSPEC_PROJECT_ROOT}/src" "${CHECKOUT}/src"
  cp "${SHELLSPEC_PROJECT_ROOT}/VERSION" "${CHECKOUT}/VERSION"
  CHECKOUT_VERSION="$(cat "${CHECKOUT}/VERSION")"
  export CHECKOUT_VERSION
  mkdir -p "${CHECKOUT}/src/profiles/testhost"
  printf '# shellcheck disable=SC2148\nexport RNF_TEST_HOST_MARKER=1\n' >"${CHECKOUT}/src/profiles/testhost/profile.zsh"
  printf '# test Brewfile — intentionally empty\n' >"${CHECKOUT}/src/profiles/testhost/Brewfile"

  # command stubs (hostname, curl) shadow the real tools for scripts run as child processes
  export PATH="${FIXTURES}/stubs:${PATH}"
  # safety net: integration runs must never reach brew/uv/nvm/sdkman
  export RNFMAC_SYNC_PROFILES_ONLY=1
}

cleanup_sandbox() {
  rm -rf "${SANDBOX}"
}

# installs the fixture checkout into RNF_HOME the way a real machine would — via
# install.sh — so that commands relying on an already-installed PRODUCT_HOME/current
# (profile/sync.sh, sync.sh, doctor.sh, upgrade.sh, brew/relay.sh --regen) have one.
install_dist_from_checkout() {
  "${CHECKOUT}/src/install.sh" >/dev/null 2>&1
}

run_sync_from_checkout() {
  install_dist_from_checkout
  "${CHECKOUT}/src/commands/sync.sh"
}

run_profile_sync_from_checkout() {
  install_dist_from_checkout
  "${CHECKOUT}/src/commands/profile/sync.sh"
}

# write a driver script that sources the given command script (Include guard active) and
# runs the given body lines — unit tests execute functions in the sandbox this way
write_unit_driver() {
  local source_script="$1"
  shift
  DRIVER="${SANDBOX}/driver.zsh"
  {
    echo '#!/bin/zsh'
    echo 'set -eo pipefail'
    echo '__SOURCED__=1'
    echo "source '${CHECKOUT}/src/commands/${source_script}'"
    printf '%s\n' "$@"
  } >"${DRIVER}"
  chmod +x "${DRIVER}"
}

# stage a fake GitHub release tarball (default version 9.9.9) served by the curl
# stub at the unversioned releases/latest/download/macsetup.tar.gz URL
build_release_tarball() {
  local version="${1:-9.9.9}"
  local stage="${SANDBOX}/release-stage"
  rm -rf "${stage}"
  mkdir -p "${stage}"
  cp -R "${CHECKOUT}/src/." "${stage}/"
  echo "${version}" >"${stage}/VERSION"
  export RNF_TEST_RELEASE_TARBALL="${SANDBOX}/macsetup.tar.gz"
  tar -czf "${RNF_TEST_RELEASE_TARBALL}" -C "${stage}" .
}
