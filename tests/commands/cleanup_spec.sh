# shellcheck shell=bash disable=SC2148,SC2317
# specs for cleanup.sh — deletes every version dir under PRODUCT_HOME except the
# one `current` points to.

Describe 'cleanup.sh'
BeforeEach 'setup_cleanup'
AfterEach 'cleanup_sandbox'

setup_cleanup() {
  setup_sandbox
  run_sync_from_checkout >/dev/null 2>&1 # installs CHECKOUT_VERSION as current
}

It 'removes old version dirs but keeps current'
mkdir -p "${HOME}/.rn-forge/macsetup/v0.0.1" "${HOME}/.rn-forge/macsetup/v0.0.2"
export RNF_SKIP_CONFIRMATIONS=1
When run script "${HOME}/.rn-forge/macsetup/current/commands/cleanup.sh"
The status should be success
The output should include "removed 2 old version(s), kept v${CHECKOUT_VERSION}"
The path "${HOME}/.rn-forge/macsetup/v0.0.1" should not be exist
The path "${HOME}/.rn-forge/macsetup/v0.0.2" should not be exist
The path "${HOME}/.rn-forge/macsetup/v${CHECKOUT_VERSION}" should be directory
End

It 'no-ops when only the current version is installed'
When run script "${HOME}/.rn-forge/macsetup/current/commands/cleanup.sh"
The status should be success
The output should include "nothing to clean up — only v${CHECKOUT_VERSION} is installed"
The path "${HOME}/.rn-forge/macsetup/v${CHECKOUT_VERSION}" should be directory
End

It 'does not remove anything when the user declines confirmation'
mkdir -p "${HOME}/.rn-forge/macsetup/v0.0.1"
Data "n"
When run script "${HOME}/.rn-forge/macsetup/current/commands/cleanup.sh"
The status should equal 1
The output should include '(y/n)'
The error should include 'Cancelled.'
The path "${HOME}/.rn-forge/macsetup/v0.0.1" should be directory
End
End
