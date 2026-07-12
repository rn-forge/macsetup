# shellcheck shell=bash disable=SC2148,SC2317
# specs for upgrade.sh — the curl stub serves a staged release tarball at the
# unversioned releases/latest/download URL; the exec'd sync runs with
# RNFMAC_SYNC_PROFILES_ONLY=1.

Describe 'upgrade.sh'
BeforeEach 'setup_upgrade'
AfterEach 'cleanup_sandbox'

setup_upgrade() {
  setup_sandbox
  run_sync_from_checkout >/dev/null 2>&1 # install CHECKOUT_VERSION first
}

It 'downloads the latest release, installs it, and flips current'
build_release_tarball "9.9.9" # stage v9.9.9 for the curl stub
When run script "${HOME}/.rn-forge/macsetup/current/commands/upgrade.sh"
The status should be success
The output should include "Upgrading v${CHECKOUT_VERSION} -> v9.9.9"
The output should include 'Profile synced successfully'
The path "${HOME}/.rn-forge/macsetup/v9.9.9" should be directory
The contents of file "${HOME}/.rn-forge/macsetup/current/VERSION" should include '9.9.9'
The path "${HOME}/.rn-forge/macsetup/v${CHECKOUT_VERSION}" should be directory
End

It 'no-ops when already on the latest release'
build_release_tarball "${CHECKOUT_VERSION}" # stage the same version already installed
When run script "${HOME}/.rn-forge/macsetup/current/commands/upgrade.sh"
The status should be success
The output should include "already on the latest release (v${CHECKOUT_VERSION})"
The contents of file "${HOME}/.rn-forge/macsetup/current/VERSION" should include "${CHECKOUT_VERSION}"
End

It 'fails when the downloaded tarball checksum does not match its sidecar'
build_release_tarball "9.9.9"
export RNF_TEST_CORRUPT_CHECKSUM=1
When run script "${HOME}/.rn-forge/macsetup/current/commands/upgrade.sh"
The status should be failure
The output should include 'Downloading latest release'
The error should include 'checksum mismatch'
The path "${HOME}/.rn-forge/macsetup/v9.9.9" should not be exist
End
End
